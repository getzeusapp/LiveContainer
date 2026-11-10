//
//  SettingsGraphicIcons.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UIKit

/// The icons the Settings app draws beside its rows, which zContainer's rows
/// show where the Settings app has one for the same thing: IconServices'
/// graphic icons, such as com.apple.graphic-icon.gear for General, drawn by
/// the system, so they're the Settings app's own and zContainer carries none
/// of Apple's artwork. Each is drawn once for its size, off the main thread,
/// in its light version, which the Settings app shows in Dark Mode too; until
/// then, or where the system has none, SettingsIcon draws its own tile.
@MainActor
@Observable
final class SettingsGraphicIcons {
    static let shared = SettingsGraphicIcons()

    /// The icons drawn, by type and size.
    private var icons: [Key: UIImage] = [:]
    /// The icons being drawn, or that the system had none for.
    @ObservationIgnored private var requested: Set<Key> = []

    struct Key: Hashable, Sendable {
        let type: String
        let size: Double
    }

    /// The icon of `type`, `size` points square, or nil while it hasn't been
    /// drawn, or when the system has none.
    func image(_ key: Key) -> UIImage? {
        icons[key]
    }

    /// Draws the icon of `key`, unless it's been drawn or asked for already.
    func load(_ key: Key) async {
        guard !requested.contains(key) else {
            return
        }
        requested.insert(key)
        let image = await Task.detached(priority: .userInitiated) {
            UIImage.graphicIcon(ofType: key.type, size: key.size, dark: false)
        }.value
        if let image {
            icons[key] = image
        }
    }
}
