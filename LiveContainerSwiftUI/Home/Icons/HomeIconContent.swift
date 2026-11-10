//
//  HomeIconContent.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What an icon shows: the app's icon, the Settings icon or a folder's, with
/// its name under it unless it is in the dock, in a frame the width of its
/// column so long names have room.
struct HomeIconContent: View {
    /// The icon to show.
    let item: HomeItem
    /// The app behind the icon, or nil for Settings.
    let app: LCAppModel?
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// Whether the name shows under the icon.
    let showsLabel: Bool
    /// Whether an app's icon shows in its dark version, as the dark icons
    /// setting asks. The views showing many icons read the setting once and
    /// pass it down, rather than each icon reading it.
    let darkModeIcon: Bool
    /// The namespace screens zoom out of this icon in, or nil where none does,
    /// such as in search.
    var zoomNamespace: Namespace.ID?

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        Group {
            switch item {
            case .settings:
                HomeSettingsIcon(metrics: metrics, showsLabel: showsLabel, zoomSource: zoomSource)
            case .app:
                if let app {
                    HomeAppIcon(app: app, metrics: metrics, showsLabel: showsLabel, darkModeIcon: darkModeIcon, zoomSource: zoomSource)
                }
            case .folder(let id):
                HomeFolderIcon(folder: model.displayedLayout.folders[id], metrics: metrics, showsLabel: showsLabel, darkModeIcon: darkModeIcon)
            case .widget:
                // Widgets draw as HomeWidgetCell, not as icons.
                EmptyView()
            }
        }
        .frame(
            width: showsLabel ? metrics.cellWidth : metrics.iconSize,
            height: showsLabel ? metrics.cellHeight : metrics.iconSize,
            alignment: .top
        )
    }

    private var zoomSource: HomeZoomSource {
        HomeZoomSource(id: item.id, namespace: zoomNamespace)
    }
}
