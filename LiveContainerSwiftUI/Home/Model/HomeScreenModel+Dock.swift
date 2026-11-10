//
//  HomeScreenModel+Dock.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The iPad dock's recent apps, what the dock holds, which sets its size,
/// and its bounce when it's full, as on iPadOS.
extension HomeScreenModel {
    /// The recent apps the iPad's dock shows after the person's icons, in
    /// order: those kept that are still on the Home Screen and not in the
    /// dock. None on an iPhone, or while they're turned off.
    var dockRecents: [HomeItem] {
        guard showsDockRecents else {
            return []
        }
        return dockRecentsStore.items.filter(isShowableRecent)
    }

    /// What the dock holds as `shown` has it. While an icon is being
    /// dragged, iPadOS keeps a place for one in the dock, even when it's
    /// empty, so there's somewhere to drop it.
    func dockContents(of shown: HomeLayout) -> HomeDockContents {
        let icons = drag == nil ? shown.dock.count : max(shown.dock.count, 1)
        return HomeDockContents(icons: icons, recents: dockRecents.count)
    }

    /// What the dock holds as it shows now.
    var dockContents: HomeDockContents {
        dockContents(of: displayedLayout)
    }

    /// Whether an item can be among the dock's recent apps: Settings or an
    /// app on the Home Screen, unless it's in the dock already, or in a
    /// folder there.
    func isShowableRecent(_ item: HomeItem) -> Bool {
        switch item {
        case .settings:
            break
        case .app(let key):
            guard apps[key] != nil else {
                return false
            }
        case .folder, .widget:
            return false
        }
        return !layout.isInDock(item)
    }

    /// Loads the recent apps the dock keeps. The first time recent apps show,
    /// they start from the apps opened most recently. While they're turned
    /// off, the ones kept are forgotten, as iPadOS forgets them.
    func loadDockRecents() {
        guard !SharedModel.isPhone else {
            return
        }
        guard showsDockRecents else {
            if HomeLayoutStorage.loadDockRecents()?.entries.isEmpty == false {
                HomeLayoutStorage.saveDockRecents(HomeDockRecents())
            }
            return
        }
        if let saved = HomeLayoutStorage.loadDockRecents() {
            dockRecentsStore = saved
            return
        }
        let opened = apps.compactMap { key, app -> (item: HomeItem, date: Date)? in
            let item = HomeItem.app(key)
            guard let date = app.appInfo.lastLaunched, isShowableRecent(item) else {
                return nil
            }
            return (item, date)
        }
        dockRecentsStore = .seeded(from: opened)
        HomeLayoutStorage.saveDockRecents(dockRecentsStore)
    }

    /// Notes that an app or Settings was opened, for the dock's recent apps,
    /// which change over half a second, as on iPadOS.
    func noteOpened(_ item: HomeItem) {
        guard showsDockRecents else {
            return
        }
        var recents = dockRecentsStore
        recents.noteOpened(item, isShowable: isShowableRecent)
        guard recents != dockRecentsStore else {
            return
        }
        withAnimation(HomeDesign.padDockRecentsChange) {
            dockRecentsStore = recents
        }
        HomeLayoutStorage.saveDockRecents(recents)
    }

    /// Notes that Settings opened once its screen has zoomed out over the
    /// dock, so the dock's recent apps change behind it, as they change
    /// behind an app opening on iPadOS.
    func noteOpenedBehindScreen(_ item: HomeItem) {
        Task { [weak self] in
            try? await Task.sleep(for: HomeDesign.padDockRecentsBehindScreen)
            self?.noteOpened(item)
        }
    }

    /// Shows or hides the dock's recent apps, as Settings > Appearance asks.
    /// Hiding them forgets them, as iPadOS does, so they start again from
    /// the next app opened once they're back on.
    func setShowsDockRecents(_ shows: Bool) {
        let shows = shows && !SharedModel.isPhone
        guard shows != showsDockRecents else {
            return
        }
        withAnimation(HomeDesign.padDockRecentsChange) {
            showsDockRecents = shows
            if !shows {
                dockRecentsStore = HomeDockRecents()
            }
        }
        if !shows {
            HomeLayoutStorage.saveDockRecents(dockRecentsStore)
        }
    }

    /// Opens a recent app from the iPad's dock, unless edit mode is on or
    /// search covers it: the app zooms open from its place there, and
    /// Settings zooms out of it.
    func openRecent(_ item: HomeItem) {
        guard !isSearching, drag == nil, !isEditing else {
            return
        }
        switch item {
        case .settings:
            zoomsFromRecent = item
            present(.settings)
            noteOpenedBehindScreen(item)
        case .app(let key):
            guard let app = apps[key] else {
                return
            }
            launch(app, from: item, startingAt: recentFrame(of: item))
        case .folder, .widget:
            break
        }
    }

    /// A recent app's frame on screen, in the iPad's dock.
    func recentFrame(of item: HomeItem) -> CGRect? {
        guard let metrics, let index = dockRecents.firstIndex(of: item) else {
            return nil
        }
        let contents = dockContents(of: layout)
        let size = metrics.dockIconSize(contents)
        let center = metrics.dockRecentCenter(at: index, in: contents)
        return CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
    }

    /// Bounces the iPad's dock, once a drag, for not taking what's held over
    /// it: a widget, or anything once it's full, as iPadOS does.
    func bounceDock() {
        guard !SharedModel.isPhone, var drag, !drag.hasBouncedDock else {
            return
        }
        drag.hasBouncedDock = true
        self.drag = drag
        withAnimation(.linear(duration: HomeDockBounce.duration)) {
            dockBounces += 1
        }
    }
}
