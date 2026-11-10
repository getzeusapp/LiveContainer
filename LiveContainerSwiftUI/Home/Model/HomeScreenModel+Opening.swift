//
//  HomeScreenModel+Opening.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Opening things from the Home Screen: apps, which zoom open from their icon
/// before zContainer turns into them, Settings and an app's settings, which
/// open over the Home Screen, and the actions in an app's long-press menu.
extension HomeScreenModel {
    /// Opens what an icon stands for, unless edit mode is on or search covers
    /// the icons: Settings, or the app, after Face ID when the app is locked.
    /// A folder opens in edit mode too, as on iOS.
    func open(_ item: HomeItem) {
        guard !isSearching, drag == nil else {
            return
        }
        if case .folder(let id) = item {
            openFolder(id)
            return
        }
        guard !isEditing else {
            return
        }
        switch item {
        case .settings:
            present(.settings)
            noteOpenedBehindScreen(item)
        case .app(let key):
            guard let app = apps[key] else {
                return
            }
            launch(app, from: item)
        case .folder, .widget:
            break
        }
    }

    /// Launches an app through the coordinator. Just before zContainer turns
    /// into the app, the app zooms open from `startFrame`, or else from its
    /// icon, or from the middle of the screen when its icon isn't showing.
    /// The page showing is saved then, as zContainer quits on the way into
    /// the app and comes back to it. The iPad dock's recent apps note it
    /// once the zoom covers them, as iPadOS's change behind the app, or once
    /// it has opened without the zoom, with JIT or in a window.
    func launch(_ app: LCAppModel, from item: HomeItem? = nil, startingAt startFrame: CGRect? = nil) {
        let zoomItem = item ?? .app(app.homeKey ?? "")
        let frame = startFrame ?? item.flatMap(iconFrame(of:)) ?? centeredIconFrame()
        let returnPage = page ?? 0
        let opened = app.homeKey.map(HomeItem.app)
        // An app that needs JIT goes to it without the zoom, so its page is
        // saved now. Any other app saves it as zContainer quits into it.
        if app.appInfo.isJITNeeded || app.appInfo.is32bit {
            HomeLayoutStorage.saveReturnPage(returnPage)
        }
        Task {
            let didOpen = await coordinator.open(app) {
                HomeLayoutStorage.saveReturnPage(returnPage)
                await self.playLaunchZoom(HomeLaunchZoom(item: zoomItem, app: app, iconFrame: frame))
                if let opened {
                    self.noteOpened(opened)
                }
            }
            if didOpen, let opened {
                noteOpened(opened)
            }
        }
    }

