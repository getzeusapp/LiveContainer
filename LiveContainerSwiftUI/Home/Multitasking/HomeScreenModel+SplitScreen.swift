//
//  HomeScreenModel+SplitScreen.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Split screen on iPhone, as other phones have it: an app opened from its
/// long-press menu takes the top half, or the left in landscape, and the
/// other half offers the apps to open beside it. LCWindowSnapManager lays
/// the two apps out and runs the divider between them; the Home Screen
/// follows it to show the apps on offer while it waits.
extension HomeScreenModel {
    /// Whether an app can go into the split screen: on iPhone, when it can
    /// run with multitasking.
    func canOpenInSplitScreen(_ app: LCAppModel) -> Bool {
        SharedModel.isPhone && canRunWithMultitasking(app)
    }

    /// Opens an app in the split screen's first half, or brings it there if
    /// it's running. The second half then offers the apps to open beside it.
    func openInSplitScreen(_ app: LCAppModel) {
        openForSplitScreen(app, into: .first)
    }

    /// Opens the app picked for the split screen's second half.
    func openBesideSplitApp(_ app: LCAppModel) {
        guard !isOpeningSplitApp else {
            return
        }
        openForSplitScreen(app, into: .second)
    }

    /// Stops waiting for a second app: the first fills the screen again.
    func cancelSplitScreenPicker() {
        LCWindowSnapManager.shared.cancelPhoneSplit()
    }

    /// Follows the split screen: whether it waits for its second app, and
    /// which app is in its first half.
    func phoneSplitDidChange() {
        let manager: LCWindowSnapManager = LCWindowSnapManager.shared
        isPickingSplitApp = manager.isAwaitingSecondPhoneSplitApp
        splitFirstDataUUID = manager.firstPhoneSplitDataUUID
    }

    /// The apps offered for the second half, in the Home Screen's order,
    /// without the app in the first half or apps that can't go there.
    var splitScreenCandidates: [LCAppModel] {
        appsInHomeScreenOrder.filter { app in
            canOpenInSplitScreen(app) && app.uiSelectedContainer?.folderName != splitFirstDataUUID
        }
    }

    /// Asks for the app's window to go into a half, and opens the app in a
    /// window whatever its setting, or brings it forward if it's running.
    /// A request no window took, as when Face ID was cancelled, is dropped.
    func openForSplitScreen(_ app: LCAppModel, into slot: LCWindowSnapSlot) {
        let manager: LCWindowSnapManager = LCWindowSnapManager.shared
        manager.requestPhoneSplitSlot(slot)
        isOpeningSplitApp = true
        Task {
            let didOpen = await coordinator.open(app, multitask: true)
            isOpeningSplitApp = false
            if !didOpen {
                manager.cancelPhoneSplitRequest()
            }
        }
    }
}
