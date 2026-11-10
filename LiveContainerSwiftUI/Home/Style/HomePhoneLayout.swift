//
//  HomePhoneLayout.swift
//  LiveContainerSwiftUI
//

import CoreGraphics

/// Where iOS 26 puts the icons, the dock and the search pill on an iPhone in
/// portrait, in points, for each screen size: measured from iOS 26.5's own
/// Home Screen in the Simulator. iPhones whose screens are the same size in
/// points share a layout. Sizes not in the table, such as a future iPhone's,
/// get the nearest one's, scaled to fit.
struct HomePhoneLayout: Equatable {
    /// An icon's width and height.
    let iconSize: Double
    /// From the sides of the screen to the first and last columns' icons. The
    /// columns between are evenly spaced, so the grid is centered.
    let sideInset: Double
    /// From the top of the screen to the first row's icons.
    let firstRowTop: Double
    /// From one row's icons to the next's.
    let rowPitch: Double
    /// The dock's distance from the screen's sides and from its bottom. 0 on
    /// iPhones with a Home button, whose dock runs the full width along the
    /// bottom edge.
    let dockInset: Double
    /// The dock's height. Its icons are centered in it.
    let dockHeight: Double
    /// From one dock icon's center to the next's, whatever their number.
    let dockPitch: Double
    /// From the dock's top up to the center of the search pill, or of the page
    /// dots on iPhones with a Home button.
    let pillAboveDock: Double
    /// What SpringBoard adds to the dock's corner radius on this screen, from
    /// _SBHDefaultDockCornerRadiusAdjustment: 2 points less on the 14 Pro's
    /// screen, and 6 less on the 16 Pro's, the Air's and the Pro Max's.
    let dockCornerAdjustment: Double
    /// The corner radius of the screen of the iPhone measured, for when iOS
    /// doesn't give this iPhone's.
    let displayCornerRadius: Double

    /// The distance between neighboring columns.
    func columnPitch(screenWidth: Double) -> Double {
        (screenWidth - sideInset * 2 - iconSize) / 3
    }

    /// The dock's corner radius on a screen with corners of
    /// `displayCornerRadius` and `scale` pixels to a point, as SpringBoard's
    /// _SBHDefaultDockMetrics works it out: concentric with the dock's icons,
    /// whose corner radius is 0.26 of their size, at the distance between
    /// the dock's edge and the columns' icons, or with the screen's corners,
    /// whichever is rounder, plus `dockCornerAdjustment`, rounded to the
    /// screen's pixels. 31.33 points on the iPhone 11 Pro and 39 on the 17
    /// Pro. 0 for a dock along the bottom edge of the screen.
    func dockCornerRadius(displayCornerRadius: Double, scale: Double) -> Double {
        guard dockInset > 0 else {
            return 0
        }
        let aroundIcons = iconSize * 0.26 + sideInset - dockInset
        let aroundScreen = displayCornerRadius - dockInset
        let radius = max(aroundIcons, aroundScreen) + dockCornerAdjustment
        return scale > 0 ? (radius * scale).rounded() / scale : radius
    }

    /// The layout of an iPhone screen of `size` in portrait.
    static func portrait(_ size: CGSize) -> HomePhoneLayout {
        let width = Double(min(size.width, size.height))
        let height = Double(max(size.width, size.height))
        if let measured = measured.first(where: { abs($0.width - width) < 0.5 && abs($0.height - height) < 0.5 }) {
            return measured.layout
        }
        // The screen nearest in width, its sizes scaled to this one.
        let nearest = measured.min { abs($0.width - width) < abs($1.width - width) }!
        let across = width / nearest.width
        let down = height / nearest.height
        let layout = nearest.layout
        return HomePhoneLayout(
            iconSize: layout.iconSize * min(across, down),
            sideInset: layout.sideInset * across,
            firstRowTop: layout.firstRowTop * down,
            rowPitch: layout.rowPitch * down,
            dockInset: layout.dockInset * across,
            dockHeight: layout.dockHeight * min(across, down),
            dockPitch: layout.dockPitch * across,
            pillAboveDock: layout.pillAboveDock * down,
            dockCornerAdjustment: layout.dockCornerAdjustment,
            displayCornerRadius: layout.displayCornerRadius
        )
    }

