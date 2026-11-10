//
//  AppAccent.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UIKit

/// zContainer's accent color: Zeus's pink, the color Zeus starts in, for
/// buttons, links, switches, checks, selections and progress everywhere, in
/// place of iOS's blue. The asset catalog's AccentColor is the same pink.
enum AppAccent {
    static let uiColor = UIColor(red: 0xDB / 255, green: 0x2C / 255, blue: 0x99 / 255, alpha: 1)
    static let color = Color(uiColor: uiColor)

    /// Tints every window zContainer opens, before the first one is made, so
    /// UIKit's alerts and menus, and the screens SwiftUI presents over its
    /// own, such as Settings, are pink too.
    @MainActor
    static func tintWindows() {
        UIWindow.appearance().tintColor = uiColor
    }
}
