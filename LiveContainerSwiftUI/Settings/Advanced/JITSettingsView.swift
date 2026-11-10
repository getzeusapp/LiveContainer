//
//  JITSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > Advanced > JIT: which tool enables JIT for the apps that need
/// it, as a list to tick like the Settings app's choices, and the address and
/// UDID the tools that run as a server need.
struct JITSettingsView: View {
    @AppStorage("LCJITEnablerType", store: LCUtils.appGroupUserDefault) private var enabler: JITEnablerType = .Zeus
    @AppStorage("LCSideJITServerAddress", store: LCUtils.appGroupUserDefault) private var serverAddress = ""
    @AppStorage("LCDeviceUDID", store: LCUtils.appGroupUserDefault) private var deviceUDID = ""

    var body: some View {
        List {
            Section {
                Picker("lc.settings.jitEnabler".loc, selection: $enabler) {
                    ForEach(JITEnablerType.allCases) { type in
                        Text(type.displayName)
                            .tag(type)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("lc.settings.jitEnabler".loc)
                .settingsSectionHeader()
            } footer: {
                Text("lc.settings.JitDesc".loc)
            }

            if enabler.needsServerAddress {
                Section {
                    LabeledContent("lc.settings.JitAddress".loc) {
                        TextField("lc.settings.JitAddress".loc, text: $serverAddress, prompt: Text(verbatim: enabler.addressPlaceholder))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    if enabler == .SideJITServer {
                        LabeledContent("lc.settings.JitUDID".loc) {
                            TextField("lc.settings.JitUDID".loc, text: $deviceUDID)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                }
            }
        }
        .navigationTitle("zc.settings.advanced.jit".loc)
        .navigationBarTitleDisplayMode(.inline)
    }
}
