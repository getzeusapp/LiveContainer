//
//  HomeHiddenApps.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Hidden section at the end of search, like the Hidden folder of the
/// iOS App Library, drawn as Spotlight draws its sections: a title, with Show
/// at its other end, which asks for Face ID and then shows the hidden apps on
/// a panel under it. It is always there, so it gives nothing away. An app's
/// menu there can stop requiring Face ID, which brings it back to the Home
/// Screen.
struct HomeHiddenApps: View {
    /// How many apps a panel row holds.
    let columns: Int
    /// Where things go on this screen, for the icons' size.
    let metrics: HomeMetrics
    /// Whether it's search's first section, with nothing suggested above it.
    let isFirst: Bool

    @EnvironmentObject private var sharedModel: SharedModel
    @Environment(AppLaunchCoordinator.self) private var coordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeSearchSectionHeader(
                title: "zc.home.hidden".loc,
                actionTitle: sharedModel.isHiddenAppUnlocked ? nil : "zc.home.search.showHidden".loc,
                action: unlock,
                isFirst: isFirst
            )
            if sharedModel.isHiddenAppUnlocked {
                if sharedModel.hiddenApps.isEmpty {
                    Text("zc.home.noHiddenApps".loc)
                        .font(.system(size: HomeDesign.searchHeaderFontSize))
                        .foregroundStyle(.white.opacity(HomeDesign.searchHeaderOpacity))
                        .padding(.top, HomeDesign.searchRowPadding)
                } else {
                    HomeSearchAppPanel(apps: sharedModel.hiddenApps, columns: columns, metrics: metrics)
                }
            }
        }
    }

    /// Asks for Face ID, which shows the hidden apps until zContainer quits.
    private func unlock() {
        Task {
            do {
                _ = try await LCUtils.authenticateUser()
            } catch {
                coordinator.errorMessage = error.localizedDescription
            }
        }
    }
}
