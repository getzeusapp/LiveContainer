//
//  HomeMetrics.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Where everything on the Home Screen goes on the current screen, in points
/// from the screen's top left corner. An iPhone in portrait gets the layout
/// iOS gives its screen, from HomePhoneLayout: the icons' size and places,
/// the floating dock, or the full-width one of iPhones with a Home button,
/// and the search pill. In landscape HomeDesign's measurements are scaled
/// from the screen's size, the grid turns to 6 columns by 4 rows and the dock
/// stands on the trailing side, as on iPhones whose Home Screen rotates.
/// An iPad filling its screen gets the layout iPadOS gives it, from
/// HomePadLayout: pages of 30 icons, 5 by 6 in portrait and 6 by 5 in
/// landscape, and the dock floating at the bottom in both orientations, laid
/// out by HomePadDock, its glass as wide as its icons need. Split View, Slide
/// Over and Stage Manager windows, which iPadOS has no Home Screen for, fit
/// the same pages and dock into their size.
struct HomeMetrics: Equatable {
    /// The size of the whole screen.
    let size: CGSize
    /// The factor HomeDesign's sizes are multiplied by.
    let scale: Double
    /// How many columns a page has.
    private(set) var columns: Int
    /// How many rows a page has.
    private(set) var rows: Int
    /// An icon's width and height.
    private(set) var iconSize: Double
    /// An icon's corner radius.
    private(set) var iconCornerRadius: Double
    /// The width an icon's name can use.
    let cellWidth: Double
    /// The height of an icon with its name under it.
    private(set) var cellHeight: Double
    /// The dock's frame. On an iPad it is the room the dock has: across the
    /// window, 8 points from each side, and as tall as the glass is at most,
    /// its bottom edge where the glass's is. The glass is only as wide as
    /// what the dock holds needs, centered in it: `dockGlass(_:)` gives it.
    let dockFrame: CGRect
    /// Whether the dock stands on the trailing side, on an iPhone in landscape.
    let isDockVertical: Bool
    /// Whether the dock runs the full width of the screen, flush with its
    /// bottom edge, as on iPhones with a Home button.
    let isDockFlush: Bool
    /// The dock's corner radius, as SpringBoard gives it: on an iPhone, its
    /// screen's, and on an iPad, at full size. `dockCornerRadius(_:)` gives
    /// an iPad dock's for what it holds.
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
    /// The width of edit mode's capsules.
    var editButtonWidth: Double {
        SharedModel.isPhone ? HomeDesign.editCapsuleWidth : HomeDesign.padEditCapsuleWidth
    }
    /// The size of edit mode's round add button, and the height of Done.
    let editButtonSize: Double

    /// The center of the first icon on a page.
    private var firstIconCenter: CGPoint
    /// The distance between neighboring columns and rows, which an open
    /// folder's icons keep too.
    private(set) var pitch: CGSize
    /// The distance between neighboring icons in an iPhone's dock, which has
    /// a fixed size and spaces its icons the same whatever their number.
    /// Unused on an iPad, whose dock HomePadDock lays out.
    private let dockPitch: Double
    /// Whether the dock floats as iPadOS's does, laid out by HomePadDock.
    private let hasPadDock: Bool

