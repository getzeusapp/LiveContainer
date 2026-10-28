//
//  HomeScreenModel.swift
//  LiveContainerSwiftUI
//

import Combine
import SwiftUI

/// The Home Screen's state: the layout of the icons, the page showing, edit
/// mode and the icon being dragged, search, and the screens and questions
/// that open over it. It keeps the layout in line with the installed apps and
/// saves it whenever it changes. Opening, editing, searching and moving
/// between pages live in this type's extensions; the AppLaunchCoordinator does
/// the installing, launching and removing.
@MainActor
@Observable
final class HomeScreenModel {
    /// Launches, installs and removes apps.
    @ObservationIgnored let coordinator: AppLaunchCoordinator
    /// The installed apps and the hidden-app state.
    @ObservationIgnored let sharedModel: SharedModel
    /// Where everything sits on the current screen, which the main window's
    /// Home Screen hands over whenever the screen's size changes. Dragging and
    /// the launch zoom read it. Views don't follow its changes; on iPad they
    /// read `padMetrics` instead.
    @ObservationIgnored var metrics: HomeMetrics?
    /// The same as `metrics` on iPad, where views follow it: search, so its
    /// panels and icons fit a window as it is resized or rotated, and the
    /// wallpaper preview until Settings has measured itself. It stays nil on
    /// iPhone, where those views keep reading `metrics` and so keep the size
    /// they opened with, as they always have.
    var padMetrics: HomeMetrics?

    /// The apps the Home Screen shows, by their Home Screen key. Hidden apps
    /// aren't among them.
    private(set) var apps: [String: LCAppModel] = [:]
    /// Where the icons are, as saved.
    var layout: HomeLayout

    /// The page showing, as the paging scroll view reports it.
    var page: Int? = 0
    /// The pages whose icons are built: the page showing and its neighbors,
    /// and while the pages move, every page they pass on the way. Pages
    /// further away have no views, so their icons don't load or jiggle.
    var builtPages = -1...1
    /// Whether the page dots show in place of "Search", which they do while
    /// the pages move.
    var showsPageDots = false
    @ObservationIgnored var pageDotsTask: Task<Void, Never>?
    /// Whether a finger is scrubbing along the page dots, which keeps them up.
    @ObservationIgnored var isScrubbingPages = false

    /// Whether the icons jiggle and can be moved and removed.
    var isEditing = false
    /// The icon being dragged in edit mode, or nil.
    var drag: HomeDrag?
    /// Where the dragged icon's center is, on screen. Only the dragged icon's
    /// copy reads it, so moving the finger doesn't redraw the other icons.
    var liftedIconCenter: CGPoint = .zero
    /// Whether the dragged icon has been let go and is flying to its place,
    /// settling back to the size and look of the icon it is about to become.
    var isDropping = false
    /// Whether the dragged icon has been let go over another icon and is
    /// shrinking into the folder it makes or joins there.
    var isDroppingIntoFolder = false
    @ObservationIgnored var pendingMerge: HomeItem?
    @ObservationIgnored var mergeTask: Task<Void, Never>?
    @ObservationIgnored var folderLeaveTask: Task<Void, Never>?
    /// A folder that has just let the dragged icon out, which the icon goes
    /// into again only once it has moved off the folder's icon, so the folder
    /// doesn't open again at once under a finger still over it.
    @ObservationIgnored var blockedMerge: HomeItem?

    /// The folder open over the Home Screen, by its id, or nil.
    var openFolderID: String?
    /// Whether the open folder shows, out of its icon. It goes back into its
    /// icon before `openFolderID` clears, and while an icon dragged out of it
    /// is still being moved, when the folder's view stays, hidden, holding
    /// the drag.
    var isFolderShown = false
    /// Whether the open folder has finished zooming out of its icon, when its
    /// panel's own icons, which can be tapped and dragged, take over from
    /// the ones that zoom.
    var isFolderSettled = false
    /// Whether the open folder has gone back into its icon for an icon dragged
    /// out of it. Its view stays to hold that drag, but draws nothing, rather
    /// than a copy of the folder's icon where it was as the Home Screen moves.
    var isFolderLetOut = false
    /// The page of the open folder that shows, as its paging scroll view
    /// reports it.
    var folderPage: Int? = 0
    /// Whether the open folder's name is being typed.
    var isEditingFolderName = false
    @ObservationIgnored var pendingTarget: HomeSlot?
    /// The icon whose menu last opened, which UIKit offers for dragging out of
    /// the menu.
    @ObservationIgnored var menuDragItem: HomeItem?
    /// Whether an icon dragged out of its menu is moving across the Home
    /// Screen. Icon menus keep their actions until it is dropped.
    var isMenuDragging = false
    @ObservationIgnored var reflowTask: Task<Void, Never>?
    @ObservationIgnored var pageTurnDirection = 0
    @ObservationIgnored var pageTurnTask: Task<Void, Never>?

