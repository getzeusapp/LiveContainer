//
//  HomeFolderIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A folder's icon, as iOS draws it: glass the size of an app icon,
/// holding its first nine icons small, three by three from the top left,
/// with its name under it unless it is in the dock.
struct HomeFolderIcon: View {
    /// The folder, or nil while it's going away.
    let folder: HomeFolder?
    /// Where things go on this screen, for the icon's size.
    let metrics: HomeMetrics
    /// Whether the name shows under the icon.
    let showsLabel: Bool
    /// Whether the apps' icons show in their dark versions.
    let darkModeIcon: Bool

    var body: some View {
        VStack(spacing: HomeDesign.labelSpacing) {
            tile
            if showsLabel {
                HomeIconLabel(title: folder?.name ?? "")
            }
        }
    }

    /// The glass with the small icons on it, in a grid as wide as it is
    /// tall, centered on the glass.
    private var tile: some View {
        let (mini, gap) = HomeDesign.folderMini(iconSize: metrics.iconSize)
        let items = Array((folder?.items ?? []).prefix(HomeFolder.iconsPerPage))
        let columns = HomeFolderMetrics.columns

        return VStack(spacing: gap) {
            ForEach(0..<columns, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        HomeFolderMiniIcon(item: index < items.count ? items[index] : nil, size: mini, darkModeIcon: darkModeIcon)
                    }
                }
            }
        }
        .frame(width: metrics.iconSize, height: metrics.iconSize)
        .homeFolderGlass(cornerRadius: metrics.iconCornerRadius)
        .accessibilityHidden(true)
    }
}
