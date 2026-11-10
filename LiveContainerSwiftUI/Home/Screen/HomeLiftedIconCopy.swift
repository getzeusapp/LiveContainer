//
//  HomeLiftedIconCopy.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A dragged icon as it follows the finger, laid out like the icon it
/// stands in for, with its name under it. It appears as exactly that icon,
/// so picking it up shows no seam, then rises and casts its shadow while its
/// name fades, as on iOS. Once dropped it shrinks back on the way to its
/// place, its name fading back in, and lands as the icon that takes over
/// there: without a name in the dock, and at the dock's size, which a narrow
/// iPad window makes smaller. Let go over another icon to go into, it shrinks
/// away into it instead.
///
/// In a stack of icons moved together, as iOS stacks them, each one under
/// the top tilts its own way, and all of them are a little see-through. One
/// that just joined flies in from where it was.
struct HomeLiftedIconCopy: View {
    /// The icon this copy is of.
    let item: HomeItem
    /// What's being dragged.
    let drag: HomeDrag
    /// The app behind the icon, or nil for Settings and folders.
    let app: LCAppModel?
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// Whether the app's icon shows in its dark version.
    let darkModeIcon: Bool
    /// How far down the stack it is: 0 for the top.
    var stackDepth = 0
    /// How far it is from where it was on screen when it joined, which it
    /// flies in from.
    var flightOffset = CGSize.zero

    @Environment(HomeScreenModel.self) private var model
    /// Whether the icon has risen under the finger since it was picked up.
    @State private var isRaised = false
    /// Whether an icon that joined has flown into the stack.
    @State private var hasArrived = false

    var body: some View {
        let isUp = isRaised && !model.isDropping
        // Before it rises the icon looks as it did where it was picked up;
        // once dropped, as it will where it lands.
        let slot = model.isDropping ? landingSlot : drag.origin
        let isStacked = drag.items.count > 1 && isUp

        VStack(spacing: HomeDesign.labelSpacing) {
            HomeIconContent(item: item, app: app, metrics: metrics, showsLabel: false, darkModeIcon: darkModeIcon)
            HomeIconLabel(title: model.title(of: item))
                .opacity(isUp || slot.isInDock || model.isDroppingIntoFolder ? 0 : 1)
        }
        .frame(width: metrics.cellWidth, height: metrics.cellHeight, alignment: .top)
        .scaleEffect(scale(isUp: isUp, slot: slot), anchor: iconCenter)
        .rotationEffect(.degrees(isStacked ? tilt : 0), anchor: iconCenter)
        // Into a folder, it shrinks away into the folder's icon; deep in a
        // stack, it hides under the ones above.
        .opacity(model.isDroppingIntoFolder ? 0 : isStacked ? (stackDepth < HomeDesign.stackTilts.count ? HomeDesign.stackOpacity : 0) : 1)
        .shadow(
            color: .black.opacity(isUp ? HomeDesign.liftedShadowOpacity : 0),
            radius: HomeDesign.liftedShadowRadius,
            y: HomeDesign.liftedShadowOffset
        )
        .offset(hasArrived ? .zero : flightOffset)
        .onAppear(perform: rise)
    }

    /// Where the icon lands once dropped: the first one where the drag goes,
    /// and each that joined it after it.
    private var landingSlot: HomeSlot {
        item == drag.item ? drag.target : drag.preview.slot(of: item) ?? drag.target
    }

    /// How the icon tilts in a stack, by how far down it is.
    private var tilt: Double {
        HomeDesign.stackTilts[min(stackDepth, HomeDesign.stackTilts.count - 1)]
    }

    /// The icon's center in this view, which it grows and shrinks around, so
    /// it stays under the finger.
    private var iconCenter: UnitPoint {
        UnitPoint(x: 0.5, y: metrics.iconSize / 2 / metrics.cellHeight)
    }

    /// How big the icon shows: risen under the finger, shrinking into a
    /// folder, or as big as the icons where it lands.
    private func scale(isUp: Bool, slot: HomeSlot) -> Double {
        if isUp {
            HomeDesign.liftedScale
        } else if model.isDroppingIntoFolder {
            HomeDesign.intoFolderScale
        } else {
            scale(in: slot)
        }
    }

    /// How big the icon is at a slot next to the pages' icons: the same, but in
    /// a dock whose icons have shrunk to fit.
    private func scale(in slot: HomeSlot) -> Double {
        guard slot.isInDock else {
            return 1
        }
        return metrics.dockIconSize(model.dockContents) / metrics.iconSize
    }

    private func rise() {
        withAnimation(HomeDesign.lift) {
            isRaised = true
        }
        withAnimation(HomeDesign.stackJoin) {
            hasArrived = true
        }
    }
}
