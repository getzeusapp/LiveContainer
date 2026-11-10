//
//  AppAppearance.swift
//  LiveContainerSwiftUI
//

import UIKit

/// zContainer's app theme, chosen in Settings > Appearance: light or dark as
/// iOS is, or always Light or Dark whatever iOS uses. SystemAppearance gives
/// zContainer's scenes the choice, so its screens, the Home Screen's glass
/// and wallpaper, and apps' icons all follow it.
enum AppAppearance: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    /// The defaults key the choice is saved under, in the app group's defaults.
    static let storageKey = "ZCAppearance"

    var id: Self {
        self
    }

    /// The choice's name in Settings.
    var title: String {
        switch self {
        case .automatic:
            "zc.settings.appearance.theme.automatic".loc
        case .light:
            "zc.settings.appearance.theme.light".loc
        case .dark:
            "zc.settings.appearance.theme.dark".loc
        }
    }

    /// The style zContainer's scenes are given, or nil to follow iOS.
    var interfaceStyle: UIUserInterfaceStyle? {
        switch self {
        case .automatic:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    /// The choice saved in Settings, Automatic until one is made.
    static var saved: AppAppearance {
        LCUtils.appGroupUserDefault.string(forKey: storageKey).flatMap(AppAppearance.init(rawValue:)) ?? .automatic
    }
}
