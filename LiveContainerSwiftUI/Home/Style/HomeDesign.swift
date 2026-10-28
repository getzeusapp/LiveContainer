//
//  HomeDesign.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Home Screen's look in one place. Sizes are in points, measured on an
/// iPhone 13 Pro Max running iOS 27 (428 by 926 points); HomeMetrics scales
/// them to the screen in use.
enum HomeDesign {
    // MARK: Reference screen

    /// The width the sizes below were measured at.
    static let referenceWidth = 428.0
    /// The largest scale HomeMetrics applies, so an iPad's icons come out a
    /// little larger than an iPhone's instead of giant.
    static let maximumScale = 1.2
    /// The coordinate space of the whole screen, which HomeMetrics' positions
    /// and the drag gesture share.
    static let coordinateSpace = "HomeScreen"

    // MARK: Icons

    /// An icon's width and height.
    static let iconSize = 68.0
    /// An icon's corner radius as a fraction of its size, the Home Screen
    /// icon shape.
    static let iconCornerFraction = 0.225
    /// The plain tile an app's icon shows as until IconServices has drawn
    /// it, and that a new app's place shows while it installs.
    static let iconPlaceholder = Color(white: 0.3)
    /// The distance between the centers of neighboring columns.
    static let columnPitch = 98.6
    /// How far the grid sits right of the screen's center on a real Home
    /// Screen, which isn't quite centered. The dock is.
    static let gridOffsetX = 1.85
    /// How far the first row's icons start below the status bar.
    static let firstRowBelowStatusBar = 24.8
    /// The distance from the first row's top to the search pill's top, in
    /// rows: the grid fills that space, so smaller screens get tighter rows.
    static let rowsAbovePill = 6.383
    /// The space between an icon and its name.
    static let labelSpacing = 5.0
    /// The size of an icon's name. The Home Screen keeps names at this size
    /// whatever the text size setting, as iOS does.
    static let labelFontSize = 12.0
    /// The weight of an icon's name, a little heavier than regular, as on iOS.
    static let labelWeight = Font.Weight.medium
    /// The height of a name's line.
    static let labelLineHeight = 14.3
    /// The color of the names, readable on a dark wallpaper.
    static let labelColor = Color.white
    /// The soft shadow under the names over the wallpaper, so they read over
    /// its bright parts, as on iOS.
    static let labelShadow = Color.black.opacity(0.45)
    /// How far the names' shadow spreads.
    static let labelShadowRadius = 2.0

    // MARK: iPhones with a Home button

    // These iPhones have square screen corners and nothing under the screen's
    // bottom edge, so iOS lays their Home Screen out with fixed sizes rather
    // than scaling the Face ID layout: the 4.7 inch grid of 60 point icons
    // 87 points apart, and a full-width dock along the bottom.

    /// An icon's width and height.
    static let squareScreenIconSize = 60.0
    /// The distance between the centers of neighboring columns, which leaves
    /// 27 points at each side of a 375 point screen.
    static let squareScreenColumnPitch = 87.0
    /// The most the rows can be apart, the distance on the 4.7 inch grid.
    /// They come closer when the search pill needs the room.
    static let squareScreenMaximumRowPitch = 88.0
    /// How far the first row's icons start below the status bar, which keeps
    /// them clear of edit mode's buttons.
    static let squareScreenFirstRowBelowStatusBar = 20.0
    /// The dock's height. It runs the full width of the screen, flush with
    /// the bottom edge, with square corners.
    static let squareScreenDockHeight = 96.0
    /// The space between the search pill and the dock, and between the
    /// pill and the names of the last row.
    static let squareScreenPillGap = 4.0
    /// The size of edit mode's round add button and the height of Done,
    /// smaller than elsewhere so they fit the short status bar.
    static let squareScreenEditButtonSize = 28.0

    // MARK: iPad

    // iPadOS keeps the dock floating at the bottom in both orientations and
    // spreads the grid over the whole screen, so iPads (and their Split View,
    // Slide Over and Stage Manager windows) get their own layout rather than
    // a scaled up iPhone.

