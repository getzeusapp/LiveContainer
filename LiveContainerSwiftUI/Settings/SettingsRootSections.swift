//
//  SettingsRootSections.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The rows Settings opens on, in the Settings app's order: Zeus on top where
/// the Apple Account is, with a row asking for attention under it when
/// zContainer can't sign apps; then General, Appearance and Wallpaper; then
/// Apps, which holds each app's settings, and Add App; and last Advanced,
/// where the Settings app puts Developer. Each row opens a page of its own,
/// except "Finish Setting Up zContainer", which opens onboarding again over
/// the Home Screen, and Add App, a menu of the ways to add an app.
struct SettingsRootSections: View {
    @Environment(ZeusConnection.self) private var connection
    @Environment(OnboardingModel.self) private var onboarding

    var body: some View {
        Section {
            SettingsPageLink(page: .zeus) {
                ZeusCard()
            }
        }

        if let attention = connection.attention {
            Section {
                if attention == .notSetUp {
                    Button(action: onboarding.present) {
                        ZeusAttentionRow(attention: attention, showsChevron: true)
                    }
                } else {
                    SettingsPageLink(page: .attention) {
                        ZeusAttentionRow(attention: attention)
                    }
                }
            }
        }

        Section {
            SettingsPageLink(page: .general) {
                SettingsRow(page: .general)
            }

            SettingsPageLink(page: .appearance) {
                SettingsRow(page: .appearance)
            }

            SettingsPageLink(page: .wallpaper) {
                SettingsRow(page: .wallpaper)
            }
        }

        Section {
            SettingsPageLink(page: .apps) {
                SettingsRow(page: .apps)
            }

            SettingsAddAppRow()
        }

        Section {
            SettingsPageLink(page: .advanced) {
                SettingsRow(page: .advanced)
            }
        }
    }
}
