//
//  SettingsSearch.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Something Settings' search finds: one of its pages, a setting on a page,
/// or an app, which opens the page it's on.
struct SettingsSearchItem: Identifiable {
    let id: String
    /// The name it's found by.
    let title: String
    /// The page it's on, shown under its name, as the Settings app's search
    /// shows where a setting is. Nil for a page itself.
    let location: String?
    /// The page it opens.
    let page: SettingsPage
}

/// What Settings' search finds for what's typed, as the Settings app's
/// search finds its pages, the settings on them and apps by name.
enum SettingsSearch {
    /// The items whose names hold what's typed, ignoring case and accents:
    /// pages first, then the settings on them, then apps, each in Settings'
    /// order.
    @MainActor
    static func results(for query: String, apps: [LCAppModel]) -> [SettingsSearchItem] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return []
        }
        return items(apps: apps).filter { $0.title.localizedStandardContains(query) }
    }

    /// Everything search can find.
    @MainActor
    private static func items(apps: [LCAppModel]) -> [SettingsSearchItem] {
        let pages: [SettingsPage] = [.zeus, .general, .appearance, .wallpaper, .apps, .advanced]
        var items = pages.map { page in
            SettingsSearchItem(id: "page.\(page.title)", title: page.title, location: nil, page: page)
        }
        for page in pages {
            for key in settings(on: page) {
                items.append(SettingsSearchItem(id: "\(page.title).\(key)", title: key.loc, location: page.title, page: page))
            }
        }
        for app in apps {
            guard let key = app.homeKey else {
                continue
            }
            items.append(SettingsSearchItem(id: "app.\(key)", title: app.displayName, location: SettingsPage.apps.title, page: .app(key)))
        }
        return items
    }

    /// The names of the settings on a page, as the page shows them.
    private static func settings(on page: SettingsPage) -> [String] {
        switch page {
        case .zeus, .attention:
            [
                "zc.settings.zeus.certificate",
                "zc.settings.zeus.status",
                "zc.settings.zeus.expires",
                "lc.jitlessDiag.teamId",
                "zc.settings.setup",
            ]
        case .general:
            [
                "zc.settings.about",
                "zc.settings.storage",
                "lc.settings.dataManagement",
                "lc.common.reset",
            ]
        case .appearance:
            [
                "zc.settings.appearance.theme",
                "zc.settings.appearance.theme.light",
                "zc.settings.appearance.theme.dark",
                "zc.settings.appearance.homeButtonInApps",
                "zc.settings.appIcon",
            ] + (SharedModel.isPhone ? [] : ["zc.settings.appearance.dockRecents"])
        case .wallpaper:
            [
                "zc.settings.wallpaper.choose",
                "zc.settings.wallpaper.dim",
                "zc.settings.wallpaper.useDefault",
            ]
        case .apps:
            [
                "lc.appList.hiddenApps",
            ]
        case .advanced:
            [
                "lc.tabView.tweaks",
                "lc.appBanner.multitask",
                "zc.settings.advanced.jit",
                "zc.settings.advanced.emulator",
                "lc.settings.dontSign",
                "lc.settings.silentSwitchApp",
                "lc.settings.silentOpenWebPage",
                "lc.settings.FrameIcon",
                "lc.settings.jitlessDiagnose",
                "zc.settings.developer",
            ]
        case .app:
            []
        }
    }
}
