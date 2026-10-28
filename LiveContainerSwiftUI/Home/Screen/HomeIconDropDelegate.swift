//
//  HomeIconDropDelegate.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UniformTypeIdentifiers

/// Moves an icon dragged out of its menu across the Home Screen. Once a menu
/// is open it has the touch, and only UIKit's drag session can carry the
/// finger on from there, so the Home Screen takes that drag as a drop target
/// and feeds the finger to edit mode's drag.
struct HomeIconDropDelegate: DropDelegate {
    /// The type of the data an icon drag carries. It never leaves zContainer.
    static let iconType = UTType(exportedAs: "app.zcontainer.home-icon")

    let model: HomeScreenModel

    func validateDrop(info: DropInfo) -> Bool {
        model.menuDragItem != nil
    }

    func dropEntered(info: DropInfo) {
        model.menuDragMoved(to: info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        model.menuDragMoved(to: info.location)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        model.menuDragEnded()
    }

    func performDrop(info: DropInfo) -> Bool {
        model.menuDragEnded()
        return true
    }
}
