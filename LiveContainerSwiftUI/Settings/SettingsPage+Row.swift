//
//  SettingsPage+Row.swift
//  LiveContainerSwiftUI
//

import SwiftUI

extension SettingsPage {
    /// The page's name, on its row and in search.
    var title: String {
        switch self {
        case .zeus, .attention:
            "zc.settings.zeus".loc
        case .general:
            "zc.settings.general".loc
        case .appearance:
            "zc.settings.appearance".loc
        case .wallpaper:
            "zc.settings.wallpaper".loc
        case .apps, .app:
            "lc.tabView.apps".loc
        case .advanced:
            "zc.settings.advanced".loc
        }
    }

    /// The icon on the page's row: the Settings app's own for the same kind
    /// of page, as an IconServices graphic icon, with the symbol and color to
    /// draw where the system has none. Nil for Zeus and for an app, which
    /// show their own.
    var rowIcon: (systemImage: String, color: Color, graphicIcon: String)? {
        switch self {
        case .zeus, .attention, .app:
            nil
        case .general:
            ("gear", .gray, "com.apple.graphic-icon.gear")
        case .appearance:
            // Display & Brightness's, where the Settings app has Light and Dark.
            ("sun.max.fill", .blue, "com.apple.graphic-icon.display")
        case .wallpaper:
            ("camera.macro", .cyan, "com.apple.graphic-icon.wallpaper")
        case .apps:
            // The Settings app's Apps row: a grid of colored squares, which
            // IconServices names after the Home Screen.
            ("square.grid.3x3.fill", .indigo, "com.apple.graphic-icon.home-screen")
        case .advanced:
            // Developer's, where the Settings app keeps its own advanced settings.
            ("hammer.fill", .gray, "com.apple.graphic-icon.developer-tools")
        }
    }
}

extension SettingsRow where Value == EmptyView {
    /// The row of one of Settings' pages, with its name and icon.
    init(page: SettingsPage) {
        let icon = page.rowIcon
        self.init(title: page.title, systemImage: icon?.systemImage ?? "gear", color: icon?.color ?? .gray, graphicIcon: icon?.graphicIcon)
    }
}
