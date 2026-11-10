//
//  HomeAppPickerGrid.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Apps to pick from, with their icons and names as the Home Screen draws
/// them, as many to a row as fit: four on iPhone. For the split screen's
/// second half and the apps the multitask dock's plus offers.
struct HomeAppPickerGrid: View {
    /// The apps to show.
    let apps: [LCAppModel]
    /// Where things go on this screen, for the icons' size.
    let metrics: HomeMetrics
    /// What picking an app does.
    let onPick: (LCAppModel) -> Void

    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: metrics.cellWidth), spacing: 0)], spacing: 18) {
            ForEach(apps, id: \.self) { app in
                Button {
                    onPick(app)
                } label: {
                    HomeIconContent(item: .app(app.homeKey ?? ""), app: app, metrics: metrics, showsLabel: true, darkModeIcon: darkModeIcon)
                }
                .buttonStyle(HomeIconButtonStyle())
                .accessibilityLabel(app.displayName)
            }
        }
    }
}