    /// The screens measured, in portrait.
    private static let measured: [(width: Double, height: Double, layout: HomePhoneLayout)] = [
        // iPhone SE (2nd and 3rd generation), with a Home button.
        (375, 667, HomePhoneLayout(iconSize: 60, sideInset: 28, firstRowTop: 30, rowPitch: 86,
                                   dockInset: 0, dockHeight: 92, dockPitch: 86, pillAboveDock: 14,
                                   dockCornerAdjustment: 0, displayCornerRadius: 0)),
        // iPhone 11 Pro, 12 mini and 13 mini.
        (375, 812, HomePhoneLayout(iconSize: 64, sideInset: 24.67, firstRowTop: 67, rowPitch: 95,
                                   dockInset: 10, dockHeight: 93.33, dockPitch: 87, pillAboveDock: 27.5,
                                   dockCornerAdjustment: 0, displayCornerRadius: 39)),
        // iPhone 12, 13, 14, 16e and 17e, and the 12 and 13 Pro.
        (390, 844, HomePhoneLayout(iconSize: 64, sideInset: 28, firstRowTop: 67, rowPitch: 98,
                                   dockInset: 12, dockHeight: 96, dockPitch: 90, pillAboveDock: 32.83,
                                   dockCornerAdjustment: 0, displayCornerRadius: 47.33)),
        // iPhone 14 Pro, 15, 15 Pro and 16.
        (393, 852, HomePhoneLayout(iconSize: 64, sideInset: 28.17, firstRowTop: 80, rowPitch: 98.67,
                                   dockInset: 12, dockHeight: 109.33, dockPitch: 86.33, pillAboveDock: 33,
                                   dockCornerAdjustment: -2, displayCornerRadius: 55)),
        // iPhone 16 Pro, 17 and 17 Pro.
        (402, 874, HomePhoneLayout(iconSize: 64, sideInset: 30.17, firstRowTop: 90, rowPitch: 100.33,
                                   dockInset: 17, dockHeight: 103.33, dockPitch: 88, pillAboveDock: 35,
                                   dockCornerAdjustment: -6, displayCornerRadius: 62)),
        // iPhone 11 and 11 Pro Max.
        (414, 896, HomePhoneLayout(iconSize: 64, sideInset: 33, firstRowTop: 70, rowPitch: 102.5,
                                   dockInset: 12, dockHeight: 106, dockPitch: 94.5, pillAboveDock: 33.75,
                                   dockCornerAdjustment: 0, displayCornerRadius: 41.5)),
        // iPhone Air.
        (420, 912, HomePhoneLayout(iconSize: 68, sideInset: 30.67, firstRowTop: 96, rowPitch: 104.67,
                                   dockInset: 17, dockHeight: 108.67, dockPitch: 92.33, pillAboveDock: 35,
                                   dockCornerAdjustment: -6, displayCornerRadius: 62)),
        // iPhone 12 Pro Max, 13 Pro Max and 14 Plus.
        (428, 926, HomePhoneLayout(iconSize: 68, sideInset: 32.17, firstRowTop: 72, rowPitch: 106.33,
                                   dockInset: 14, dockHeight: 104.67, dockPitch: 98.33, pillAboveDock: 40.17,
                                   dockCornerAdjustment: 0, displayCornerRadius: 53.33)),
        // iPhone 14 Pro Max, 15 Plus, 15 Pro Max and 16 Plus.
        (430, 932, HomePhoneLayout(iconSize: 68, sideInset: 33, firstRowTop: 84, rowPitch: 106.67,
                                   dockInset: 14, dockHeight: 106, dockPitch: 98.67, pillAboveDock: 40.17,
                                   dockCornerAdjustment: 0, displayCornerRadius: 55)),
        // iPhone 16 Pro Max and 17 Pro Max.
        (440, 956, HomePhoneLayout(iconSize: 68, sideInset: 35, firstRowTop: 94, rowPitch: 108.67,
                                   dockInset: 17, dockHeight: 117.33, dockPitch: 96, pillAboveDock: 43,
                                   dockCornerAdjustment: -6, displayCornerRadius: 62)),
    ]
}
