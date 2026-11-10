//
//  HomePadLayout.swift
//  LiveContainerSwiftUI
//

import CoreGraphics

/// Where iPadOS 26 puts the icons and the page dots on an iPad's Home Screen,
/// in points, for each screen size and orientation: measured from iPadOS
/// 26.5's own Home Screen in the Simulator. It's the page iPadOS shows where
/// there are no widgets, which zContainer's pages never have: 30 icons of 68
/// points, 5 by 6 in portrait and 6 by 5 in landscape, centered across the
/// screen. The dock is the same on every iPad. A screen not measured gets
/// the nearest one's layout, stretched to fit.
struct HomePadLayout: Equatable {
    /// How many columns and rows a page has.
    let columns: Int
    let rows: Int
    /// From one column's icons to the next's, and one row's to the next's.
    let columnPitch: Double
    let rowPitch: Double
    /// From the top of the screen to the first row's icons.
    let firstRowTop: Double
    /// From the dock's top up to the center of the page dots.
    let pageDotsAboveDock: Double

    /// An icon's width and height, on every iPad.
    static let iconSize = HomePadDock.referenceIconSize
    /// The dock's height at full size, and the distance HomePadDock keeps it
    /// from the bottom of the screen and from its sides.
    static let dockHeight = 107.0
    static let dockBottomInset = 8.0

    /// The layout for a window filling an iPad's screen of `size`, in either
    /// orientation, or nil for a smaller window, such as one in Split View,
    /// Slide Over or Stage Manager, which iPadOS has no Home Screen for.
    static func fullScreen(_ size: CGSize) -> HomePadLayout? {
        let width = Double(size.width)
        let height = Double(size.height)
        let isLandscape = width > height
        let candidates = measured.filter { ($0.width > $0.height) == isLandscape }
        if let exact = candidates.first(where: { abs($0.width - width) < 0.5 && abs($0.height - height) < 0.5 }) {
            return exact.layout
        }
        // An iPad not measured, whose screen is a little different from one
        // that was: that one's layout, stretched to it.
        guard let nearest = candidates.min(by: { abs($0.width - width) + abs($0.height - height) < abs($1.width - width) + abs($1.height - height) }),
              abs(nearest.width - width) / nearest.width < 0.06,
              abs(nearest.height - height) / nearest.height < 0.1 else {
            return nil
        }
        let across = width / nearest.width
        let down = height / nearest.height
        let layout = nearest.layout
        return HomePadLayout(
            columns: layout.columns,
            rows: layout.rows,
            columnPitch: layout.columnPitch * across,
            rowPitch: layout.rowPitch * down,
            firstRowTop: layout.firstRowTop * down,
            pageDotsAboveDock: layout.pageDotsAboveDock * down
        )
    }

    /// The screens measured, as wide and tall as the window filling them.
    private static let measured: [(width: Double, height: Double, layout: HomePadLayout)] = [
        // iPad mini (6th generation and A17 Pro).
        (744, 1133, HomePadLayout(columns: 5, rows: 6, columnPitch: 110, rowPitch: 139, firstRowTop: 122.5, pageDotsAboveDock: 52.75)),
        (1133, 744, HomePadLayout(columns: 6, rows: 5, columnPitch: 140, rowPitch: 104.5, firstRowTop: 68, pageDotsAboveDock: 25.75)),
        // iPad (10th generation and A16), iPad Air 11-inch.
        (820, 1180, HomePadLayout(columns: 5, rows: 6, columnPitch: 132.06, rowPitch: 162.5, firstRowTop: 92, pageDotsAboveDock: 29.75)),
        (1180, 820, HomePadLayout(columns: 6, rows: 5, columnPitch: 164.05, rowPitch: 121, firstRowTop: 76, pageDotsAboveDock: 20.75)),
        // iPad Pro 11-inch (M4 and M5).
        (834, 1210, HomePadLayout(columns: 5, rows: 6, columnPitch: 132, rowPitch: 162.5, firstRowTop: 107.5, pageDotsAboveDock: 36.75)),
        (1210, 834, HomePadLayout(columns: 6, rows: 5, columnPitch: 164, rowPitch: 121.5, firstRowTop: 83.5, pageDotsAboveDock: 24.75)),
        // iPad Air 13-inch, iPad Pro 12.9-inch.
        (1024, 1366, HomePadLayout(columns: 5, rows: 6, columnPitch: 162, rowPitch: 196, firstRowTop: 95, pageDotsAboveDock: 30.75)),
        // iPad Pro 13-inch (M4 and M5).
        (1032, 1376, HomePadLayout(columns: 5, rows: 6, columnPitch: 164, rowPitch: 196, firstRowTop: 100, pageDotsAboveDock: 33.75)),
        (1376, 1032, HomePadLayout(columns: 6, rows: 5, columnPitch: 197.6, rowPitch: 147.5, firstRowTop: 124, pageDotsAboveDock: 45.75)),
    ]
}
