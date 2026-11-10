//
//  AdvancedSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > Advanced: LiveContainer's power-user settings, with the pages
/// it already had. Tweaks and Multitask; the JIT enabler and the 32-bit
/// emulator; Don't Sign New Apps; whether guest apps switch apps and open
/// links without asking; the frame on icons made by Add to Home Screen; and
/// the JIT-less diagnosis. zContainer's version sits at the bottom, and five
/// taps on it add the Developer page.
struct AdvancedSettingsView: View {
    @EnvironmentObject private var sharedModel: SharedModel

    @AppStorage("LCJITEnablerType", store: LCUtils.appGroupUserDefault) private var jitEnabler: JITEnablerType = .Zeus
    @AppStorage("LCSelected32BitEmulator", store: LCUtils.appGroupUserDefault) private var selected32BitEmulator = ""
    @AppStorage("LCDontSignApp", store: LCUtils.appGroupUserDefault) private var dontSignApp = false
    // In the app group, where apps in multitasking windows read them too.
    @AppStorage("LCSwitchAppWithoutAsking", store: LCUtils.appGroupUserDefault) private var silentSwitchApp = false
    @AppStorage("LCOpenWebPageWithoutAsking", store: LCUtils.appGroupUserDefault) private var silentOpenWebPage = false
    @AppStorage("LCFrameShortcutIcons") private var frameShortcutIcons = false

    var body: some View {
        List {
            // A second zContainer uses the first one's tweaks.
            if sharedModel.multiLCStatus != 2 {
                Section {
                    NavigationLink {
                        LCTweakFolderView(baseUrl: LCPath.tweakPath, isRoot: true)
                            .settingsPageMargins()
                    } label: {
                        Text("lc.tabView.tweaks".loc)
                    }
                }
            }

            Section {
                NavigationLink {
                    LCMultitaskSettingView()
                        .settingsPageMargins()
                } label: {
                    Text("lc.appBanner.multitask".loc)
                }
            } footer: {
                Text("lc.settings.multitaskDesc".loc)
            }

            Section {
                NavigationLink {
                    JITSettingsView()
                        .settingsPageMargins()
                } label: {
                    LabeledContent("zc.settings.advanced.jit".loc, value: jitEnabler.displayName)
                }

                Picker("zc.settings.advanced.emulator".loc, selection: $selected32BitEmulator) {
                    Text("lc.common.none".loc)
                        .tag("")
                    ForEach(sharedModel.arm32EmuApps, id: \.self) { app in
                        Text(app.displayName)
                            .tag(app.appInfo.relativeBundlePath ?? "")
                    }
                }
                .pickerStyle(.navigationLink)
            } footer: {
                Text("zc.settings.advanced.emulatorFooter".loc)
            }

            Section {
                Toggle("lc.settings.dontSign".loc, isOn: $dontSignApp)
            } footer: {
                Text("lc.settings.dontSignDesc".loc)
            }

            Section {
                Toggle("lc.settings.silentSwitchApp".loc, isOn: $silentSwitchApp)
            } footer: {
                Text("lc.settings.silentSwitchAppDesc".loc)
            }

            Section {
                Toggle("lc.settings.silentOpenWebPage".loc, isOn: $silentOpenWebPage)
            } footer: {
                Text("lc.settings.silentOpenWebPageDesc".loc)
            }

            Section {
                Toggle("lc.settings.FrameIcon".loc, isOn: $frameShortcutIcons)
            } footer: {
                Text("zc.settings.advanced.frameIconsFooter".deviceLoc)
            }

            Section {
                NavigationLink {
                    LCJITLessDiagnoseView()
                        .settingsPageMargins()
                } label: {
                    Text("lc.settings.jitlessDiagnose".loc)
                }

                if sharedModel.developerMode {
                    NavigationLink {
                        DeveloperSettingsView()
                            .settingsPageMargins()
                    } label: {
                        Text("zc.settings.developer".loc)
                    }
                }
            } footer: {
                SettingsVersionFooter()
            }
        }
        .navigationTitle("zc.settings.advanced".loc)
        .navigationBarTitleDisplayMode(.inline)
    }
}
