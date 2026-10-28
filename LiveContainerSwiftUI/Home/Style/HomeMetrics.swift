//
//  HomeMetrics.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Where everything on the Home Screen goes on the current screen, in points
/// from the screen's top left corner. HomeDesign's measurements are scaled
/// from the screen's width, and the rows share the height between the status
/// bar and the search pill, so the layout matches a real Home Screen on an
/// iPhone 13 Pro Max and keeps its proportions elsewhere. iPhones with a Home
/// button get the fixed sizes iOS gives them instead, with a full-width dock
/// along the bottom. In landscape the grid turns to 6 columns by 4 rows and
/// the dock stands on the trailing side, as on iPhones whose Home Screen rotates.
/// iPads, and their Split View, Slide Over and Stage Manager windows, get the
/// layout iPadOS uses instead: the grid spread over the whole window, 6 by 4
/// or 4 by 6, whichever fits bigger icons, and the dock floating at the
/// bottom in both orientations, its glass as wide as its icons need.
struct HomeMetrics: Equatable {
    /// The size of the whole screen.
    let size: CGSize
    /// The factor HomeDesign's sizes are multiplied by.
    let scale: Double
    /// How many columns a page has.
    let columns: Int
    /// How many rows a page has.
    let rows: Int
    /// An icon's width and height.
    private(set) var iconSize: Double
    /// An icon's corner radius.
    private(set) var iconCornerRadius: Double
    /// The width an icon's name can use.
    let cellWidth: Double
    /// The height of an icon with its name under it.
    private(set) var cellHeight: Double
    /// The dock's frame. On an iPad it is the most room the dock has, across
    /// the window, and the glass is only as wide as its icons need, centered
    /// in it: `dockFrame(holding:)` gives the glass.
    let dockFrame: CGRect
    /// Whether the dock stands on the trailing side, on an iPhone in landscape.
    let isDockVertical: Bool
    /// Whether the dock runs the full width of the screen, flush with its
    /// bottom edge, as on iPhones with a Home button.
    let isDockFlush: Bool
    /// The dock's corner radius where corners can't follow the screen's.
    let dockCornerRadius: Double
    /// The center of the search pill and the page dots.
    let pillCenter: CGPoint
    /// How much the Home button shrinks where it takes the search pill's
    /// place, so it fits between the last row's names and the dock. It is 1
    /// wherever there is room.
    let pillButtonScale: Double
    /// The vertical center of the buttons edit mode shows in place of the
    /// status bar.
    let editControlsCenterY: Double
    /// The space between the edit mode buttons and the sides of the screen.
    let editControlsInset: Double
    /// The size of edit mode's round add button, and the height of Done.
    let editButtonSize: Double

    /// The center of the first icon on a page.
    private let firstIconCenter: CGPoint
    /// The distance between neighboring columns and rows, which an open
    /// folder's icons keep too.
    let pitch: CGSize
    /// The distance between neighboring icons in the dock. On an iPad it is
    /// the most they can be apart; a narrow window brings them closer.
    private let dockPitch: Double
    /// On an iPad, the width the dock's icons can spread over, from the first
    /// one's leading edge to the last one's trailing edge. Nil on an iPhone,
    /// whose dock has a fixed size and spaces its icons the same whatever
    /// their number.
    private let dockRoom: Double?

