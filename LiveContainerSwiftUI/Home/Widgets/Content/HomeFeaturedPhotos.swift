//
//  HomeFeaturedPhotos.swift
//  LiveContainerSwiftUI
//

import Photos
import SwiftUI
import UIKit

/// The photos the Photos widget features, once zContainer may see the
/// library: tapping the widget asks, as the widget is the only thing that
/// looks. The person's favorites when they have some, as the photos they'd
/// most like to see, and otherwise their latest, a different one each hour,
/// as iOS's widget changes its photo through the day. Each is drawn once for
/// its size.
@MainActor
@Observable
final class HomeFeaturedPhotos {
    static let shared = HomeFeaturedPhotos()

    /// The photos it picks from, by their library identifier.
    private(set) var candidates: [String] = []
    /// The photos drawn, by identifier and size.
    private var images: [String: UIImage] = [:]
    @ObservationIgnored private var requested: Set<String> = []
    @ObservationIgnored private var observer: LibraryObserver?
    @ObservationIgnored private var hasLoaded = false

    /// How many photos it picks from, at most.
    private static let candidateLimit = 60

    /// Whether zContainer may ask to see the library, which it hasn't yet.
    var canAsk: Bool {
        PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined
    }

    private var isAllowed: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// Asks to see the library, then shows a photo from it.
    func requestAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            return
        }
        hasLoaded = false
        load()
    }

    /// Finds the photos to feature once, and again whenever the library
    /// changes.
    func load() {
        guard isAllowed, !hasLoaded else {
            return
        }
        hasLoaded = true
        if observer == nil {
            let observer = LibraryObserver { [weak self] in
                self?.fetch()
            }
            PHPhotoLibrary.shared().register(observer)
            self.observer = observer
        }
        fetch()
    }

    /// The photo featured at `date`: one of the candidates for each hour.
    func featured(at date: Date) -> String? {
        guard !candidates.isEmpty else {
            return nil
        }
        let hour = Int(date.timeIntervalSince1970 / 3600)
        return candidates[hour % candidates.count]
    }

    /// A photo drawn at `pixels`, or nil until it has been.
    func image(_ id: String, pixels: CGSize) -> UIImage? {
        images[Self.key(id, pixels)]
    }

    /// Draws a photo at `pixels`, filling them, unless it's drawn or being
    /// drawn.
    func loadImage(_ id: String, pixels: CGSize) async {
        let key = Self.key(id, pixels)
        guard !requested.contains(key),
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            return
        }
        requested.insert(key)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        let image = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            PHImageManager.default().requestImage(for: asset, targetSize: pixels, contentMode: .aspectFill, options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
        if let image {
            images[key] = image
        } else {
            requested.remove(key)
        }
    }

    /// Lists the favorites, or the latest photos when there are none.
    private func fetch() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.fetchLimit = Self.candidateLimit

        var ids: [String] = []
        if let favorites = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil).firstObject {
            PHAsset.fetchAssets(in: favorites, options: options).enumerateObjects { asset, _, _ in
                ids.append(asset.localIdentifier)
            }
        }
        if ids.isEmpty {
            PHAsset.fetchAssets(with: options).enumerateObjects { asset, _, _ in
                ids.append(asset.localIdentifier)
            }
        }
        if ids != candidates {
            candidates = ids
        }
    }

    private static func key(_ id: String, _ pixels: CGSize) -> String {
        "\(id)@\(Int(pixels.width))x\(Int(pixels.height))"
    }
}

/// Tells the featured photos the library changed, on the main thread.
private final class LibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    private let changed: @MainActor () -> Void

    init(changed: @escaping @MainActor () -> Void) {
        self.changed = changed
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            changed()
        }
    }
}