    /// The height HomeDesign's sizes reach full scale at on an iPad, so short
    /// windows scale down as narrow ones do. An iPad mini in landscape (744
    /// points high) still gets full size icons.
    static let padReferenceHeight = 620.0
    /// The space between the grid's outer cells and the sides of the screen,
    /// before scaling. Icons sit centered in their cells, further in.
    static let padGridSideInset = 24.0
    /// The least room between neighboring icons, before scaling. Icons shrink
    /// before they get closer.
    static let padMinimumColumnGap = 16.0
    /// The least room between a name and the icon under it, before scaling.
    static let padMinimumRowGap = 12.0
    /// The most the rows can be apart, as a multiple of the column distance,
    /// so a tall narrow window doesn't pull its rows far apart. The grid
    /// keeps to the top, as a page that isn't full does.
    static let padMaximumRowToColumnPitch = 1.6
    /// How far a name can reach past each side of its icon, before scaling.
    /// iPadOS cuts long names off near their icon rather than letting them
    /// run across the wide columns.
    static let padNameOverhang = 16.0
    /// The space between the ends of the dock's glass and its first and last
    /// icons, before scaling, as on the iPhone's full dock. The glass is only
    /// as wide as its icons need, as on iPadOS.
    static let padDockEndPadding = 17.7
    /// The least room between neighboring icons in the dock, before scaling.
    /// In a window too narrow for a full dock at the pages' icon size, the
    /// dock's icons come this close, then shrink.
    static let padMinimumDockGap = 12.0

    // MARK: Dock

    /// The space between the dock and the sides of the screen.
    static let dockSideInset = 14.4
    /// The dock's height (its width on an iPhone in landscape, where it
    /// stands on the side).
    static let dockThickness = 105.0
    /// The space between the dock and the bottom of the screen.
    static let dockBottomInset = 13.5
    /// The dock's corner radius before iOS 26, where corners can't follow the
    /// screen's. It matches the 13 Pro Max's screen corners less the inset.
    static let dockCornerRadius = 39.0

    // MARK: Wallpaper

    /// How much black goes over a photo wallpaper when it's dimmed, about
    /// what iOS's dark mode dims wallpapers by.
    static let wallpaperDimming = 0.22

    // MARK: Search pill and page dots

    /// How far the search pill's center sits above the dock.
    static let pillAboveDock = 40.2
    /// The search pill's height.
    static let pillHeight = 30.0
    /// The space at each end of the pill.
    static let pillPadding = 12.0
    /// The space between the magnifying glass and "Search".
    static let pillSpacing = 5.0
    /// The size of the pill's text.
    static let pillFontSize = 12.0
    /// The color of the pill's text and glass.
    static let pillTextColor = Color(white: 0.75)
    /// A page dot's size.
    static let pageDotSize = 7.0
    /// The space between page dots.
    static let pageDotSpacing = 8.0
    /// How long the dots stay after the pages stop moving, before "Search"
    /// comes back.
    static let pageDotsLinger = Duration.milliseconds(900)
    /// How far a finger dragged along the page dots moves to go one page
    /// further, a little more than a dot and the space after it.
    static let pageScrubStep = 20.0

    // MARK: Glass

