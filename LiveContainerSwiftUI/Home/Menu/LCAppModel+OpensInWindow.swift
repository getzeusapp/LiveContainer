//
//  LCAppModel+OpensInWindow.swift
//  LiveContainerSwiftUI
//

import Foundation

extension LCAppModel {
    /// Whether the app opens in a multitasking window over the Home Screen,
    /// rather than taking over zContainer, for the long-press menu's switch.
    /// Turning it on or off makes the choice the app's own, over the setting
    /// for every app.
    var opensInWindow: Bool {
        get {
            shouldLaunchInMultitaskMode
        }
        set {
            uiIsMultitaskModeSpecificed = newValue ? .yes : .no
        }
    }
}
