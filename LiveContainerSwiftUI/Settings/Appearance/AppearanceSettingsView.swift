//
//  AppearanceSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > Appearance: zContainer's app theme, Light, Dark or Automatic as
/// iOS is, which apps' icons follow too; whether the Home button floats over
/// the apps you open, which it doesn't until it's turned on here, while
/// zContainer's own screens always show it; on iPad, whether the dock shows
/// the apps opened most recently after its icons, as iPadOS's Show Suggested
/// and Recent Apps in Dock does, on until it's turned off; and zContainer's
/// own icon on the iPhone's Home Screen, which a second zContainer doesn't
/// offer, so it keeps the icon that tells it apart.
struct AppearanceSettingsView: View {
    @AppStorage(AppAppearance.storageKey, store: LCUtils.appGroupUserDefault) private var appearance = AppAppearance.automatic

    /// Whether apps show the Home button, which TweakLoader reads as
    /// "LCShowHomeButtonInApps" before it draws the button over an app. Off
    /// until it's turned on.
    @AppStorage("LCShowHomeButtonInApps") private var showsHomeButtonInApps = false

    /// Whether the iPad's dock shows recent apps, which the Home Screen
    /// follows.
    @AppStorage(HomeDockRecents.settingKey) private var showsDockRecents = true

    var body: some View {
        List {
            Section {
                AppThemePicker(appearance: $appearance)
            } header: {
                Text("zc.settings.appearance.theme".loc)
                    .settingsSectionHeader()
            }

            Section {
                Toggle("zc.settings.appearance.homeButtonInApps".loc, isOn: $showsHomeButtonInApps)
            } footer: {
                Text("zc.settings.appearance.homeButtonInAppsFooter".loc)
            }

            if !SharedModel.isPhone {
                Section {
                    Toggle("zc.settings.appearance.dockRecents".loc, isOn: $showsDockRecents)
                } footer: {
                    Text("zc.settings.appearance.dockRecentsFooter".loc)
                }
            }

            if UIApplication.shared.supportsAlternateIcons && DataManager.shared.model.multiLCStatus != 2 {
                Section {
                    AppIconPicker()
                } header: {
                    Text("zc.settings.appIcon".loc)
                        .settingsSectionHeader()
                }
            }
        }
        .navigationTitle("zc.settings.appearance".loc)
        .navigationBarTitleDisplayMode(.inline)
    }
}