    /// Lays the Home Screen out for a screen of `size`, whose system bars
    /// cover `safeArea`. `isPhone` tells an iPhone from an iPad, since iPads
    /// and iPhones with a Home button each get their own layout.
    init(size: CGSize, safeArea: EdgeInsets, isPhone: Bool = true) {
        self.size = size
        let labelBlock = HomeDesign.labelSpacing + HomeDesign.labelLineHeight
        // Only iPhones stand the dock on the side; iPadOS keeps it at the bottom.
        isDockVertical = isPhone && size.width > size.height
        isDockFlush = isPhone && !isDockVertical && safeArea.bottom == 0

        if !isPhone {
            // An iPad, or a window on one: the dock floats at the bottom in
            // both orientations, and the grid spreads over the whole width.
            let scale = min(
                size.width / HomeDesign.referenceWidth,
                size.height / HomeDesign.padReferenceHeight,
                HomeDesign.maximumScale
            )
            self.scale = scale
            let thickness = HomeDesign.dockThickness * scale
            let dockInset = HomeDesign.dockSideInset * scale
            let dockLeft = max(safeArea.leading, dockInset)
            let dockRight = size.width - max(safeArea.trailing, dockInset)
            dockFrame = CGRect(
                x: dockLeft,
                y: size.height - HomeDesign.dockBottomInset * scale - thickness,
                width: dockRight - dockLeft,
                height: thickness
            )
            pillCenter = CGPoint(x: size.width / 2, y: dockFrame.minY - HomeDesign.pillAboveDock * scale)
            editControlsCenterY = max(safeArea.top * 0.54, 24)
            editControlsInset = max(safeArea.leading, safeArea.trailing) + 16
            editButtonSize = HomeDesign.editButtonSize
            // Below the status bar, and below edit mode's buttons with room
            // for the first row's minus badges. The buttons don't move when
            // edit mode hides the status bar, so neither do the icons.
            let badgeReach = HomeDesign.minusBadgeSize / 2 - HomeDesign.minusBadgeInset
            let top = max(
                max(safeArea.top, 20) + HomeDesign.firstRowBelowStatusBar * scale,
                editControlsCenterY + editButtonSize / 2 + badgeReach + 4
            )
            let bottom = pillCenter.y - HomeDesign.pillHeight / 2 - 4 * scale
            let side = HomeDesign.padGridSideInset * scale
            let left = max(safeArea.leading, side)
            let right = size.width - max(safeArea.trailing, side)
            // Icons are as big as they can be while keeping the least gaps
            // beside them and under the names above, and no bigger than the
            // iPhone's, scaled. Both pitches count, so a short window gets
            // smaller icons instead of crushed rows.
            func fit(columns: Int, rows: Int) -> (pitch: CGSize, icon: Double) {
                let pitchWidth = (right - left) / Double(columns)
                let pitchHeight = min((bottom - top) / Double(rows), pitchWidth * HomeDesign.padMaximumRowToColumnPitch)
                let icon = min(
                    HomeDesign.iconSize * scale,
                    pitchHeight - labelBlock - HomeDesign.padMinimumRowGap * scale,
                    pitchWidth - HomeDesign.padMinimumColumnGap * scale
                )
                return (CGSize(width: pitchWidth, height: pitchHeight), max(icon, 20))
            }
            // 6 by 4 or 4 by 6, whichever gives bigger icons, so a window
            // near square keeps full size icons and the switch doesn't jump.
            // Both hold the 24 icons of a page, so turning the iPad keeps
            // every icon on its page.
            let wide = fit(columns: 6, rows: 4)
            let tall = fit(columns: 4, rows: 6)
            let isWide = abs(wide.icon - tall.icon) < 1 ? size.width > size.height : wide.icon > tall.icon
            columns = isWide ? 6 : 4
            rows = isWide ? 4 : 6
            let chosen = isWide ? wide : tall
            pitch = chosen.pitch
            iconSize = chosen.icon
            firstIconCenter = CGPoint(
                x: left + pitch.width / 2,
                y: top + (pitch.height - iconSize - labelBlock) / 2 + iconSize / 2
            )
            dockPitch = HomeDesign.columnPitch * scale
        } else if isDockVertical {
            let scale = min(size.height / HomeDesign.referenceWidth, HomeDesign.maximumScale)
            self.scale = scale
            columns = 6
            rows = 4
            let edge = HomeDesign.dockBottomInset * scale
            let thickness = HomeDesign.dockThickness * scale
            dockFrame = CGRect(
                x: size.width - max(safeArea.trailing, edge) - thickness,
                y: edge,
                width: thickness,
                height: size.height - edge * 2
            )
            editControlsCenterY = max(safeArea.top * 0.54, 24)
            editControlsInset = max(safeArea.leading, safeArea.trailing) + 16
            editButtonSize = HomeDesign.editCapsuleHeight
            let left = max(safeArea.leading, 16 * scale) + 8 * scale
            let right = dockFrame.minX - 8 * scale
            // Below edit mode's buttons with room for the first row's minus
            // badges, as on iPad. The buttons don't move when edit mode
            // starts, so neither do the icons.
            let badgeReach = HomeDesign.minusBadgeSize / 2 - HomeDesign.minusBadgeInset
            let top = max(
                max(safeArea.top, 8 * scale) + 6 * scale,
                editControlsCenterY + editButtonSize / 2 + badgeReach + 4
            )
            pillCenter = CGPoint(
                x: (left + right) / 2,
                y: size.height - max(safeArea.bottom, 8 * scale) - HomeDesign.pillHeight / 2 - 2 * scale
            )
            let bottom = pillCenter.y - HomeDesign.pillHeight / 2 - 4 * scale
            pitch = CGSize(width: (right - left) / 6, height: (bottom - top) / 4)
            iconSize = max(min(HomeDesign.iconSize * scale, pitch.height - labelBlock - 2, pitch.width - 12), 20)
            firstIconCenter = CGPoint(
                x: left + pitch.width / 2,
                y: top + (pitch.height - iconSize - labelBlock) / 2 + iconSize / 2
            )
            // The first of a full dock's four icons, one and a half steps
            // above the dock's middle, starts no higher than the first row,
            // so Done leaves its minus badge clear too.
            dockPitch = min(
                HomeDesign.columnPitch * scale,
                (dockFrame.height - 24 * scale) / 4,
                (dockFrame.midY - iconSize / 2 - top) / 1.5
            )
        } else if isDockFlush {
            // An iPhone with a Home button: fixed sizes, the dock along the
            // bottom edge and the rows as close as the search pill needs.
            scale = 1
            columns = 4
            rows = 6
            let thickness = HomeDesign.squareScreenDockHeight
            dockFrame = CGRect(x: 0, y: size.height - thickness, width: size.width, height: thickness)
            let gap = HomeDesign.squareScreenPillGap
            pillCenter = CGPoint(x: size.width / 2, y: dockFrame.minY - gap - HomeDesign.pillHeight / 2)
            iconSize = HomeDesign.squareScreenIconSize
            let firstIconTop = max(safeArea.top, 20) + HomeDesign.squareScreenFirstRowBelowStatusBar
            let lastRowBottom = pillCenter.y - HomeDesign.pillHeight / 2 - gap
            let rowPitch = min(
                HomeDesign.squareScreenMaximumRowPitch,
                (lastRowBottom - firstIconTop - iconSize - labelBlock) / 5
            )
            pitch = CGSize(width: HomeDesign.squareScreenColumnPitch, height: rowPitch)
            firstIconCenter = CGPoint(
                x: size.width / 2 - pitch.width * 1.5,
                y: firstIconTop + iconSize / 2
            )
            dockPitch = pitch.width
            editButtonSize = HomeDesign.squareScreenEditButtonSize
            // The buttons sit in the status bar, just above the minus badges
            // of the first row.
            editControlsCenterY = max(firstIconTop - HomeDesign.minusBadgeSize / 2 + HomeDesign.minusBadgeInset - editButtonSize / 2, editButtonSize / 2)
            editControlsInset = 16
        } else {
            let scale = min(size.width / HomeDesign.referenceWidth, HomeDesign.maximumScale)
            self.scale = scale
            columns = 4
            rows = 6
            let dockWidth = (HomeDesign.referenceWidth - HomeDesign.dockSideInset * 2) * scale
            let thickness = HomeDesign.dockThickness * scale
            dockFrame = CGRect(
                x: (size.width - dockWidth) / 2,
                y: size.height - HomeDesign.dockBottomInset * scale - thickness,
                width: dockWidth,
                height: thickness
            )
            pillCenter = CGPoint(x: size.width / 2, y: dockFrame.minY - HomeDesign.pillAboveDock * scale)
            // At least the status bar's height, so the icons stay put when edit
            // mode hides the status bar.
            let firstIconTop = max(safeArea.top, 20) + HomeDesign.firstRowBelowStatusBar * scale
            let pillTop = pillCenter.y - HomeDesign.pillHeight / 2
            let rowPitch = (pillTop - firstIconTop) / HomeDesign.rowsAbovePill
            pitch = CGSize(width: HomeDesign.columnPitch * scale, height: rowPitch)
            iconSize = max(min(HomeDesign.iconSize * scale, rowPitch - labelBlock - 2), 20)
            // A real Home Screen's grid sits a little right of center.
            firstIconCenter = CGPoint(
                x: size.width / 2 - pitch.width * 1.5 + HomeDesign.gridOffsetX * scale,
                y: firstIconTop + iconSize / 2
            )
            dockPitch = pitch.width
            // Where iOS 27 puts them, in the status bar's place, which edit
            // mode hides: a little above its bottom, under its left and right
            // items.
            editControlsCenterY = max(
                safeArea.top * HomeDesign.editControlsCenterFraction,
                HomeDesign.editCapsuleHeight / 2 + 4
            )
            editControlsInset = max(size.width * HomeDesign.editControlsInsetFraction, 16)
            editButtonSize = HomeDesign.editCapsuleHeight
        }

        iconCornerRadius = iconSize * HomeDesign.iconCornerFraction
        let nameWidth = max(pitch.width - 6, iconSize)
        // An iPad's columns are wide, and iPadOS cuts long names off near
        // their icon rather than letting them run across the column.
        cellWidth = isPhone ? nameWidth : min(nameWidth, iconSize + HomeDesign.padNameOverhang * 2 * scale)
        cellHeight = iconSize + labelBlock
        dockCornerRadius = isDockFlush ? 0 : HomeDesign.dockCornerRadius * scale
        dockRoom = isPhone ? nil : dockFrame.width - HomeDesign.padDockEndPadding * 2 * scale

        // The Home button is centered where the pill is, between the names of
        // the last row and the dock.
        if isDockVertical {
            pillButtonScale = 1
        } else {
            let lastNameBottom = firstIconCenter.y - iconSize / 2 + pitch.height * Double(rows - 1) + cellHeight
            let room = min(pillCenter.y - lastNameBottom, dockFrame.minY - pillCenter.y) - 2
            pillButtonScale = min(max(room * 2 / HomeDesign.homeButtonSize, 0.5), 1)
        }
    }

