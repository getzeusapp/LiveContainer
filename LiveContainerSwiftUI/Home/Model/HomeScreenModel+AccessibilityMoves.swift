//
//  HomeScreenModel+AccessibilityMoves.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Moving icons in edit mode without dragging them, for VoiceOver, Switch
/// Control and Voice Control: one place earlier or later in reading order,
/// across the pages, within the dock or within a folder, and into or out of
/// the dock.
extension HomeScreenModel {
    /// Whether icons can be moved by these actions now: in edit mode, while
    /// no icon is being dragged.
    var canMoveForAccessibility: Bool {
        isEditing && drag == nil
    }

    /// The icon an icon trades places with when it moves one place earlier
    /// (`offset` -1) or later (1): its neighbor in the dock, in its folder, or
    /// on the pages read one after another. Nil when there is none that way.
    func accessibilityNeighbor(of item: HomeItem, by offset: Int) -> HomeItem? {
        guard let slot = layout.slot(of: item) else {
            return nil
        }
        let order = switch slot {
        case .dock:
            layout.dock
        case .page:
            layout.pages.flatMap { $0 }
        case .folder(let id, _):
            layout.folders[id]?.items ?? []
        }
        guard let position = order.firstIndex(of: item) else {
            return nil
        }
        let neighbor = position + offset
        return order.indices.contains(neighbor) ? order[neighbor] : nil
    }

    /// Whether an icon on a page can move into the dock, which has room.
    func canMoveToDock(_ item: HomeItem) -> Bool {
        guard let slot = layout.slot(of: item) else {
            return false
        }
        return slot.page != nil && layout.dock.count < HomeLayout.dockCapacity
    }

    /// Whether an icon is in the dock, so it can move out onto a page.
    func canMoveOutOfDock(_ item: HomeItem) -> Bool {
        layout.slot(of: item)?.isInDock ?? false
    }

    /// The name of an icon, as it shows under it and as VoiceOver reads it,
    /// even in the dock, where it doesn't show.
    func title(of item: HomeItem) -> String {
        switch item {
        case .settings:
            "lc.tabView.settings".loc
        case .app(let key):
            apps[key]?.displayName ?? ""
        case .folder(let id):
            displayedLayout.folders[id]?.name ?? ""
        case .widget(let id):
            displayedLayout.widgets[id].map { widget in
                widget.isStack ? "zc.widget.stack".loc : widget.kinds.first?.title ?? ""
            } ?? ""
        }
    }

    /// Moves an icon one place earlier (`offset` -1) or later (1), past its
    /// neighbor, onto the next or previous page when it is at the end of one.
    func moveForAccessibility(_ item: HomeItem, by offset: Int) {
        guard canMoveForAccessibility, let neighbor = accessibilityNeighbor(of: item, by: offset) else {
            return
        }
        var others = layout
        others.remove(item)
        guard let neighborSlot = others.slot(of: neighbor) else {
            return
        }
        // Before the neighbor, or after it, in the layout without the icon.
        let step = offset > 0 ? 1 : 0
        let target: HomeSlot = switch neighborSlot {
        case .page(let page, let index):
            .page(page, index: index + step)
        case .dock(let index):
            .dock(index + step)
        case .folder(let id, let index):
            .folder(id, index: index + step)
        }
        commitAccessibilityMove(of: item, to: target)
    }

    /// Moves an icon into the dock, at its end, or out of it, to the end of
    /// the page showing.
    func moveForAccessibility(_ item: HomeItem, toDock: Bool) {
        guard canMoveForAccessibility else {
            return
        }
        if toDock {
            guard canMoveToDock(item) else {
                return
            }
            commitAccessibilityMove(of: item, to: .dock(layout.dock.count))
        } else {
            guard canMoveOutOfDock(item) else {
                return
            }
            let current = min(page ?? 0, layout.pages.count - 1)
            commitAccessibilityMove(of: item, to: .page(current, index: layout.pages[current].count))
        }
    }

    /// Saves an icon's new place without the pages left empty, and turns to
    /// the page it moved to, so VoiceOver can find it there.
    private func commitAccessibilityMove(of item: HomeItem, to target: HomeSlot) {
        var moved = layout.moving(item, to: target)
        moved.removeEmptyPages()
        guard moved != layout else {
            return
        }
        withAnimation(HomeDesign.reflow) {
            layout = moved
        }
        HomeLayoutStorage.save(moved)
        if let newPage = moved.slot(of: item)?.page, newPage != (page ?? 0) {
            showPage(newPage)
        } else {
            clampPage()
        }
    }
}
