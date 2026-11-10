//
//  HomeIconMoveActions.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The actions VoiceOver, Switch Control and Voice Control offer on an icon
/// in edit mode, where moving it otherwise takes a drag: past the icon before
/// or after it, named so each one says where it goes, and into or out of the
/// dock.
struct HomeIconMoveActions: ViewModifier {
    /// The icon the actions move.
    let item: HomeItem
    /// Whether the icon can be moved: not one of the iPad dock's recent apps.
    var isEnabled = true

    @Environment(HomeScreenModel.self) private var model

    func body(content: Content) -> some View {
        // Only edit mode gates the actions here, so a drag's every step
        // doesn't redraw each icon. The model ignores them during a drag.
        content.accessibilityActions {
            if model.isEditing && isEnabled {
                if let before = model.accessibilityNeighbor(of: item, by: -1) {
                    Button("zc.home.moveBefore %@".localizeWithFormat(model.title(of: before)), action: moveBefore)
                }
                if let after = model.accessibilityNeighbor(of: item, by: 1) {
                    Button("zc.home.moveAfter %@".localizeWithFormat(model.title(of: after)), action: moveAfter)
                }
                if model.canMoveToDock(item) {
                    Button("zc.home.moveToDock".loc, action: moveToDock)
                }
                if model.canMoveOutOfDock(item) {
                    Button("zc.home.moveOutOfDock".loc, action: moveOutOfDock)
                }
            }
        }
    }

    private func moveBefore() {
        model.moveForAccessibility(item, by: -1)
    }

    private func moveAfter() {
        model.moveForAccessibility(item, by: 1)
    }

    private func moveToDock() {
        model.moveForAccessibility(item, toDock: true)
    }

    private func moveOutOfDock() {
        model.moveForAccessibility(item, toDock: false)
    }
}

extension View {
    /// Offers the actions that move an icon in edit mode without a drag.
    func homeIconMoveActions(for item: HomeItem, isEnabled: Bool = true) -> some View {
        modifier(HomeIconMoveActions(item: item, isEnabled: isEnabled))
    }
}
