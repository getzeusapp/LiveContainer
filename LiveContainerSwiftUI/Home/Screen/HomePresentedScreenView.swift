//
//  HomePresentedScreenView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The screen open over the Home Screen: zContainer's Settings, or an app's
/// settings. The Home button at the bottom goes back to the Home Screen from
/// any of its pages, or on an iPad, beside the edge the iPad's own Home
/// button is on as it's turned. Settings on an iPad wide enough for its
/// sidebar shows the button at the bottom of the sidebar instead, while that
/// edge is the bottom.
struct HomePresentedScreenView: View {
    /// Which screen to show.
    let screen: HomePresentedScreen

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.homeButtonEdge) private var homeButtonEdge
    /// This screen's whole size, measured on iPad only and handed down as
    /// `presentedScreenSize`. It stays nil on iPhone.
    @State private var size: CGSize?
    /// Whether Settings' list shows the Home button in its own bottom bar.
    @State private var settingsHasHomeButton = false

    var body: some View {
        Group {
            switch screen {
            case .settings:
                SettingsView()
            case .appSettings(let app):
                HomeAppSettingsScreen(app: app)
            }
        }
        .onPreferenceChange(SettingsBottomBarHomeButton.self) { hasButton in
            settingsHasHomeButton = hasButton
        }
        .homeButtonBar(isShown: showsHomeButtonBar && !settingsHasHomeButton, action: model.goHome)
        .background {
            if !SharedModel.isPhone {
                Color.clear
                    .ignoresSafeArea()
                    .onGeometryChange(for: CGSize.self, of: { $0.size }, action: sizeChanged)
            }
        }
        .environment(\.presentedScreenSize, size)
        // A screen presented over the Home Screen doesn't keep the tint given
        // the window's root, so it's given again: Zeus's pink, switches too.
        .tint(AppAccent.color)
    }

    /// Whether the Home button shows in a bar across the bottom, which it
    /// does except where Settings puts it in its sidebar.
    private var showsHomeButtonBar: Bool {
        guard case .settings = screen else {
            return true
        }
        return !SettingsSplitView.placesHomeButtonInSidebar(horizontalSizeClass, edge: homeButtonEdge)
    }

    private func sizeChanged(_ newSize: CGSize) {
        size = newSize
    }
}
