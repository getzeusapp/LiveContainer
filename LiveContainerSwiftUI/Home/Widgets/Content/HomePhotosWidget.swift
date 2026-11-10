//
//  HomePhotosWidget.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UIKit

/// Photos' featured photos widget: a photo from the library filling it, a
/// different one each hour, once zContainer may see the library, which
/// tapping the widget asks. Until then, and while the library has none, it
/// shows what iOS's does before it has photos to feature: the Photos icon
/// and a line saying they'll appear once processed.
struct HomePhotosWidget: View {
    /// The widget's size on screen.
    let frameSize: CGSize

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        // Redrawn every minute, so the photo changes with the hour.
        TimelineView(.everyMinute) { context in
            let photos = HomeFeaturedPhotos.shared
            let pixels = CGSize(width: frameSize.width * displayScale, height: frameSize.height * displayScale)
            if let id = photos.featured(at: context.date), let image = photos.image(id, pixels: pixels) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: frameSize.width, height: frameSize.height)
                    .clipped()
                    .accessibilityHidden(true)
            } else {
                placeholder
                    .task(id: photos.featured(at: context.date)) {
                        if let id = photos.featured(at: context.date) {
                            await photos.loadImage(id, pixels: pixels)
                        }
                    }
            }
        }
        .onAppear {
            HomeFeaturedPhotos.shared.load()
        }
    }

    /// The Photos icon and the line saying photos will appear.
    private var placeholder: some View {
        VStack(spacing: 6) {
            Group {
                if let icon = HomeWidgetAppIcons.shared.image(.photos, isDark: colorScheme == .dark) {
                    Image(uiImage: icon)
                        .resizable()
                } else {
                    HomeWidgetDesign.placeholder
                }
            }
            .frame(width: Self.iconSize, height: Self.iconSize)
            .clipShape(.rect(cornerRadius: Self.iconSize * HomeDesign.iconCornerFraction, style: .continuous))
            Text("zc.widget.photos.processing".loc)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { HomeWidgetBackground() }
        .onAppear {
            HomeWidgetAppIcons.shared.load(.photos)
        }
    }

    /// The Photos icon's size, as the widget shows it.
    private static let iconSize = 60.0
}

/// The icons of iOS's own apps that widgets show, drawn by IconServices from
/// the apps on the device, as the Settings icon is, and kept in Caches.
@MainActor
@Observable
final class HomeWidgetAppIcons {
    static let shared = HomeWidgetAppIcons()

    enum App: String, Sendable {
        case calendar = "Calendar"
        case maps = "Maps"
        case news = "News"
        case photos = "Photos"
        case reminders = "Reminders"

        /// The app a widget is from.
        init(_ kind: HomeWidgetKind) {
            switch kind {
            case .calendar:
                self = .calendar
            case .maps:
                self = .maps
            case .news:
                self = .news
            case .photos:
                self = .photos
            case .reminders:
                self = .reminders
            }
        }

        /// The names the app's bundle goes by in /Applications: Calendar is
        /// MobileCal, and older iOS versions call Photos MobileSlideShow.
        var bundleNames: [String] {
            switch self {
            case .calendar:
                ["MobileCal"]
            case .maps:
                ["Maps"]
            case .news:
                ["News"]
            case .photos:
                ["Photos", "MobileSlideShow"]
            case .reminders:
                ["Reminders"]
            }
        }
    }

    private var icons: [String: UIImage] = [:]
    @ObservationIgnored private var requested: Set<App> = []

    func image(_ app: App, isDark: Bool) -> UIImage? {
        icons["\(app.rawValue)-\(isDark)"]
    }

    /// Draws both versions of an app's icon, once.
    func load(_ app: App) {
        guard !requested.contains(app) else {
            return
        }
        requested.insert(app)
        Task.detached(priority: .userInitiated) {
            let light = Self.icon(app, isDark: false)
            let dark = Self.icon(app, isDark: true)
            await self.show(app, light: light, dark: dark)
        }
    }

    private func show(_ app: App, light: UIImage?, dark: UIImage?) {
        icons["\(app.rawValue)-false"] = light
        icons["\(app.rawValue)-true"] = dark
    }

    nonisolated private static func icon(_ app: App, isDark: Bool) -> UIImage? {
        let system = ProcessInfo.processInfo.operatingSystemVersion
        let version = "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)"
        let saved = URL.cachesDirectory
            .appending(path: "HomeScreen", directoryHint: .isDirectory)
            .appending(path: "\(app.rawValue)-\(version)-\(isDark ? "dark" : "light").png")
        if let image = UIImage(contentsOfFile: saved.path(percentEncoded: false)) {
            return image
        }
        #if targetEnvironment(simulator)
        guard let root = ProcessInfo.processInfo.environment["SIMULATOR_ROOT"] else {
            return nil
        }
        let applications = URL(fileURLWithPath: root).appending(path: "Applications", directoryHint: .isDirectory)
        #else
        let applications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        #endif
        let bundles = app.bundleNames.map { applications.appending(path: "\($0).app", directoryHint: .isDirectory) }
        guard let bundle = bundles.first(where: { FileManager.default.isReadableFile(atPath: $0.appending(path: "Info.plist").path(percentEncoded: false)) }),
              let image = UIImage.generateIcon(forBundleURL: bundle, style: isDark ? .Dark : .Light, hasBorder: false),
              image.cgImage != nil, let png = image.pngData() else {
            return nil
        }
        try? FileManager.default.createDirectory(at: saved.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? png.write(to: saved, options: .atomic)
        return image
    }
}