    /// The layout of the iPhone 13 Pro Max in portrait, the screen HomeDesign
    /// was measured on, for views that show icons before the screen's size is known.
    static let reference = HomeMetrics(
        size: CGSize(width: 428, height: 926),
        safeArea: EdgeInsets(top: 47, leading: 0, bottom: 34, trailing: 0)
    )

    /// How many icons a page holds.
    var iconsPerPage: Int {
        columns * rows
    }

    /// The center of the icon at `index` on a page, on screen.
    func iconCenter(at index: Int) -> CGPoint {
        let column = index % columns
        let row = index / columns
        return CGPoint(
            x: firstIconCenter.x + Double(column) * pitch.width,
            y: firstIconCenter.y + Double(row) * pitch.height
        )
    }

    /// The center of the icon and its name together, which is where the view
    /// holding both goes for the icon at `index` on a page.
    func cellCenter(at index: Int) -> CGPoint {
        let icon = iconCenter(at: index)
        return CGPoint(x: icon.x, y: icon.y - iconSize / 2 + cellHeight / 2)
    }

    /// The center of the icon at `index` in a dock holding `count` icons,
    /// which keeps its icons centered as iOS does.
    func dockIconCenter(at index: Int, count: Int) -> CGPoint {
        let offset = (Double(index) - Double(max(count, 1) - 1) / 2) * dockSpacing(count: count).pitch
        if isDockVertical {
            return CGPoint(x: dockFrame.midX, y: dockFrame.midY + offset)
        }
        return CGPoint(x: dockFrame.midX + offset, y: dockFrame.midY)
    }

