//
//  HomePadDock.swift
//  LiveContainerSwiftUI
//

import CoreGraphics
import Foundation
import UIKit

/// The iPad's floating dock, laid out as iPadOS 26.5's SpringBoard lays it
/// out (+[SBFloatingDockView getMetrics:forBounds:…] in SpringBoardHome): the
/// person's icons, then a divider and the apps opened most recently, on glass
/// as wide as they need, but never narrower than four icons, even when the
/// dock is empty. Its bottom edge is 8 points above the screen's. When they
/// don't all fit across the room the dock has, the icons and the space
/// around them shrink together, so the dock never wraps. zContainer has no
/// App Library, so its dock has no App Library icon after the recent apps.
struct HomePadDock: Equatable {
    /// The glass, on screen.
    let platter: CGRect
    /// The icons' width and height.
    let iconSize: Double
    /// The space between neighboring icons, and between the icons and the
    /// glass's edges.
    let spacing: Double
    /// The glass's corner radius, which stays concentric with its icons'.
    let cornerRadius: Double
    /// The top left corner of the place the person's first icon goes, on screen.
    let iconsOrigin: CGPoint
    /// The top left corner of the place the first recent app goes, on screen.
    let recentsOrigin: CGPoint
    /// The line between the person's icons and the recent apps, on screen.
    let divider: CGRect
    /// Whether the divider shows: only with icons on both sides of it.
    let showsDivider: Bool

    /// Lays out a dock holding `icons` of the person's icons and `recents`
    /// recent apps after them, whose glass's bottom edge is `room.maxY` and
    /// which can spread across `room`. Its icons are at most `largestIcon`
    /// points, which a window smaller than the screen makes less than the
    /// 68 they are on every iPad.
    init(room: CGRect, icons: Int, recents: Int, largestIcon: Double = Self.referenceIconSize) {
        let reference = Self.referenceIconSize
        let largest = Self.floorToPixel(min(largestIcon, reference))
        // 48/167ths of an icon between icons, as iPadOS spaces them: 19.5
        // points around 68 point icons.
        let referenceSpacing = Self.floorToPixel(reference * 48 / 167)
        let width = room.width

        // One divider, with the spacing on each side of it, between the
        // person's icons and the recent apps, and the spacing at each end.
        let dividers = icons > 0 && recents > 0 ? 1 : 0
        let count = icons + recents
        let spacings = max(icons - 1, 0) + max(recents - 1, 0) + dividers * 2 + 2

        var icon = largest
        var gap = referenceSpacing
        if Double(count) * largest + Double(spacings) * referenceSpacing + Double(dividers) > width + Self.tolerance {
            // Too wide for the room: the icons and the spacing shrink
            // together until it all fits.
            icon = Self.floorToPixel((width - Double(dividers)) / (Double(spacings) * referenceSpacing / largest + Double(count)))
            if icon != reference {
                gap = Self.floorToPixel(referenceSpacing * icon / reference)
            }
        } else if reference > largest {
            gap = Self.floorToPixel(referenceSpacing * largest / reference)
        }

        let recentsWidth = Self.rowWidth(recents, icon: icon, gap: gap)
        let contentWidth = Double(count) * icon + Double(spacings - 2) * gap + Double(dividers)
        let height = icon + gap * 2
        var platter = CGRect(
            x: Self.roundToPixel(room.midX - contentWidth / 2) - gap,
            y: room.maxY - height,
            width: contentWidth + gap * 2,
            height: height
        )
        // Never narrower than four icons and the spacing around them, with
        // what it holds in the middle.
        let narrowest = icon * 4 + gap * 6 + 1
        var inset = 0.0
        if platter.width < narrowest - Self.tolerance {
            inset = (narrowest - platter.width) / 2
            platter = CGRect(
                x: Self.roundToPixel(platter.midX - narrowest / 2),
                y: Self.roundToPixel(platter.midY - height / 2),
                width: narrowest,
                height: height
            )
        }

        // The recent apps end where the content does, and the divider sits
        // the spacing before them. iPadOS centers the person's icons in
        // their part of the dock, the spacing wider on each side, and rounds
        // the space before them to whole points, so at full size they start
        // 20 points in rather than 19.5.
        let contentEnd = inset + gap + contentWidth
        let recentsStart = contentEnd - recentsWidth
        self.platter = platter
        iconSize = icon
        spacing = gap
        cornerRadius = Self.cornerRadius(platterHeight: height, reference: reference, referenceSpacing: referenceSpacing)
        iconsOrigin = CGPoint(x: platter.minX + inset + gap.rounded(), y: platter.minY + gap)
        recentsOrigin = CGPoint(x: platter.minX + recentsStart, y: platter.minY + gap)
        divider = CGRect(
            x: platter.minX + (recents > 0 ? recentsStart : contentEnd) - gap - 1,
            y: platter.minY + gap - 1,
            width: 1,
            height: icon + 2
        )
        showsDivider = dividers > 0
    }

