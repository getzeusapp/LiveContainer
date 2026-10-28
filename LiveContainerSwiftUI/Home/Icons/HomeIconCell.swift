//
//  HomeIconCell.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One icon on the pages or in the dock, and everything it does: a tap opens
/// it, a long press lifts it with its menu, and dragging it from there starts
/// edit mode with it in hand. In edit mode it jiggles while on screen, shows
/// its minus badge and can be held and dragged to a new place, or moved with
/// VoiceOver's actions.
struct HomeIconCell: View {
    /// The icon.
    let item: HomeItem
    /// The app behind the icon, or nil for Settings.
    let app: LCAppModel?
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// Whether the name shows under the icon. Icons in the dock have none.
    let showsLabel: Bool
    /// Whether this icon is being dragged. Its view stays put and hidden while
    /// a copy follows the finger, so the drag gesture on it keeps going.
    let isLifted: Bool
    /// Whether the icon is on the page showing or in the dock. Only those
    /// jiggle in edit mode, so the pages off screen cost nothing each frame.
    let isOnScreen: Bool
    /// Whether the app's icon shows in its dark version, as the dark icons
    /// setting asks.
    let darkModeIcon: Bool
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isHeld = false

    var body: some View {
        let isMergeTarget = model.drag?.mergeTarget == item

        Button(action: open) {
            HomeIconContent(
                item: item,
                app: app,
                metrics: metrics,
                showsLabel: showsLabel,
                darkModeIcon: darkModeIcon,
                zoomNamespace: zoomNamespace
            )
            .scaleEffect(mergeScale(isMergeTarget), anchor: iconAnchor)
            .background(alignment: .top) {
                if isMergeTarget && !item.isFolder {
                    newFolderGlass
                }
            }
            .animation(HomeDesign.mergeHighlight, value: isMergeTarget)
            // The icon's whole place takes touches, its name too, as on iOS,
            // not only what's drawn there: a folder's glass between its small
            // icons, or an app icon's clear corners.
            .contentShape(.rect)
        }
        .buttonStyle(HomeIconButtonStyle())
        .accessibilityLabel(title)
        .homeIconMoveActions(for: item)
        .contentShape(.contextMenuPreview, HomeIconPreviewShape(iconSize: metrics.iconSize, cornerRadius: metrics.iconCornerRadius))
        .contextMenu {
            HomeIconMenu(item: item, app: app)
        }
        // Lets the icon be dragged out of its menu, which starts edit mode.
        // UIKit draws nothing under the finger: the Home Screen's own lifted
        // icon follows it, through HomeIconDropDelegate.
        .onDrag(menuDragItem) {
            Color.clear.frame(width: 1, height: 1)
        }
        .highPriorityGesture(editDrag, including: model.isEditing ? .all : .subviews)
        .onChange(of: isHeld) { wasHeld, isHeld in
            if wasHeld && !isHeld {
                model.iconReleased(item)
            }
        }
        // The badge sits over the icon, outside the drag gesture, so a tap on
        // it isn't taken for the start of a drag.
        .overlay(alignment: .topLeading) {
            if model.isEditing && model.isRemovable(item) && !isLifted {
                HomeMinusBadge(title: title, action: requestRemoval)
                    .position(x: iconLeft + HomeDesign.minusBadgeInset, y: HomeDesign.minusBadgeInset)
            }
        }
        .homeJiggle(isActive: model.isEditing && isOnScreen && !reduceMotion && !isLifted, seed: jiggleSeed)
        .opacity(isLifted || isOpenFolder ? 0 : 1)
        // HomeLiftedIcon's copy takes the icon's place in the same spot and
        // look, and an open folder's view zooms out of its icon and back into
        // it, so the icon hides and comes back at once, with no fade.
        .animation(nil, value: isLifted)
        .animation(nil, value: isOpenFolder)
        .accessibilityHidden(isLifted)
    }

    /// The icon's name, which VoiceOver reads even in the dock, where it
    /// doesn't show.
    private var title: String {
        model.title(of: item)
    }

    /// Whether this is a folder's icon while the folder is open over the Home
    /// Screen, or zooming back into it. A folder an icon is being dragged out
    /// of has gone back into its icon, which shows again.
    private var isOpenFolder: Bool {
        guard case .folder(let id) = item, id == model.openFolderID else {
            return false
        }
        return model.isFolderShown || model.drag == nil
    }

    /// The icon's center in this view, which it grows and shrinks around.
    private var iconAnchor: UnitPoint {
        showsLabel ? UnitPoint(x: 0.5, y: metrics.iconSize / 2 / metrics.cellHeight) : .center
    }

    /// How big the icon shows while a dragged icon hovers over it to go in: a
    /// folder grows to take it, and an app or Settings shrinks into the glass
    /// of the folder the two would make.
    private func mergeScale(_ isMergeTarget: Bool) -> Double {
        guard isMergeTarget else {
            return 1
        }
        return item.isFolder ? HomeDesign.mergeFolderScale : HomeDesign.mergeIconScale
    }

    /// The glass of the folder an app or Settings would make with the icon
    /// hovering over it, grown out behind the icon.
    private var newFolderGlass: some View {
        let size = metrics.iconSize * HomeDesign.mergeTileScale
        return Color.clear
            .frame(width: size, height: size)
            .homeFolderGlass(cornerRadius: metrics.iconCornerRadius * HomeDesign.mergeTileScale)
            // Centered on the icon, which sits at the top of this view.
            .offset(y: (metrics.iconSize - size) / 2)
            .transition(.scale(scale: 1 / HomeDesign.mergeTileScale).combined(with: .opacity))
    }

    /// Where the icon's left edge is in this view.
    private var iconLeft: Double {
        showsLabel ? (metrics.cellWidth - metrics.iconSize) / 2 : 0
    }

    /// A number that stays the same for this icon, so it always jiggles its own way.
    private var jiggleSeed: Int {
        item.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }

    /// Holding an icon in edit mode for a moment picks it up; moving the finger
    /// then drags it. A quick swipe fails the hold, so it turns the page instead.
    private var editDrag: some Gesture {
        LongPressGesture(minimumDuration: HomeDesign.pickUpDelay, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(HomeDesign.coordinateSpace)))
            .updating($isHeld) { value, isHeld, _ in
                if case .second(true, _) = value {
                    isHeld = true
                }
            }
            .onChanged(dragChanged)
    }

    private func dragChanged(_ value: SequenceGesture<LongPressGesture, DragGesture>.Value) {
        guard case .second(true, let drag?) = value else {
            return
        }
        model.dragChanged(item, finger: drag.location, start: drag.startLocation)
    }

    private func menuDragItem() -> NSItemProvider {
        model.offerMenuDrag(of: item)
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: HomeIconDropDelegate.iconType.identifier, visibility: .ownProcess) { completion in
            completion(Data(), nil)
            return nil
        }
        return provider
    }

    private func open() {
        model.open(item)
    }

    private func requestRemoval() {
        model.requestRemoval(of: item)
    }
}
