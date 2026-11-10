//
//  WallpaperStore.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What the Home Screen shows behind its icons: the halo zContainer comes
/// with, or a photo chosen in Settings > Wallpaper or from edit mode's add
/// button. It keeps a blurred copy for behind search, and whether Dark Mode
/// dims a photo. A photo is kept as a file the size of the largest screens;
/// either is loaded off the main thread at launch.
@MainActor
@Observable
final class WallpaperStore {
    /// The wallpaper, ready to draw. Nil only until it has loaded.
    private(set) var image: UIImage?

    /// The wallpaper blurred, shown behind search. Blurring it once here
    /// spares search a live blur of a full screen picture. Nil until it's
    /// made, a moment after the wallpaper shows.
    private(set) var blurredImage: UIImage?

    /// Whether the wallpaper is a photo the person chose, rather than the
    /// halo zContainer comes with.
    private(set) var isCustom = false

    /// How bright the wallpaper is behind parts of the screen, for the
    /// wallpaper showing, so it's worked out once.
    @ObservationIgnored private var brightnesses: [String: Double] = [:]

    /// How bright the wallpaper is behind a part of a screen of `screenSize`,
    /// from 0 for black to 1 for white, as it shows: dimmed in Dark Mode when
    /// it's dimmed. Nil while there's no wallpaper.
    func brightness(behind rect: CGRect, onScreenOf screenSize: CGSize, isDark: Bool) -> Double? {
        guard let image else {
            return nil
        }
        let key = "\(ObjectIdentifier(image).hashValue) \(rect) \(screenSize)"
        let brightness: Double
        if let known = brightnesses[key] {
            brightness = known
        } else {
            guard let measured = WallpaperFile.brightness(of: image, behind: rect, onScreenOf: screenSize) else {
                return nil
            }
            if brightnesses.count > 16 {
                brightnesses.removeAll()
            }
            brightnesses[key] = measured
            brightness = measured
        }
        let isDimmed = isCustom && dimsInDarkMode && isDark
        return isDimmed ? brightness * (1 - HomeDesign.wallpaperDimming) : brightness
    }

    /// Whether a new wallpaper is being made from a photo.
    private(set) var isPreparing = false

    /// Whether a photo is dimmed a little while Dark Mode is on, so the white
    /// names under the icons read over its bright parts, as on iOS. The halo
    /// is made dark already, so it's never dimmed.
    var dimsInDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(dimsInDarkMode, forKey: Self.dimmedKey)
        }
    }

    /// The defaults key `dimsInDarkMode` is saved under.
    private static let dimmedKey = "ZCWallpaperDimmed"

    /// Counts the wallpapers set, and the times the halo is chosen again,
    /// so one that finishes loading or being made late can't replace a
    /// newer one.
    @ObservationIgnored private var generation = 0

    init() {
        dimsInDarkMode = UserDefaults.standard.object(forKey: Self.dimmedKey) as? Bool ?? true
        load()
    }

    /// Makes a photo's data the wallpaper. Throws when it isn't a picture
    /// iOS can read, leaving the wallpaper as it was. A photo or the halo
    /// chosen while it's being made wins, and this one is dropped.
    func set(_ data: Data) async throws {
        generation += 1
        let setting = generation
        isPreparing = true
        defer {
            // A photo chosen after this one is still being made.
            if setting == generation {
                isPreparing = false
            }
        }
        let (image, jpeg, blurred) = try await Task.detached(priority: .userInitiated) {
            let made = try WallpaperFile.make(data)
            return (made.image, made.jpeg, WallpaperFile.blurred(made.image))
        }.value
        // Use Default, or a photo chosen after this one, came later and wins.
        // Saving here on the main actor, with no wait after the check, keeps
        // the file in the order useDefault removes it in.
        guard setting == generation else {
            return
        }
        try WallpaperFile.save(jpeg)
        self.image = image
        blurredImage = blurred
        isCustom = true
    }

    /// Goes back to the halo zContainer comes with. The photo stays, dimmed as
    /// it was, until the halo has loaded and takes its place.
    func useDefault() {
        generation += 1
        isPreparing = false
        WallpaperFile.remove()
        load()
    }

    /// Loads the saved photo, or the halo when there's none: the iPad's
    /// square one on an iPad, which fills the screen either way up. The
    /// wallpaper shows as soon as it's decoded, and the blurred copy for
    /// search follows once it's made.
    private func load() {
        let loading = generation
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        Task {
            let loaded = await Task.detached(priority: .userInitiated) {
                let photo = WallpaperFile.load()
                return (photo ?? WallpaperFile.loadDefault(isPad: isPad)).map { image in
                    (image, photo != nil)
                }
            }.value
            // A wallpaper set meanwhile is newer than this one.
            guard loading == generation, let loaded else {
                return
            }
            image = loaded.0
            blurredImage = nil
            isCustom = loaded.1

            let blurred = await Task.detached(priority: .userInitiated) {
                WallpaperFile.blurred(loaded.0)
            }.value
            guard loading == generation else {
                return
            }
            blurredImage = blurred
        }
    }
}
