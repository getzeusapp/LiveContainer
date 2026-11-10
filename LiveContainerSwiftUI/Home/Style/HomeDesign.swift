//
//  HomeDesign.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Home Screen's look in one place. Sizes are in points, measured on an
/// iPhone 13 Pro Max running iOS 27 (428 by 926 points); HomeMetrics scales
/// them to iPads and to iPhones in landscape. An iPhone in portrait takes its
/// screen's layout from HomePhoneLayout instead.
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
    /// icon shape: 0.26, as SpringBoard's SBHIconImageInfo gives it and
    /// iOS 26.5 draws icons on the Home Screen and in Spotlight, 16.64 points
    /// on a 64 point icon.
    static let iconCornerFraction = 0.26
    /// A widget's corner radius as a fraction of a small widget's side, with
    /// the same continuous curve as an icon's: SpringBoard's widget layers
    /// round 27.94 points on the iPhone 17 Pro's 164.33 point widgets and
    /// 23.12 on an iPad Air's 136, both 0.17 of the side.
    static let widgetCornerFraction = 0.17
    /// The gap between an iPad's widgets, inside a larger one: iPadOS 26.5's
    /// medium and large widgets are 300 points, two small ones of 136 and 28
    /// between them, measured on an iPad Air 11-inch.
    static let padWidgetGap = 28.0
    /// How far apart the rows of an iPad's page with widgets are in
    /// landscape, as a share of its rows in portrait: 160.75 points to 162.5
    /// on an iPad Air 11-inch, as iPadOS 26.5 spaces them.
    static let padLandscapeWidgetRowRatio = 160.75 / 162.5
    /// How much the light rim inside an icon's edge adds, at each of its two
    /// layers, and how wide it is: 9% and 4.5% over the first point and the
    /// first half point, as iOS lights its icons' edges.
    static let iconRimOpacity = 0.035
    static let iconRimWidth = 1.0
    /// The plain tile an app's icon shows as until IconServices has drawn
    /// it, and that a new app's place shows while it installs.
    static let iconPlaceholder = Color(white: 0.3)
    /// The distance between the centers of neighboring columns.
    static let columnPitch = 98.6
    /// How far the first row's icons start below the status bar.
    static let firstRowBelowStatusBar = 24.8
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
    /// How far the page dots' center sits above the dock in an iPad window
    /// smaller than the screen, about where iPadOS puts them full screen.
    static let padPageDotsAboveDock = 30.0

    // MARK: Dock

    /// The space between the dock and the sides of the screen.
    static let dockSideInset = 14.4
    /// The dock's height (its width on an iPhone in landscape, where it
    /// stands on the side).
    static let dockThickness = 105.0
    /// The space between the dock and the bottom of the screen.
    static let dockBottomInset = 13.5

    /// How the iPad's dock changes size when what it holds changes, as
    /// SpringBoard's -[SBFloatingDockViewController
    /// _resizeDockForChangedNumberOfIconsAnimated:] animates it: its glass,
    /// the divider and where its icons start over 0.3 seconds, easing in and
    /// out, while the icons move to their places within it with
    /// SBHIconEditingSettings' spring of 0.67 seconds and 0.85 damping.
    static let padDockResize = Animation.easeInOut(duration: 0.3)
    static let padDockReflow = Animation.spring(duration: 0.67, bounce: 0.15)
    /// A recent app coming into the iPad's dock from a hundredth of its size
    /// and clear, or going out to that, over half a second, the dock
    /// resizing along with it, as SpringBoard animates them.
    static let padDockRecentsChange = Animation.easeInOut(duration: 0.5)
    static let padDockRecentHiddenScale = 0.01
    /// How long after Settings starts opening it covers the dock, where it
    /// goes among the recent apps then, as an app does behind itself.
    static let padDockRecentsBehindScreen = Duration.milliseconds(500)
    /// The line between the person's icons and the recent apps in the iPad's
    /// dock: white at 42%, in Light and Dark alike, as
    /// SBHFloatingDockSeparatorView draws it.
    static let padDockDividerOpacity = 0.42

    // MARK: Wallpaper

    /// How much black goes over a photo wallpaper when it's dimmed, about
    /// what iOS's dark mode dims wallpapers by.
    static let wallpaperDimming = 0.22

    // MARK: Search pill and page dots

    /// How far the search pill's center sits above the dock.
    static let pillAboveDock = 40.2
    /// The search pill's height.
    static let pillHeight = 30.0
    /// The space at each end of the pill, outside the glyph's and the
    /// text's own margins: iOS's 78 point pill has 12.7 points from its
    /// ends to their ink.
    static let pillPadding = 11.5
    /// The space between the magnifying glass and "Search", which leaves
    /// 4.7 points between their ink, as on iOS.
    static let pillSpacing = 3.17
    /// The size of the pill's text.
    static let pillFontSize = 12.0
    /// The size of the pill's magnifying glass, 9.3 points across, as on iOS.
    static let pillGlyphSize = 9.6
    /// How far the pill's text sits above its middle, and the magnifying
    /// glass that much higher again, one pixel each on a 3x screen, as iOS
    /// sets them.
    static let pillContentRaise = 1.0 / 3
    /// The color of the pill's text and glass.
    static let pillTextColor = Color(white: 0.75)
    /// The pill's text and dots over a bright wallpaper, where iOS turns them
    /// dark so they stay readable on the clear glass.
    static let pillDarkTextColor = Color.black.opacity(0.55)
    /// How bright the wallpaper behind the pill has to be, from 0 to 1, for
    /// its text and dots to turn dark.
    static let brightBackdrop = 0.55
    /// The width of wallpaper behind the pill that's measured for that.
    static let pillBackdropWidth = 80.0
    /// A page dot's size in the pill.
    static let pageDotSize = 6.33
    /// The space between page dots in the pill, 14 points from one dot's
    /// center to the next.
    static let pageDotSpacing = 7.67
    /// The space at each end of the pill when it shows the page dots.
    static let pageDotsPadding = 21.0
    /// How much white the dots of the pages not showing have.
    static let pageDotOtherOpacity = 0.45
    /// A page dot's size on iPhones with a Home button, which show the dots
    /// on their own above the dock, with no pill.
    static let bareDotSize = 7.5
    /// The space between those dots, 18 points from one dot's center to the next.
    static let bareDotSpacing = 10.5
    /// How long the dots stay after the pages stop moving, before "Search"
    /// comes back.
    static let pageDotsLinger = Duration.milliseconds(900)
    /// How far a finger dragged along the page dots moves to go one page
    /// further, a little more than a dot and the space after it.
    static let pageScrubStep = 20.0

    // MARK: Glass

    /// The white the dock's and the search pill's clear glass is lit with
    /// in Light Mode. Over black, SpringBoard's glass then shows the same
    /// grey, 47 of 255, and in Dark Mode plain clear glass matches it.
    static let lightModeClearGlassTint = Color.white.opacity(0.12)
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

    /// How icons jiggle in edit mode, as iOS 26.5's SpringBoard animates
    /// them: how far an icon tilts each way, in radians, and shifts each way
    /// across and up and down, in points, and how long each motion takes
    /// one way, in seconds, easing in and out on the same curve.
    static let jiggleTilt = 0.03
    static let jiggleShift = 0.4
    static let jiggleTiltDuration = 0.128
    static let jiggleShiftXDuration = 0.134
    static let jiggleShiftYDuration = 0.142
    static let jiggleCurve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.36, y: 0), endControlPoint: UnitPoint(x: 0.63, y: 1))
    /// How an icon comes back to rest when edit mode ends.
    static let jiggleSettle = Animation.easeOut(duration: 0.3)
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
    /// How much bigger a widget shows while it's dragged: less than an icon,
    /// as it's bigger.
    static let liftedWidgetScale = 1.04
    /// The shadow under a dragged icon, which lifts it off the others.
    static let liftedShadowOpacity = 0.4
    static let liftedShadowRadius = 12.0
    static let liftedShadowOffset = 6.0
    /// Several icons moved at once, as iOS 26.5 stacks them under the finger:
    /// each one under the top one shows a little lower and to the right, each
    /// tilted its own way, with no more than three showing, all of them a
    /// little see-through; and how an icon tapped to join flies in.
    static let stackOffset = CGSize(width: 3, height: 3)
    static let stackTilts: [Double] = [2, -2, 3]
    static let stackOpacity = 0.8
    static let stackJoin = Animation.spring(response: 0.3, dampingFraction: 0.85)
    /// The badge counting the icons in the stack, as iOS 26.5 draws it: a
    /// circle of the system blue, 23 points across, with the count in white,
    /// centered on the top icon's top right corner, a point beyond it.
    static let stackBadgeSize = 23.0
    static let stackBadgeFontSize = 16.0
    static let stackBadgeOutset = 1.0
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
    /// Edit mode's buttons, Edit and Done, as iOS 26.5 draws them: two glass
    /// capsules of the same size, their words in white, measured on an
    /// iPhone 17 Pro and an iPad Air 11-inch.
    static let editCapsuleWidth = 66.0
    static let editCapsuleHeight = 28.0
    static let padEditCapsuleWidth = 59.5
    static let padEditCapsuleHeight = 25.5
    /// The size and weight of their words, and the least space at each end.
    static let editCapsuleFontSize = 15.0
    static let editCapsulePadding = 12.0
    /// Where those capsules sit on an iPhone in portrait, where the status
    /// bar was: their centers this share of the status bar's height down, and
    /// their outer ends this share of the screen's width in from the sides,
    /// under the status bar's left and right items.
    static let editControlsCenterFraction = 0.53
    static let editControlsInsetFraction = 39 / 402.0
    /// How far an iPad's capsules are from the top and the sides.
    static let padEditControlsInset = 16.0

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
    /// Search as iOS 26.5's Spotlight lays it out, measured on an iPhone 17
    /// Pro. Its sections run 16 points from the sides of the screen, from the
    /// top of the safe area, 16 points apart.
    static let searchMargin = 16.0
    /// Room between a panel and the header of the section after it, besides
    /// the header's own. A header after rows has only its own.
    static let searchPanelSectionSpacing = 7.0
    /// A section's title: 15-point medium text in white at 64%. At the top
    /// of search its header is 36 points tall, the baseline 9.67 points above
    /// its bottom. Further down a header is 42 points tall with a line along
    /// its bottom, the baseline 11.67 points above the header's bottom. SF
    /// Pro's descent is 0.241 of its size.
    static let searchHeaderFontSize = 15.0
    static let searchHeaderOpacity = 0.64
    static let searchFirstHeaderHeight = 36.0
    static let searchFirstHeaderBaselineInset = 9.67
    static let searchHeaderHeight = 42.0
    static let searchHeaderBaselineInset = 11.67
    static let searchHeaderDescentShare = 0.241
    /// A panel of icons: white at 10%, rounded concentrically with its icons,
    /// 16 points around them and 20 under the last row, its rows 16 points
    /// apart and four apps across on iPhone.
    static let searchPanelOpacity = 0.1
    static let searchPanelPadding = 16.0
    static let searchPanelBottomPadding = 20.0
    static let searchPanelRowSpacing = 16.0
    static let searchPanelColumns = 4
    /// An icon's cell in a panel: the icon, and 14 points for its name, which
    /// runs on lower.
    static let searchCellLabelRoom = 14.0
    /// The Top Hit's highlight: white at 20%, 3 points around its icon.
    static let searchTopHitHighlightOpacity = 0.2
    static let searchTopHitHighlightOutset = 3.0
    /// A row of an app found: its icon 16 points from the row's top and
    /// bottom, and its name 14 points beside it in 17-point semibold.
    static let searchRowPadding = 16.0
    static let searchRowSpacing = 14.0
    static let searchRowFontSize = 17.0
    /// The lines between rows and under section titles: white at 18%.
    static let searchSeparatorOpacity = 0.18
    /// The search field: a capsule 48 points tall, 35 points from the sides
    /// with the keyboard down and 8 with it up, 3 points above the keyboard or
    /// the bottom of the safe area. The magnifying glass 12 points in, the
    /// text 8 beyond it in 17-point medium, the placeholder in white at 25%.
    static let searchFieldHeight = 48.0
    static let searchFieldMargin = 35.0
    static let searchFieldKeyboardMargin = 8.0
    static let searchFieldBottomGap = 3.0
    static let searchFieldLeadingInset = 12.0
    static let searchFieldIconSpacing = 8.0
    static let searchFieldFontSize = 17.0
    static let searchFieldPlaceholderOpacity = 0.25
    /// The clear button's 44-point target 5.5 points from the field's end,
    /// which puts its 17-point glyph 19 points from it.
    static let searchFieldClearButtonInset = 5.5

    // MARK: Search on iPad

    /// Search on iPad, as iPadOS 26.5's Spotlight lays it out, measured on an
    /// iPad Air 11-inch (M4): a panel of glass over the Home Screen, which
    /// stays as it is. The panel is 600 points wide, or 20 points from the
    /// sides where that's too wide, 80 points from the top of the screen,
    /// and as tall as what it shows, down to 80 points from the bottom. Its
    /// corners are 30.5 points round, and its shadow black at 50%, 30.5
    /// points soft and 10 points down.
    static let padSearchPanelWidth = 600.0
    static let padSearchPanelSideMargin = 20.0
    static let padSearchPanelTop = 80.0
    static let padSearchPanelBottom = 80.0
    /// How far the panel stays above an on-screen keyboard.
    static let padSearchPanelKeyboardGap = 20.0
    static let padSearchPanelCornerRadius = 30.5
    static let padSearchPanelShadowOpacity = 0.5
    static let padSearchPanelShadowRadius = 30.5
    static let padSearchPanelShadowOffset = 10.0
    /// The field along the panel's top: a row 61 points tall, a line white
    /// at 20% along its bottom, 22 points from the panel's sides. The
    /// magnifying glass is 24-point medium, 17.5 points in, and the text
    /// 26-point medium white, 57 points in, its placeholder white at 20%.
    /// The clear button's glyph is 22-point medium, its middle 33.75 points
    /// from the end, which its 44-point target leaves 11.75 points from it.
    /// The glass and the clear button are white at 60%, a quarter point
    /// above the row's middle.
    static let padSearchFieldHeight = 61.0
    static let padSearchFieldIconSize = 24.0
    static let padSearchFieldIconInset = 17.5
    static let padSearchFieldIconRaise = 0.25
    static let padSearchFieldTextInset = 57.0
    static let padSearchFieldFontSize = 26.0
    static let padSearchFieldPlaceholderOpacity = 0.2
    static let padSearchFieldClearSize = 22.0
    static let padSearchFieldClearButtonInset = 11.75
    static let padSearchFieldSymbolOpacity = 0.6
    static let padSearchFieldSeparatorOpacity = 0.2
    /// What the panel shows, laid out as on iPhone but for these: sections
    /// 22 points from the panel's sides, and apps on panels with nothing
    /// behind them, 22 points around their icons and 26 under the last row,
    /// the rows 22 points apart, with 17 points under each icon for its
    /// name. A header after such a panel comes 9 points closer to it than on
    /// iPhone, from where the panel ends.
    static let padSearchMargin = 22.0
    /// Its icons are 64 points across, as on iPhone, smaller than the iPad
    /// Home Screen's.
    static let padSearchIconSize = 64.0
    static let padSearchPanelPadding = 22.0
    static let padSearchPanelBottomPadding = 26.0
    static let padSearchPanelRowSpacing = 22.0
    static let padSearchCellLabelRoom = 17.0
    static let padSearchPanelSectionSpacing = -9.0

    // MARK: Folders

    /// How big a folder icon's small icons are, and the space between them:
    /// 13 and 3 points on an iPhone, whatever the size of its icons, as iOS
    /// draws them, and in proportion on an iPad's bigger icons.
    static func folderMini(iconSize: Double) -> (size: Double, gap: Double) {
        let scale = max(iconSize / 68, 1)
        return (13 * scale, 3 * scale)
    }
    /// An open folder's panel's corner radius, as a share of an icon: 40
    /// points with 64 point icons, as iOS draws it.
    static let folderCornerRatio = 40.0 / 64.0
    /// The room an open folder's panel keeps under its last row for page
    /// dots, which makes it 12 points taller than the space around its icons
    /// alone, as on iOS, whether the dots show or not.
    static let folderPageDotsRoom = 12.0
    /// An open folder's name: its size, how far its baseline sits above the
    /// panel, and how far large type's own spacing puts it before the first
    /// column, as iOS has it.
    static let folderTitleSize = 34.0
    static let folderTitleGap = 26.67
    static let folderTitleOverhang = 4.5
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