    /// Whether search is open over the Home Screen.
    var isSearching = false
    /// How far a pull down on the pages has brought search in, from 0 to 1,
    /// while the finger is still down. Search follows it until the pull ends.
    var searchPull = 0.0
    /// What the person typed into search.
    var searchText = ""

    /// The screen open over the Home Screen, such as Settings.
    var presentedScreen: HomePresentedScreen?
    /// Whether a screen covers the Home Screen completely, from the moment it
    /// opens until it has closed. The status bar then follows that screen's
    /// appearance instead of the Home Screen's dark one.
    var isCoveredByScreen = false

    /// The app the person asked to remove, while the question shows.
    var pendingRemoval: LCAppModel?
    /// Whether Files is open to pick an IPA to install.
    var isChoosingIPA = false
    /// How to add an app once the screen over the Home Screen has closed,
    /// as Settings' Add App row asks.
    @ObservationIgnored var pendingAddition: HomeAddition?
    /// Whether the question asking for an install link shows.
    var isEnteringInstallURL = false
    /// The install link being typed.
    var installURL = ""
    /// An app asked to go on the iPhone's own Home Screen from its long-press
    /// menu, for AppShortcutPresenter to put there.
    var shortcutRequest: AppShortcutRequest?

    /// The app zooming open from its icon, just before zContainer turns into it.
    var launchZoom: HomeLaunchZoom?
    @ObservationIgnored var launchZoomContinuation: CheckedContinuation<Void, Never>?

    /// Loads the saved layout, or makes the first one from LiveContainer's
    /// custom order or the install order, and brings it in line with the apps.
    /// When zContainer comes back from an app, it opens on the page the app
    /// was opened from, as iOS does.
    init(coordinator: AppLaunchCoordinator) {
        self.coordinator = coordinator
        sharedModel = coordinator.sharedModel
        let apps = coordinator.sharedModel.apps
        if let saved = HomeLayoutStorage.load() {
            layout = saved
        } else {
            layout = .firstLaunch(apps: apps, customOrder: HomeLayoutStorage.legacyCustomOrder())
            HomeLayoutStorage.save(layout)
        }
        let returnPage = min(HomeLayoutStorage.takeReturnPage(), max(layout.pages.count - 1, 0))
        page = returnPage
        builtPages = (returnPage - 1)...(returnPage + 1)
        syncApps(apps)
    }

    /// Reports every change to the list of apps the Home Screen shows. The
    /// Home Screen view passes each new list to `syncApps(_:)`.
    var appsPublisher: Published<[LCAppModel]>.Publisher {
        sharedModel.$apps
    }

    /// The layout on screen: the saved one, or while an icon is dragged, the
    /// one with the icon where it would drop.
    var displayedLayout: HomeLayout {
        drag?.preview ?? layout
    }

    /// The icons on the pages and where each one shows.
    var gridPlacements: [HomePlacement] {
        let shown = displayedLayout
        var placements: [HomePlacement] = []
        for (page, items) in shown.pages.enumerated() {
            for (index, item) in items.enumerated() where item != drag?.item {
                placements.append(HomePlacement(item: item, slot: .page(page, index: index), isLifted: false))
            }
        }
        if let drag, drag.origin.page != nil {
            let slot = drag.target.page != nil ? drag.target : drag.origin
            placements.append(HomePlacement(item: drag.item, slot: slot, isLifted: true))
        }
        return placements
    }