    /// The center of the person's icon at `index`.
    func iconCenter(at index: Int) -> CGPoint {
        CGPoint(x: iconsOrigin.x + Double(index) * (iconSize + spacing) + iconSize / 2, y: iconsOrigin.y + iconSize / 2)
    }

    /// The center of the recent app at `index`.
    func recentCenter(at index: Int) -> CGPoint {
        CGPoint(x: recentsOrigin.x + Double(index) * (iconSize + spacing) + iconSize / 2, y: recentsOrigin.y + iconSize / 2)
    }

    /// An icon's width and height on every iPad's Home Screen and dock.
    static let referenceIconSize = 68.0
    /// The scale of every iPad's screen, whose pixels iPadOS rounds the
    /// dock's sizes to.
    static let displayScale = 2.0
    /// How much two lengths can differ and still count as the same, as
    /// SpringBoard compares them.
    private static let tolerance = 1e-7

    /// The width of a row of `count` icons with `gap` between them.
    private static func rowWidth(_ count: Int, icon: Double, gap: Double) -> Double {
        count > 0 ? Double(count) * icon + Double(count - 1) * gap : 0
    }

    /// The glass's corner radius: the icons' own corner radius, which iPadOS
    /// makes 0.26 of their size, plus the spacing around them, which keeps
    /// the corners concentric, scaled down with the glass when its icons
    /// shrink. It's 37 points at full size.
    private static func cornerRadius(platterHeight: Double, reference: Double, referenceSpacing: Double) -> Double {
        let fullHeight = referenceSpacing * 2 + floorToPixel(reference)
        let largest = referenceSpacing + reference * iconCornerFraction
        let shrink = fullHeight > 0 ? min(platterHeight / fullHeight, 1) : 1
        return floorToPixel(largest * shrink)
    }

    /// An iPad icon's corner radius over its size, as SpringBoard's
    /// SBHIconImageInfo gives it.
    private static let iconCornerFraction = 0.26

    private static func floorToPixel(_ value: Double) -> Double {
        (value * displayScale).rounded(.down) / displayScale
    }

    private static func roundToPixel(_ value: Double) -> Double {
        (value * displayScale).rounded() / displayScale
    }
}

extension HomePadDock {
    /// How many of the person's icons an iPad's dock holds at most, as
    /// iPadOS 26.5 allows on its screen: 20, 16 on an iPad mini and 26 on a
    /// 12.9- or 13-inch iPad not zoomed, and 3 more with recent apps turned
    /// off, whose places they take. It's the device's, not the window's, so
    /// resizing a window never pushes an icon out of the dock.
    static func capacity(showsRecents: Bool) -> Int {
        deviceCapacity + (showsRecents ? 0 : HomeDockRecents.capacity)
    }

    /// The capacity with recent apps on, from the screen: an iPad mini's is
    /// under 1,600 pixels across, and a 12.9- or 13-inch iPad's 2,048 or
    /// more, and more than 800 points unless Display Zoom is on.
    private static let deviceCapacity: Int = {
        let screen = UIScreen.main
        let pixels = min(screen.nativeBounds.width, screen.nativeBounds.height)
        let points = min(screen.bounds.width, screen.bounds.height)
        if pixels < 1600 {
            return 16
        }
        if pixels >= 2048 && points > 800 {
            return 26
        }
        return 20
    }()
}