    /// The size of the icons in a dock holding `count` icons. It is
    /// `iconSize`, except in an iPad window too narrow for that many at the
    /// pages' size.
    func dockIconSize(count: Int) -> Double {
        dockSpacing(count: count).icon
    }

    /// These metrics with the icons at the size of a dock holding `count`
    /// icons, for drawing the dock's icons. They are these same metrics
    /// wherever the dock's icons are the pages' size. Only for drawing: the
    /// icons' places come from these metrics, not from the copy.
    func dockIconMetrics(count: Int) -> HomeMetrics {
        let size = dockIconSize(count: count)
        guard size != iconSize else {
            return self
        }
        var metrics = self
        metrics.iconSize = size
        metrics.iconCornerRadius = size * HomeDesign.iconCornerFraction
        metrics.cellHeight = size + HomeDesign.labelSpacing + HomeDesign.labelLineHeight
        return metrics
    }

    /// The frame of the dock's glass for a dock holding `count` icons. An
    /// iPad's glass fits its icons, as on iPadOS, with room for one when the
    /// dock is empty so it stays in sight. An iPhone's is always `dockFrame`.
    func dockFrame(holding count: Int) -> CGRect {
        guard dockRoom != nil else {
            return dockFrame
        }
        let count = max(count, 1)
        let spacing = dockSpacing(count: count)
        let width = Double(count - 1) * spacing.pitch + spacing.icon + HomeDesign.padDockEndPadding * 2 * scale
        return CGRect(x: dockFrame.midX - width / 2, y: dockFrame.minY, width: width, height: dockFrame.height)
    }

