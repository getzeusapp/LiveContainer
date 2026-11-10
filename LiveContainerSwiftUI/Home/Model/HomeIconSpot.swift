//
//  HomeIconSpot.swift
//  LiveContainerSwiftUI
//

import Foundation

/// The icon a dragged one is held nearest to, as the icons show while it
/// moves: the icon, its place on the page showing or in the dock, and its
/// center on screen.
struct HomeIconSpot {
    let item: HomeItem
    let index: Int
    let center: CGPoint
    /// The icon's size there, when it isn't the pages' icon size, as in an
    /// iPad dock whose icons have shrunk to fit.
    var size: Double? = nil
}
