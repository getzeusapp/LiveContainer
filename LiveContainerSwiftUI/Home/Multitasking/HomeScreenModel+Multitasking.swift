//
//  HomeScreenModel+Multitasking.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The apps that can run with multitasking, which the multitask dock's plus
/// offers and the split screen picks from.
extension HomeScreenModel {
    /// Whether an app can run with multitasking, in its own process: not one
    /// set to open the classic way.
    func canRunWithMultitasking(_ app: LCAppModel) -> Bool {
        app.appInfo.defaultClassicMode == 0
    }

    /// The Home Screen's apps in its order: the dock's, then each page's,
    /// with the apps in folders where the folders are.
    var appsInHomeScreenOrder: [LCAppModel] {
        var seen = Set<String>()
        var ordered: [LCAppModel] = []
        func add(_ item: HomeItem) {
            switch item {
            case .app(let key):
                if seen.insert(key).inserted, let app = apps[key] {
                    ordered.append(app)
                }
            case .folder(let id):
                layout.folders[id]?.items.forEach(add)
            case .settings, .widget:
                break
            }
        }
        layout.dock.forEach(add)
        layout.pages.forEach { $0.forEach(add) }
        return ordered
    }

    /// The apps the multitask dock's plus offers: those that can run with
    /// multitasking and aren't in the dock already, running or not, in the
    /// Home Screen's order.
    var multitaskAddCandidates: [LCAppModel] {
        let inDock = Set(MultitaskDockManager.hasWindows ? MultitaskDockManager.shared.apps.map(\.appUUID) : [])
        return appsInHomeScreenOrder.filter { app in
            guard canRunWithMultitasking(app) else {
                return false
            }
            guard let folderName = app.uiSelectedContainer?.folderName else {
                return true
            }
            return !inDock.contains(folderName) && !MultitaskManager.isUsing(container: folderName)
        }
    }

    /// Opens an app picked from the dock's plus with multitasking, whatever
    /// its setting, and it joins the dock. On iPhone it goes beside the app
    /// that shows, in the split screen: an app filling the screen moves up to
    /// the first half, and in a split screen the new app takes the second.
    /// With no app showing it fills the screen, as it does in a window on
    /// iPad.
    func addToMultitasking(_ app: LCAppModel) {
        isAddingMultitaskApp = false
        if canOpenInSplitScreen(app),
           LCWindowSnapManager.shared.prepareToAddPhoneSplitApp(in: MultitaskDockManager.shared.windowHostingView) {
            openForSplitScreen(app, into: .second)
            return
        }
        Task {
            await coordinator.open(app, multitask: true)
        }
    }
}
