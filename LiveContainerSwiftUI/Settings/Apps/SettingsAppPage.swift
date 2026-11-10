//
//  SettingsAppPage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One app's settings, opened from its row in Settings > Apps, like an app's
/// page in the Settings app. It shows LiveContainer's app settings as they
/// are, with Add to Home Screen in the toolbar, and goes back to the list
/// when the app hides or shows itself, which moves it between Apps and
/// Hidden Apps.
struct SettingsAppPage: View {
    let app: LCAppModel

    @Environment(AppLaunchCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        LCAppSettingsView(model: app)
            .settingsPageMargins()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    AddToHomeScreenButton(app: app)
                }
            }
            .onChange(of: coordinator.appSettingsCloseRequests, close)
    }

    private func close() {
        dismiss()
    }
}
