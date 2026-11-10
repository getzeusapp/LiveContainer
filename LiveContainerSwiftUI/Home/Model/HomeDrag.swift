//
//  HomeDrag.swift
//  LiveContainerSwiftUI
//

import Foundation

/// An icon being moved in edit mode: where it came from, where it would land
/// if dropped now, the layout the other icons show to make room for it, and
/// the icon it would make a folder with or go into instead.
struct HomeDrag: Equatable {
    /// The icon being moved.
    let item: HomeItem
    /// Where the icon was when it was picked up.
    let origin: HomeSlot
    /// The distance from the finger to the icon's center, so the icon doesn't
    /// jump under the finger when it is picked up.
    let grabOffset: CGSize
    /// Where the icon goes if it is dropped now.
    var target: HomeSlot
    /// The layout with the icon at `target`.
    var preview: HomeLayout
    /// The icon the dragged one has hovered over long enough to go into if
    /// dropped now: a folder, or an app or Settings that a new folder would
    /// hold along with it.
    var mergeTarget: HomeItem?
    /// Whether the finger has moved further than a tap would since it picked
    /// the icon up. A folder held and let go without moving opens instead.
    var hasMoved = false
    /// The icons tapped while the icon was held, which joined it, as on iOS:
    /// in the order they joined, the newest on top of the stack under the
    /// finger. They go down together after `item`, in that order.
    var extras: [HomeItem] = []
    /// Where each icon that joined was on screen, which it flew in from.
    var joinedFrom: [HomeItem: CGPoint] = [:]
    /// Where each icon that joined lands, once the stack is let go.
    var landing: [HomeItem: CGPoint] = [:]
    /// Whether the iPad's dock has bounced for being full while the icon was
    /// held over it, which it does once a drag, as on iPadOS.
    var hasBouncedDock = false

    /// Every icon being moved, from the first picked up to the last to join.
    var items: [HomeItem] {
        [item] + extras
    }

    /// Whether any icon being moved is a folder, which can't go into one.
    var holdsFolder: Bool {
        items.contains(where: \.isFolder)
    }
}
