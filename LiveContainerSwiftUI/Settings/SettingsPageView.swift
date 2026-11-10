//
//  SettingsPageView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The page a row of Settings opens: pushed over the list on iPhone, and on
/// iPad shown in the detail column beside the sidebar.
struct SettingsPageView: View {
    /// Which page to show.
    let page: SettingsPage

    @EnvironmentObject private var sharedModel: SharedModel

    var body: some View {
        switch page {
        case .zeus, .attention:
            ZeusSettingsView()
        case .general:
            GeneralSettingsView()
                .settingsPageMargins()
        case .appearance:
            AppearanceSettingsView()
                .settingsPageMargins()
        case .wallpaper:
            WallpaperSettingsView()
                .settingsPageMargins()
        case .apps:
            AppsSettingsView()
        case .advanced:
            AdvancedSettingsView()
                .settingsPageMargins()
        case .app(let key):
            // Apps, should the app have gone since search found it.
            if let app = sharedModel.apps.first(where: { $0.homeKey == key }) {
                SettingsAppPage(app: app)
            } else {
                AppsSettingsView()
            }
        }
    }
}
