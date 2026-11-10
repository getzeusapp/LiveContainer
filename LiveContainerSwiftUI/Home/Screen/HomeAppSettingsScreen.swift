//
//  HomeAppSettingsScreen.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An app's settings, opened from its long-press menu, with Done to go back
/// to the Home Screen and, as in Settings > Apps, Add to Home Screen. On iPad
/// the settings stay in a readable column in the middle of the screen, so
/// their switches sit near their labels.
struct HomeAppSettingsScreen: View {
    /// The app whose settings show.
    let app: LCAppModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LCAppSettingsView(model: app)
                // On iPad the settings keep their readable column instead.
                .settingsPageMargins(isOnPad: false)
                .readableContentWidth(Self.padReadableWidth)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("lc.common.done".loc, action: close)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        AddToHomeScreenButton(app: app)
                    }
                }
        }
    }

    private func close() {
        dismiss()
    }

    /// The widest the settings get on iPad.
    private static let padReadableWidth = 700.0
}
