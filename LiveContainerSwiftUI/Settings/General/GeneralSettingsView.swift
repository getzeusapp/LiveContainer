//
//  GeneralSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > General, laid out like the General page of the Settings app:
/// the card that says what the page is for, then rows with the Settings
/// app's icons for About zContainer (the credits and licenses), the space the
/// apps take and the tools that tidy their data, and Reset.
struct GeneralSettingsView: View {
    @EnvironmentObject private var sharedModel: SharedModel

    var body: some View {
        List {
            SettingsPageHeader(page: .general, detail: "zc.settings.general.detail".loc)

            Section {
                NavigationLink {
                    LCAboutView()
                        .settingsPageMargins()
                } label: {
                    // The Settings app's About, which is about the device.
                    SettingsRow(title: "zc.settings.about".loc, systemImage: SharedModel.isPhone ? "iphone" : "ipad", color: .gray, graphicIcon: "com.apple.graphic-icon.about-current-device") {
                        Text(Self.version)
                    }
                }
            } footer: {
                Text("lc.settings.warning".loc)
            }

            Section {
                // A second zContainer keeps no apps of its own to measure.
                if sharedModel.multiLCStatus != 2 {
                    NavigationLink {
                        LCStorageManagementView()
                            .settingsPageMargins()
                    } label: {
                        // iPhone Storage's.
                        SettingsRow(title: "zc.settings.storage".loc, systemImage: "internaldrive.fill", color: .gray, graphicIcon: "com.apple.graphic-icon.internal-drive")
                    }
                }

                NavigationLink {
                    LCDataManagementView()
                        .settingsPageMargins()
                } label: {
                    // A folder, for the apps' data folders it tidies.
                    SettingsRow(title: "lc.settings.dataManagement".loc, systemImage: "folder.fill", color: .cyan, graphicIcon: "com.apple.graphic-icon.file-sharing")
                }
            }

            Section {
                NavigationLink {
                    ResetSettingsView()
                        .settingsPageMargins()
                } label: {
                    // Transfer or Reset iPhone's, or iPad's.
                    SettingsRow(title: "lc.common.reset".loc, systemImage: "arrow.counterclockwise", color: .gray, graphicIcon: SharedModel.isPhone ? "com.apple.graphic-icon.transfer-or-reset-iphone" : "com.apple.graphic-icon.transfer-or-reset-ipad")
                }
            }
        }
        .navigationTitle("zc.settings.general".loc)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// zContainer's version, as About shows it in full.
    private static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}