    /// The fill behind the dock and the pill where Liquid Glass isn't
    /// available, the gray the glass shows over a black wallpaper.
    static let fallbackGlassFill = Color(white: 0.067)
    /// The line along the top of a dock that runs to the screen's edges,
    /// where Liquid Glass isn't available.
    static let fallbackGlassHairline = Color(white: 0.3)
    /// The light rim along the glass's edge where Liquid Glass isn't available.
    static let fallbackGlassRim = LinearGradient(
        colors: [Color(white: 0.42), Color(white: 0.12), Color(white: 0.24)],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: Editing

    /// How far icons tilt each way while they jiggle, in degrees.
    static let jiggleAngle = 1.4
    /// How long a jiggle takes to tilt one way and back.
    static let jiggleDuration = 0.26
    /// How long an icon must be held in edit mode before it can be dragged,
    /// so a quick swipe still turns the page.
    static let pickUpDelay = 0.15
    /// How far a finger can move on an icon in edit mode and still count as a
    /// tap, which opens a folder however long it was held.
    static let tapSlop = 10.0
    /// How long a long-press menu takes to close, which Edit Home Screen waits
    /// out before the icons start to jiggle.
    static let menuCloseDuration = Duration.milliseconds(400)
    /// How much a dragged icon grows.
    static let liftedScale = 1.12
    /// The shadow under a dragged icon, which lifts it off the others.
    static let liftedShadowOpacity = 0.4
    static let liftedShadowRadius = 12.0
    static let liftedShadowOffset = 6.0
    /// How close to the side of the screen a dragged icon turns the page.
    static let pageTurnEdge = 28.0
    /// How long a dragged icon waits at the side before the page turns.
    static let pageTurnDelay = Duration.milliseconds(550)
    /// How long a dragged icon hovers over a place before the icons move to
    /// make room, so they don't shuffle while it passes over them.
    static let reflowDelay = Duration.milliseconds(110)
    /// The size of the minus badge on icons in edit mode.
    static let minusBadgeSize = 22.0
    /// How far the minus badge's center is from the icon's top left corner.
    static let minusBadgeInset = 3.0

    // MARK: Buttons

    /// The smallest touch area a control gets.
    static let minimumTouchSize = 44.0
    /// The size of edit mode's round add button, and the height of Done.
    static let editButtonSize = 36.0
    /// The space at each end of Done.
    static let editButtonPadding = 18.0
    /// An iPhone's edit mode buttons, as iOS 27 draws them: two glass
    /// capsules of the same size, add and Done, measured on an iPhone 13 Pro
    /// Max.
    static let editCapsuleWidth = 66.0
    static let editCapsuleHeight = 28.0
    /// The point size of the glyphs in those capsules.
    static let editCapsuleGlyphSize = 15.0
    /// Where those capsules sit on an iPhone in portrait, where the status
    /// bar was: their centers this share of the status bar's height down, and
    /// their outer ends this share of the screen's width in from the sides,
    /// under the status bar's left and right items.
    static let editControlsCenterFraction = 0.79
    static let editControlsInsetFraction = 0.1

    // MARK: Home button

    /// The Home button's width and height, on zContainer's own screens and
    /// over apps alike (TweakLoader's LCHomeButtonView draws the same button).
    static let homeButtonSize = 52.0
    /// The rings on the Home button, from the outside in: each one's width and
    /// how white it is. They stack like AssistiveTouch's, a soft halo around a
    /// bright dot.
    static let homeButtonRings: [(size: Double, opacity: Double)] = [(40, 0.12), (32, 0.22), (24, 0.92)]
    /// The dark tint of the Home button's glass, so it looks the same over the
    /// wallpaper, over Settings in light mode and over apps.
    static let homeButtonTint = Color.black.opacity(0.32)
    /// The light rim of the Home button where Liquid Glass isn't available.
    static let homeButtonRim = Color.white.opacity(0.22)
    /// The space above and below the Home button in a screen's bottom bar.
    static let homeButtonBarPadding = 8.0
    /// How much the Home button shrinks while it is pressed.
    static let homeButtonPressedScale = 0.9

    // MARK: Search

    /// How much the Home Screen blurs behind search.
    static let searchBlur = 24.0
    /// How far a pull on the pages must go down to open search.
    static let pullToSearchDistance = 60.0
    /// How far a pull on the pages goes down to bring search in completely.
    static let searchPullRange = 140.0
    /// How far above its place search starts as a pull brings it in.
    static let searchPullOffset = 36.0
    /// How much search darkens the Home Screen behind it.
    static let searchDimming = 0.35
    /// How much the Home Screen shrinks behind search.
    static let searchScale = 0.94
    /// How long search waits for its field to get the keyboard before it
    /// shows the Home button under the field anyway.
    static let searchFocusWait = Duration.milliseconds(300)
    /// The space between search's panels and the sides of the screen.
    static let searchMargin = 16.0
    /// The space between search's panels, and above the search field.
    static let searchSpacing = 14.0
    /// The height of the search field and of the rows in search's panels.
    static let searchFieldHeight = 48.0
    /// The space inside search's panels.
    static let searchPanelPadding = 16.0
    /// The corner radius of search's panels.
    static let searchPanelCornerRadius = 26.0

    // MARK: Folders

    /// How big a folder icon's small icons are, and the space between them,
    /// as a share of the folder icon: 13 and 3 points on a 68 point icon, as
    /// iOS 27 draws them.
    static let folderMiniRatio = 13.0 / 68.0
    static let folderMiniGapRatio = 3.0 / 68.0
    /// An open folder's name: its size, how far its baseline sits above the
    /// panel, and how far large type's own spacing puts it before the first
    /// column, as iOS 27 has it.
    static let folderTitleSize = 36.0
    static let folderTitleGap = 38.0
    static let folderTitleOverhang = 3.0
    /// The least space under an open folder's panel on a screen too short
    /// to center the panel with its name above it, such as an iPhone's in
    /// landscape, where the panel moves down under the name instead.
    static let folderShortScreenMargin = 16.0
    /// How dark the blurred Home Screen gets behind an open folder.
    static let folderDim = 0.3
    /// How far beside an open folder a dragged icon can go and still be over
    /// it, and how long it waits further out before the folder closes and
    /// lets it out onto the Home Screen. A folder that opened under a dragged
    /// icon starts waiting only once it's out, so the finger has time to
    /// reach it.
    static let folderDragMargin = 24.0
    static let folderLeaveDelay = Duration.milliseconds(500)
    /// How far from another icon's center, across and down, a dragged icon
    /// can be and still go into it rather than beside it, as a share of an
    /// icon's size: most of the icon. Beside it, the dragged icon goes before
    /// it over its left half and after it over its right half.
    static let mergeZone = 0.4
    /// How long a dragged icon hovers over another before they'd make or fill
    /// a folder, and how much longer over a folder before the folder opens to
    /// take it at a place of its choosing.
    static let mergeDelay = Duration.milliseconds(350)
    static let folderHoverOpenDelay = Duration.milliseconds(650)
    /// The glass a new folder would be, growing behind the icon it would
    /// hold, and how small that icon gets inside it.
    static let mergeTileScale = 1.25
    static let mergeIconScale = 0.82
    /// How much a folder grows while an icon hovers over it to go in.
    static let mergeFolderScale = 1.12
    /// How small a dropped icon gets as it goes into a folder.
    static let intoFolderScale = 0.3
    /// The light rim around a folder icon's glass, and its width.
    static let folderGlassRim = Color.white.opacity(0.16)
    static let folderGlassRimWidth = 0.75
    /// An open folder's page dots: their size, the space between them, how
    /// faint the other pages' dots are, and how far up from the panel's
    /// bottom edge they sit.
    static let folderPageDotSize = 7.0
    static let folderPageDotSpacing = 8.0
    static let folderPageDotDimming = 0.35
    static let folderPageDotsInset = 10.0
    /// The field a folder's name is typed into in edit mode: the space beside
    /// the name, the room its clear button takes, and its corner radius.
    static let folderNameFieldPadding = 16.0
    static let folderNameFieldVerticalPadding = 4.0
    static let folderNameClearSize = 28.0
    static let folderNameFieldCornerRadius = 22.0

    // MARK: Animations

    /// Icons moving to new places.
    static let reflow = Animation.spring(duration: 0.35, bounce: 0.12)
    /// A picked up icon rising under the finger, its name fading as it goes.
    static let lift = Animation.spring(duration: 0.25, bounce: 0.2)
    /// A dropped icon flying to its place, shrinking back to size and its
    /// name fading back in on the way, so it lands as the icon it becomes.
    static let drop = Animation.spring(duration: 0.4, bounce: 0.12)
    /// A folder zooming out of its icon, or back into it.
    static let folderZoom = Animation.spring(duration: 0.42, bounce: 0.1)
    /// An icon making ready to go into another, or giving up on it.
    static let mergeHighlight = Animation.spring(duration: 0.3, bounce: 0.2)
    /// Edit mode, search and the page dots appearing or going away.
    static let modeChange = Animation.spring(duration: 0.3)
    /// A tapped app zooming open before zContainer turns into it.
    static let launchZoom = Animation.easeIn(duration: 0.26)
}