    /// The icons in a folder and where each one shows. An icon dragged out of
    /// the folder keeps its view here, hidden, so its drag goes on.
    func folderPlacements(_ id: String) -> [HomePlacement] {
        let items = displayedLayout.folders[id]?.items ?? []
        var placements: [HomePlacement] = []
        for (index, item) in items.enumerated() where item != drag?.item {
            placements.append(HomePlacement(item: item, slot: .folder(id, index: index), isLifted: false))
        }
        if let drag, drag.origin.folder == id {
            let slot = drag.target.folder == id ? drag.target : drag.origin
            placements.append(HomePlacement(item: drag.item, slot: slot, isLifted: true))
        }
        return placements
    }

    /// The icons on the pages that are built, and the icon being dragged,
    /// whose view has to stay so its drag gesture goes on. The page showing
    /// and its neighbors always count as built, even before `builtPages`
    /// catches up with a new page.
    var visibleGridPlacements: [HomePlacement] {
        let current = page ?? 0
        let built = min(builtPages.lowerBound, current - 1)...max(builtPages.upperBound, current + 1)
        return gridPlacements.filter { placement in
            placement.isLifted || built.contains(placement.slot.page ?? 0)
        }
    }

    /// The icons in the dock and where each one shows.
    var dockPlacements: [HomePlacement] {
        let shown = displayedLayout
        var placements: [HomePlacement] = []
        for (index, item) in shown.dock.enumerated() where item != drag?.item {
            placements.append(HomePlacement(item: item, slot: .dock(index), isLifted: false))
        }
        if let drag, drag.origin.isInDock {
            let slot = drag.target.isInDock ? drag.target : drag.origin
            placements.append(HomePlacement(item: drag.item, slot: slot, isLifted: true))
        }
        return placements
    }

    /// How many pages there are to swipe through, including the page an app
    /// being installed will land on.
    var pageCount: Int {
        var count = displayedLayout.pages.count
        if coordinator.isInstalling, let page = displayedLayout.nextFreeSlot.page {
            count = max(count, page + 1)
        }
        return max(count, 1)
    }

    /// Brings the layout in line with the apps the Home Screen shows: new
    /// apps take the next free slot, and removed or hidden apps leave theirs.
    /// When that leaves fewer pages, the last one shows instead of one that
    /// is gone.
    func syncApps(_ newApps: [LCAppModel]) {
        defer {
            clampPage()
        }
        var lookup: [String: LCAppModel] = [:]
        var keys: [String] = []
        for app in newApps {
            guard let key = app.homeKey, lookup[key] == nil else {
                continue
            }
            lookup[key] = app
            keys.append(key)
        }
        apps = lookup

        var updated = layout
        updated.reconcile(withAppKeys: keys)
        if updated != layout {
            withAnimation(HomeDesign.reflow) {
                layout = updated
            }
            HomeLayoutStorage.save(updated)
        }
        // A folder whose last app went away closes with it, and one that lost
        // its last page shows the page now last.
        if let openFolderID, updated.folders[openFolderID] == nil, drag == nil {
            self.openFolderID = nil
            isFolderShown = false
        } else if let openFolderID, let folder = updated.folders[openFolderID], let folderPage, folderPage >= folder.pageCount {
            self.folderPage = folder.pageCount - 1
        }

        guard var drag else {
            return
        }
        if updated.slot(of: drag.item) == nil {
            cancelDrag()
        } else {
            drag.preview = updated.moving(drag.item, to: drag.target)
            self.drag = drag
        }
    }

    /// Ends edit mode, closes search and closes the screen open over the Home
    /// Screen, so it shows what a link just started, such as an install.
    func showHomeScreen() {
        presentedScreen = nil
        if isSearching {
            closeSearch()
        }
        if isEditing {
            endEditing()
        }
    }

    /// Follows a link zContainer was opened with: links that do something in
    /// an app, or bring up zContainer, show the Home Screen, as do
    /// certificates sent to zContainer and requests from Zeus, whose
    /// questions show over it.
    func handle(_ route: HomeRoute) {
        switch route {
        case .home, .app, .certificate, .certificateFile, .zeusRequests:
            showHomeScreen()
        }
    }
}