    /// How far apart the icons of a dock holding `count` icons are, and how
    /// big. An iPhone's dock spaces its icons the same whatever their number.
    /// An iPad's keeps them `dockPitch` apart while they fit; in a narrow
    /// window it brings them closer, then shrinks them, so a full dock still
    /// fits, as iPadOS does.
    private func dockSpacing(count: Int) -> (pitch: Double, icon: Double) {
        guard let dockRoom, count > 1 else {
            return (dockPitch, iconSize)
        }
        let slots = Double(count)
        let pitch = min(dockPitch, (dockRoom - iconSize) / (slots - 1))
        let gap = HomeDesign.padMinimumDockGap * scale
        guard pitch - iconSize < gap else {
            return (pitch, iconSize)
        }
        let closest = (dockRoom + gap) / slots
        return (closest, closest - gap)
    }

    /// An icon's frame, around its center.
    func iconFrame(around center: CGPoint) -> CGRect {
        CGRect(x: center.x - iconSize / 2, y: center.y - iconSize / 2, width: iconSize, height: iconSize)
    }

    /// The position on a page nearest to a point on screen.
    func gridIndex(nearest point: CGPoint) -> Int {
        let column = Self.steps(point.x - firstIconCenter.x, of: pitch.width)
        let row = Self.steps(point.y - firstIconCenter.y, of: pitch.height)
        return min(max(row, 0), rows - 1) * columns + min(max(column, 0), columns - 1)
    }

    /// How many whole steps of `step` points fit in `distance`, rounded, or 0
    /// before the screen has a size.
    private static func steps(_ distance: Double, of step: Double) -> Int {
        guard step > 0, distance.isFinite else {
            return 0
        }
        return Int((distance / step).rounded())
    }

    /// Whether a point is over the glass of a dock holding `count` icons,
    /// with a little room around it.
    func dockContains(_ point: CGPoint, count: Int) -> Bool {
        dockFrame(holding: count).insetBy(dx: -8, dy: -8).contains(point)
    }
}