    /// Plays the launch zoom and returns when it has filled the screen. The
    /// zoom view calls `launchZoomDidFinish()` at the end of its animation.
    private func playLaunchZoom(_ zoom: HomeLaunchZoom) async {
        await withCheckedContinuation { continuation in
            launchZoomContinuation?.resume()
            launchZoomContinuation = continuation
            launchZoom = zoom
        }
        // zContainer quits as the app opens. If it's still here after a few
        // seconds, the launch didn't happen, so the Home Screen comes back.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            if self?.launchZoom?.id == zoom.id {
                self?.launchZoom = nil
            }
        }
    }

    /// Lets the launch go ahead once the zoom has filled the screen.
    func launchZoomDidFinish() {
        launchZoomContinuation?.resume()
        launchZoomContinuation = nil
    }

    /// An icon's frame on screen, when it shows on the page in view, in the
    /// dock, or on the open folder's page showing.
    func iconFrame(of item: HomeItem) -> CGRect? {
        guard let metrics else {
            return nil
        }
        switch layout.slot(of: item) {
        case .page(let page, let index)?:
            guard page == (self.page ?? 0) else {
                return nil
            }
            return metrics.iconFrame(around: layout.center(ofPage: page, index: index, on: metrics))
        case .dock(let index)?:
            // At the size the dock draws it, which an iPad dock holding more
            // than fit across it shrinks. Elsewhere it is the pages' icon size.
            let contents = dockContents(of: layout)
            let size = metrics.dockIconSize(contents)
            let center = metrics.dockIconCenter(at: index, in: contents)
            return CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
        case .folder(let id, let index)?:
            guard id == openFolderID, isFolderShown, index / HomeFolder.iconsPerPage == (folderPage ?? 0) else {
                return nil
            }
            return metrics.iconFrame(around: folderIconCenter(at: index, metrics: metrics))
        case nil:
            return nil
        }
    }

    private func centeredIconFrame() -> CGRect {
        guard let metrics else {
            return .zero
        }
        return metrics.iconFrame(around: CGPoint(x: metrics.size.width / 2, y: metrics.size.height / 2))
    }

    // MARK: Screens over the Home Screen

    /// Opens a screen over the Home Screen. From iOS 18 it zooms out of its
    /// icon and covers the screen, and so it does on iPad on iOS 17, so the
    /// status bar follows it from then on.
    func present(_ screen: HomePresentedScreen) {
        if HomeScreenPresentation.coversHomeScreen {
            isCoveredByScreen = true
        }
        presentedScreen = screen
    }

    /// Hands the status bar back to the Home Screen once the screen over it
    /// has closed, and opens Files or the link question if the screen asked
    /// to add an app.
    func presentedScreenDidClose() {
        isCoveredByScreen = false
        zoomsFromRecent = nil
        // Settings and app settings cover the Home Screen full screen, which
        // takes it off the window until now.
        if #available(iOS 16.0, *), MultitaskDockManager.hasWindows {
            MultitaskDockManager.shared.keepWindowsAboveHomeScreen()
        }
        guard let addition = pendingAddition else {
            return
        }
        pendingAddition = nil
        switch addition {
        case .ipaFile:
            chooseIPA()
        case .link:
            askForInstallURL()
        }
    }

    /// Opens an app's settings, zooming out of its icon, or out of its place
    /// among the iPad dock's recent apps when they were opened from there.
    func showSettings(for app: LCAppModel, fromRecent: Bool = false) {
        if fromRecent, let key = app.homeKey {
            zoomsFromRecent = .app(key)
        }
        present(.appSettings(app))
    }

    /// Closes an app's settings, as the app asks before it hides itself.
    func closeAppSettings() {
        if case .appSettings = presentedScreen {
            presentedScreen = nil
        }
    }

    // MARK: Long-press actions

    /// Opens Add to Home Screen's sheet for an app, as its long-press menu
    /// does, once the menu has closed, so the sheet can open over the Home
    /// Screen. `style` is its icon's.
    func addToHomeScreen(_ app: LCAppModel, style: GeneratedIconStyle) {
        Task { [weak self] in
            try? await Task.sleep(for: HomeDesign.menuCloseDuration)
            self?.shortcutRequest = AppShortcutRequest(app: app, style: style)
        }
    }

    /// Opens an app with JIT, as Open with JIT in its long-press menu does:
    /// zContainer asks the JIT tool set in Settings, Zeus unless another was
    /// chosen, to give it JIT, then turns into the app.
    func openWithJIT(_ app: LCAppModel) {
        HomeLayoutStorage.saveReturnPage(page ?? 0)
        Task {
            if await coordinator.open(app, forceJIT: true), let key = app.homeKey {
                noteOpened(.app(key))
            }
        }
    }

    /// Makes a new container for an app and opens the app in it. A locked app
    /// asks for Face ID before the container is made, so cancelling leaves the
    /// app as it was. Search closes first when the app was found there, so its
    /// zoom shows.
    func openInNewContainer(_ app: LCAppModel) {
        guard app.appInfo.isLocked && !sharedModel.isHiddenAppUnlocked else {
            makeContainerAndLaunch(app)
            return
        }
        Task {
            do {
                guard try await LCUtils.authenticateUser() else {
                    return
                }
            } catch {
                coordinator.errorMessage = error.localizedDescription
                return
            }
            makeContainerAndLaunch(app)
        }
    }

    /// Makes the new container and opens the app in it, once a locked app has
    /// passed Face ID.
    private func makeContainerAndLaunch(_ app: LCAppModel) {
        do {
            try app.makeNewContainer(sharedModel: sharedModel)
        } catch {
            coordinator.errorMessage = error.localizedDescription
            return
        }
        if isSearching {
            closeSearch()
        }
        launch(app, from: app.homeKey.map(HomeItem.app))
    }

    /// Locks an app behind Face ID, Touch ID or the passcode, after asking for
    /// it once, as iOS does. `hiding` also takes the app off the Home Screen;
    /// it then shows only in search's Hidden section.
    func requireAuthentication(for app: LCAppModel, hiding: Bool) {
        Task {
            do {
                guard try await LCUtils.authenticateUser() else {
                    return
                }
            } catch {
                coordinator.errorMessage = error.localizedDescription
                return
            }
            app.uiIsLocked = true
            await app.setLocked(newLockState: true)
            if hiding && !app.appInfo.isHidden {
                await app.toggleHidden()
            }
        }
    }

    /// Unlocks an app, after Face ID. A hidden app comes back to the Home Screen.
    func stopRequiringAuthentication(for app: LCAppModel) {
        Task {
            app.uiIsLocked = false
            await app.setLocked(newLockState: false)
        }
    }

    // MARK: Adding apps

    /// Adds an app from the screen open over the Home Screen, as Settings'
    /// Add App row does: the screen closes, then Files or the link question
    /// open over the Home Screen, where the new app shows as it installs.
    func addApp(_ addition: HomeAddition) {
        pendingAddition = addition
        presentedScreen = nil
    }

    /// Opens Files to pick an IPA, from the add button in edit mode.
    func chooseIPA() {
        isChoosingIPA = true
    }

    /// Notes that Files closed.
    func filePickerDidClose() {
        isChoosingIPA = false
    }

    /// Installs the IPA picked in Files.
    func installPickedFiles(_ urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        Task {
            await coordinator.startInstallApp(url)
        }
    }

    /// Asks for a link to install an app from.
    func askForInstallURL() {
        installURL = ""
        isEnteringInstallURL = true
    }

    /// Installs from the link typed in.
    func installFromEnteredURL() {
        let address = installURL.trimmingCharacters(in: .whitespacesAndNewlines)
        installURL = ""
        guard !address.isEmpty else {
            return
        }
        Task {
            await coordinator.install(fromAddress: address)
        }
    }
}