    /// Lays the Home Screen out for a screen of `size`, whose system bars
    /// cover `safeArea`. `isPhone` tells an iPhone from an iPad, since iPads
    /// and iPhones with a Home button each get their own layout.
    init(size: CGSize, safeArea: EdgeInsets, isPhone: Bool = true) {
        self.size = size
        let labelBlock = HomeDesign.labelSpacing + HomeDesign.labelLineHeight
        // Only iPhones stand the dock on the side; iPadOS keeps it at the bottom.
        isDockVertical = isPhone && size.width > size.height
        isDockFlush = isPhone && !isDockVertical && safeArea.bottom == 0
        hasPadDock = !isPhone

        if !isPhone {
            // An iPad, or a window on one: the dock floats at the bottom in
            // both orientations, as iPadOS's does, the same on every iPad. A
            // window filling the screen gets iPadOS's own layout for it; a
            // smaller one, which iPadOS has no Home Screen for, fits the same
            // pages of 30 into its size, and the dock's icons shrink when it
            // holds more than fit across it, as iPadOS's do.
            editButtonSize = HomeDesign.padEditCapsuleHeight
            editControlsCenterY = HomeDesign.padEditControlsInset + editButtonSize / 2
            editControlsInset = max(safeArea.leading, safeArea.trailing) + HomeDesign.padEditControlsInset
            dockPitch = 0
            let dockInset = HomePadLayout.dockBottomInset
            let dockLeft = max(safeArea.leading, dockInset)
            let dockRight = size.width - max(safeArea.trailing, dockInset)
            dockFrame = CGRect(
                x: dockLeft,
                y: size.height - HomePadLayout.dockBottomInset - HomePadLayout.dockHeight,
                width: dockRight - dockLeft,
                height: HomePadLayout.dockHeight
            )

            if let layout = HomePadLayout.fullScreen(size) {
                scale = 1
                columns = layout.columns
                rows = layout.rows
                iconSize = HomePadLayout.iconSize
                pitch = CGSize(width: layout.columnPitch, height: layout.rowPitch)
                // Centered across the screen, at the height iPadOS puts it.
                firstIconCenter = CGPoint(
                    x: size.width / 2 - Double(layout.columns - 1) / 2 * layout.columnPitch,
                    y: layout.firstRowTop + iconSize / 2
                )
                pillCenter = CGPoint(x: size.width / 2, y: dockFrame.minY - layout.pageDotsAboveDock)
            } else {
                let scale = min(
                    size.width / HomeDesign.referenceWidth,
                    size.height / HomeDesign.padReferenceHeight,
                    1
                )
                self.scale = scale
                pillCenter = CGPoint(x: size.width / 2, y: dockFrame.minY - HomeDesign.padPageDotsAboveDock)
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
                // beside them and under the names above, and no bigger than
                // iPadOS's. Both pitches count, so a short window gets smaller
                // icons instead of crushed rows.
                func fit(columns: Int, rows: Int) -> (pitch: CGSize, icon: Double) {
                    let pitchWidth = (right - left) / Double(columns)
                    let pitchHeight = min((bottom - top) / Double(rows), pitchWidth * HomeDesign.padMaximumRowToColumnPitch)
                    let icon = min(
                        HomePadLayout.iconSize,
                        pitchHeight - labelBlock - HomeDesign.padMinimumRowGap * scale,
                        pitchWidth - HomeDesign.padMinimumColumnGap * scale
                    )
                    return (CGSize(width: pitchWidth, height: pitchHeight), max(icon, 20))
                }
                // 6 by 5 or 5 by 6, as iPadOS turns its pages, whichever gives
                // bigger icons, so a window near square keeps full size icons
                // and the switch doesn't jump. Both hold a page's 30 icons, so
                // turning the iPad keeps every icon on its page.
                let wide = fit(columns: 6, rows: 5)
                let tall = fit(columns: 5, rows: 6)
                let isWide = abs(wide.icon - tall.icon) < 1 ? size.width > size.height : wide.icon > tall.icon
                columns = isWide ? 6 : 5
                rows = isWide ? 5 : 6
                let chosen = isWide ? wide : tall
                pitch = chosen.pitch
                iconSize = chosen.icon
                firstIconCenter = CGPoint(
                    x: left + pitch.width / 2,
                    y: top + (pitch.height - iconSize - labelBlock) / 2 + iconSize / 2
                )
            }
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
            // An iPhone with a Home button: iOS's layout for its screen, with
            // the dock along the bottom edge and the page dots above it.
            let layout = HomePhoneLayout.portrait(size)
            scale = 1
            columns = 4
            rows = 6
            dockFrame = CGRect(x: 0, y: size.height - layout.dockHeight, width: size.width, height: layout.dockHeight)
            pillCenter = CGPoint(x: size.width / 2, y: dockFrame.minY - layout.pillAboveDock)
            iconSize = layout.iconSize
            pitch = CGSize(width: layout.columnPitch(screenWidth: size.width), height: layout.rowPitch)
            firstIconCenter = CGPoint(x: layout.sideInset + iconSize / 2, y: layout.firstRowTop + iconSize / 2)
            dockPitch = layout.dockPitch
            editButtonSize = HomeDesign.squareScreenEditButtonSize
            // The buttons sit in the status bar, just above the minus badges
            // of the first row.
            editControlsCenterY = max(layout.firstRowTop - HomeDesign.minusBadgeSize / 2 + HomeDesign.minusBadgeInset - editButtonSize / 2, editButtonSize / 2)
            editControlsInset = 16
        } else {
            // An iPhone in portrait: iOS's own layout for its screen. The dock
            // floats as far from the sides as from the bottom, the grid is
            // centered, and the rows sit where iOS puts them, which doesn't
            // depend on the status bar, so edit mode hiding it moves nothing.
            let layout = HomePhoneLayout.portrait(size)
            scale = layout.iconSize / HomeDesign.iconSize
            columns = 4
            rows = 6
            dockFrame = CGRect(
                x: layout.dockInset,
                y: size.height - layout.dockInset - layout.dockHeight,
                width: size.width - layout.dockInset * 2,
                height: layout.dockHeight
            )
            pillCenter = CGPoint(x: size.width / 2, y: dockFrame.minY - layout.pillAboveDock)
            iconSize = layout.iconSize
            pitch = CGSize(width: layout.columnPitch(screenWidth: size.width), height: layout.rowPitch)
            firstIconCenter = CGPoint(x: layout.sideInset + iconSize / 2, y: layout.firstRowTop + iconSize / 2)
            dockPitch = layout.dockPitch
            // Where iOS 26.5 puts them, in the status bar's place, which edit
            // mode hides, under its left and right items.
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
        dockCornerRadius = if isDockFlush {
            0
        } else if isPhone {
            Self.phoneDockCornerRadius(screenSize: size)
        } else {
            HomePadDock(room: dockFrame, icons: 0, recents: 0).cornerRadius
        }

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

    /// The corner radius of an iPhone's dock on a screen of `screenSize`, in
    /// either orientation, as SpringBoard works it out for that screen: with
    /// this iPhone's own screen corners when it's this iPhone's screen, and
    /// otherwise those of the iPhone its layout was measured on.
    private static func phoneDockCornerRadius(screenSize: CGSize) -> Double {
        let layout = HomePhoneLayout.portrait(screenSize)
        let screen = UIScreen.main.bounds.size
        let isThisScreen = abs(min(screen.width, screen.height) - min(screenSize.width, screenSize.height)) < 0.5
            && abs(max(screen.width, screen.height) - max(screenSize.width, screenSize.height)) < 0.5
        let screenCorner = isThisScreen ? (systemDisplayCornerRadius ?? layout.displayCornerRadius) : layout.displayCornerRadius
        return layout.dockCornerRadius(displayCornerRadius: screenCorner, scale: Double(UIScreen.main.scale))
    }

    /// The corner radius of this device's screen, as iOS gives it, or nil
    /// where it doesn't.
    private static let systemDisplayCornerRadius: Double? = {
        let screen = UIScreen.main
        let key = "_displayCornerRadius"
        guard screen.responds(to: NSSelectorFromString(key)) else {
            return nil
        }
        return (screen.value(forKey: key) as? NSNumber)?.doubleValue
    }()

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

    /// These metrics for a page with widgets. iPadOS lays a page with widgets
    /// out in 4 columns by 6 rows in portrait, the columns as far apart as
    /// its landscape ones, across the middle of the screen, and in 6 columns
    /// by 4 rows in landscape, the rows further apart, where a page of only
    /// icons has 5 of either. A page with widgets lays out like any other on
    /// iPhone and in a smaller window.
    var forWidgetPage: HomeMetrics {
        guard !SharedModel.isPhone, let turned = HomePadLayout.fullScreen(CGSize(width: size.height, height: size.width)) else {
            return self
        }
        var metrics = self
        if columns == 5 {
            metrics.columns = 4
            metrics.pitch.width = turned.columnPitch
            metrics.firstIconCenter.x = size.width / 2 - 1.5 * turned.columnPitch
        } else if columns == 6, rows == 5 {
            metrics.rows = 4
            metrics.pitch.height = turned.rowPitch * HomeDesign.padLandscapeWidgetRowRatio
        }
        return metrics
    }

    /// The frame on screen of a widget whose top left place on a page is
    /// `origin`, spanning `span` places across and down. On iPhone a widget
    /// reaches from the top of its first row's icons to the bottom of its
    /// last row's, and a small one is as wide as it's tall, centered on its
    /// two columns, as iOS draws them; a wider one reaches from its first two
    /// columns' small widget to its last two's. On iPad a widget's places are
    /// each twice an icon's size, around the icon's center.
    func widgetFrame(origin: Int, span: (columns: Int, rows: Int)) -> CGRect {
        let first = iconCenter(at: origin)
        let last = iconCenter(at: origin + (span.rows - 1) * columns + span.columns - 1)
        guard SharedModel.isPhone else {
            // iPadOS's widgets are the same size whatever the rows' pitch:
            // twice an icon's size, and a larger one two of those and the
            // gap between them, centered on their places.
            let side = smallWidgetSide
            let width = Double(span.columns) * side + Double(span.columns - 1) * HomeDesign.padWidgetGap
            let height = Double(span.rows) * side + Double(span.rows - 1) * HomeDesign.padWidgetGap
            let center = CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2)
            return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
        }
        let side = smallWidgetSide
        let left = first.x + pitch.width / 2 - side / 2
        let right = last.x - pitch.width / 2 + side / 2
        return CGRect(x: left, y: first.y - iconSize / 2, width: right - left, height: last.y - first.y + iconSize)
    }

    /// The width and height of a small widget: two rows of icons tall on
    /// iPhone, and twice an icon's size on iPad.
    var smallWidgetSide: Double {
        SharedModel.isPhone ? pitch.height + iconSize : iconSize * 2
    }

    /// How much smaller than an iPhone's a widget's content is drawn: on
    /// iPad, a small widget's side over the side iPadOS lays it out at, as
    /// iPadOS draws widgets laid out at about an iPhone's size made smaller;
    /// 1 on iPhone, whose widgets are laid out at their own size.
    var widgetContentScale: Double {
        SharedModel.isPhone ? 1 : smallWidgetSide / HomeWidgetDesign.padLayoutSide
    }

    /// A widget's corner radius, the same at every size, as iOS rounds them.
    var widgetCornerRadius: Double {
        smallWidgetSide * HomeDesign.widgetCornerFraction
    }

    /// The center of the icon and its name together, which is where the view
    /// holding both goes for the icon at `index` on a page.
    func cellCenter(at index: Int) -> CGPoint {
        let icon = iconCenter(at: index)
        return CGPoint(x: icon.x, y: icon.y - iconSize / 2 + cellHeight / 2)
    }

    /// The iPad's dock holding `contents`, as iPadOS lays it out, or nil on
    /// an iPhone, whose dock has a fixed size.
    func padDock(_ contents: HomeDockContents) -> HomePadDock? {
        guard hasPadDock else {
            return nil
        }
        return HomePadDock(room: dockFrame, icons: contents.icons, recents: contents.recents, largestIcon: iconSize)
    }

    /// The center of the icon at `index` in a dock holding `contents`, which
    /// keeps its icons centered as iOS does.
    func dockIconCenter(at index: Int, in contents: HomeDockContents) -> CGPoint {
        if let dock = padDock(contents) {
            return dock.iconCenter(at: index)
        }
        let offset = (Double(index) - Double(max(contents.icons, 1) - 1) / 2) * dockPitch
        if isDockVertical {
            return CGPoint(x: dockFrame.midX, y: dockFrame.midY + offset)
        }
        return CGPoint(x: dockFrame.midX + offset, y: dockFrame.midY)
    }

    /// The center of the recent app at `index` in an iPad's dock holding
    /// `contents`. An iPhone's dock has no recent apps.
    func dockRecentCenter(at index: Int, in contents: HomeDockContents) -> CGPoint {
        padDock(contents)?.recentCenter(at: index) ?? CGPoint(x: dockFrame.midX, y: dockFrame.midY)
    }

    /// The size of the icons in a dock holding `contents`. It is `iconSize`,
    /// except in an iPad dock holding more than fit across it at that size.
    func dockIconSize(_ contents: HomeDockContents) -> Double {
        padDock(contents)?.iconSize ?? iconSize
    }

    /// These metrics with the icons at the size of a dock holding `contents`,
    /// for drawing the dock's icons. They are these same metrics wherever
    /// the dock's icons are the pages' size. Only for drawing: the icons'
    /// places come from these metrics, not from the copy.
    func dockIconMetrics(_ contents: HomeDockContents) -> HomeMetrics {
        withIconSize(dockIconSize(contents))
    }

    /// These metrics with icons `size` points across, rounded to match, for
    /// drawing icons at another size than the pages': the dock's when it
    /// shrinks them, and search's on iPad. Only for drawing: the icons'
    /// places on the Home Screen come from these metrics, not from the copy.
    func withIconSize(_ size: Double) -> HomeMetrics {
        guard size != iconSize else {
            return self
        }
        var metrics = self
        metrics.iconSize = size
        metrics.iconCornerRadius = size * HomeDesign.iconCornerFraction
        metrics.cellHeight = size + HomeDesign.labelSpacing + HomeDesign.labelLineHeight
        return metrics
    }

    /// The frame of the glass of a dock holding `contents`. An iPad's fits
    /// what it holds, as iPadOS's does, and is never narrower than four
    /// icons; an iPhone's is always `dockFrame`.
    func dockGlass(_ contents: HomeDockContents) -> CGRect {
        padDock(contents)?.platter ?? dockFrame
    }

    /// The corner radius of the glass of a dock holding `contents`, which on
    /// an iPad gets smaller with its icons.
    func dockCornerRadius(_ contents: HomeDockContents) -> Double {
        padDock(contents)?.cornerRadius ?? dockCornerRadius
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

    /// Whether a point is over the glass of a dock holding `contents`, with a
    /// little room around it.
    func dockContains(_ point: CGPoint, _ contents: HomeDockContents) -> Bool {
        dockGlass(contents).insetBy(dx: -8, dy: -8).contains(point)
    }
}

/// What the dock holds, which on an iPad sets how it's laid out: the
/// person's icons, counting the place kept for one while an icon is being
/// dragged, and the recent apps after them. An iPhone's dock holds no recent
/// apps.
struct HomeDockContents: Equatable {
    /// How many of the person's icons the dock makes room for.
    var icons: Int
    /// How many recent apps it shows after them.
    var recents = 0
}
