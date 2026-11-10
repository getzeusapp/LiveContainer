//
//  HomeFolderZoom.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The icons of an open folder's page showing, while the folder zooms out of
/// its icon or back into it, as on iOS: each grows from its small place on
/// the folder's icon to its place on the panel, or shrinks back, and its name
/// fades in or out. It draws icons only, without their buttons and gestures;
/// the panel's own icons take over in the same places once the folder is
/// out, and hand back to these as it closes.
struct HomeFolderZoom: View {
    /// The icons of the folder's page showing, at most nine.
    let items: [HomeItem]
    /// The folder's icon on screen, where the icons come from and go back to.
    let iconFrame: CGRect
    /// Whether the icons are out on the panel, rather than small on the icon.
    let isOut: Bool
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// Where things go in the open folder.
    let folderMetrics: HomeFolderMetrics

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        let mini = HomeDesign.folderMini(iconSize: iconFrame.width).size
        let miniScale = mini / metrics.iconSize

        ZStack(alignment: .topLeading) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let center = isOut ? folderMetrics.iconCenter(at: index) : miniCenter(at: index, mini: mini)
                VStack(spacing: HomeDesign.labelSpacing) {
                    HomeIconContent(item: item, app: app(for: item), metrics: metrics, showsLabel: false, darkModeIcon: darkModeIcon)
                    HomeIconLabel(title: model.title(of: item))
                        .opacity(isOut ? 1 : 0)
                }
                .frame(width: metrics.cellWidth, height: metrics.cellHeight, alignment: .top)
                .scaleEffect(isOut ? 1 : miniScale, anchor: iconAnchor)
                // The icon being dragged keeps its place, empty: its copy is
                // under the finger.
                .opacity(item == model.drag?.item ? 0 : 1)
                // Laid out like an icon with its name, so its center sits below
                // the icon's, as the panel's icons do.
                .position(x: center.x, y: center.y - metrics.iconSize / 2 + metrics.cellHeight / 2)
            }
        }
        .frame(width: metrics.size.width, height: metrics.size.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The icon's center in its view, which it grows and shrinks around.
    private var iconAnchor: UnitPoint {
        UnitPoint(x: 0.5, y: metrics.iconSize / 2 / metrics.cellHeight)
    }

    /// The center of a small icon on the folder's icon, on screen: three by
    /// three, centered on the icon, as HomeFolderIcon draws them.
    private func miniCenter(at index: Int, mini: Double) -> CGPoint {
        let gap = HomeDesign.folderMini(iconSize: iconFrame.width).gap
        let columns = HomeFolderMetrics.columns
        let grid = Double(columns) * mini + Double(columns - 1) * gap
        let inset = (iconFrame.width - grid) / 2
        let column = Double(index % columns)
        let row = Double(index / columns)
        return CGPoint(
            x: iconFrame.minX + inset + mini / 2 + column * (mini + gap),
            y: iconFrame.minY + inset + mini / 2 + row * (mini + gap)
        )
    }

    private func app(for item: HomeItem) -> LCAppModel? {
        guard case .app(let key) = item else {
            return nil
        }
        return model.apps[key]
    }
}
