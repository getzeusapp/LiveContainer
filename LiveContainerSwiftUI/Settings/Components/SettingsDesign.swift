//
//  SettingsDesign.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The look of zContainer's Settings in one place, matched to the Settings
/// app. Sizes are in points at the default text size; the views scale them
/// with Dynamic Type.
enum SettingsDesign {
    // MARK: Row icons

    /// The colored tile beside a row, and an app's icon in the Apps list: 29
    /// points, as in the Settings app.
    static let iconSize = 29.0
    /// The size of a tile's symbol, as a fraction of the tile. Symbols keep
    /// their own proportions at that size, as the Settings app's glyphs do:
    /// its gear comes out 21 points across on a 29 point tile.
    static let glyphRatio = 0.66
    /// The sheen at the top of a tile, as the Settings app shades them: the
    /// tile's color with this much white at its top edge, fading to the plain
    /// color this far down.
    static let iconSheen = 0.27
    static let iconSheenEnd = 0.57
    /// A tile's or an icon's corner radius, as a fraction of its size: the
    /// shape of an app icon.
    static let iconCornerRatio = 0.225
    /// The hairline around an app's icon, which keeps white icons apart from
    /// the white rows.
    static let iconOutlineWidth = 0.5
    /// The largest a row's logo grows with the text size, so a 180 pixel
    /// logo stays sharp on a 3x screen.
    static let largestLogoSize = 60.0

    // MARK: A page's header

    /// The icon in the card at the top of a page, as big as the Settings app's
    /// at the top of General.
    static let pageHeaderIconSize = 60.0
    /// Space under that icon, and under the page's name, which the iPad's
    /// Settings app leaves more of.
    static let pageHeaderIconSpacing = SharedModel.isPhone ? 15.0 : 20.0
    static let pageHeaderTitleSpacing = SharedModel.isPhone ? 4.0 : 8.0
    /// The space around the card's contents: at the sides, as much as a row's
    /// on iPhone and iPad.
    static let pageHeaderInsets = EdgeInsets(
        top: 15.67,
        leading: SharedModel.isPhone ? 16 : 20,
        bottom: 15.33,
        trailing: SharedModel.isPhone ? 16 : 20
    )

    // MARK: Pages drawn as UIKit draws them

    /// The margin at the sides of a page whose counterpart in the Settings
    /// app is drawn with UIKit, where UIKit can't be asked for its own.
    static let uiKitPageSideMargin = 16.0
    /// The space above such a page's first card: UIKit's half of the 35
    /// points between its sections, rounded to the pixel, where SwiftUI
    /// leaves all 35.
    static let uiKitPageTopMargin = 17.67
    /// How much lower UIKit puts a section's header under the card above it,
    /// and how much closer it puts the section's card under the header, than
    /// SwiftUI: on iPhone its header's baseline sits 45.67 points under the
    /// card above and 9.67 over its own card, where SwiftUI's sits 44 and
    /// 13.67, and on iPad 45.5 and 10, where SwiftUI's sits 43.5 and 14.5.
    /// On iPhone the first is a little under the difference, as SwiftUI
    /// rounds the header onto the pixel past the one UIKit uses.
    static let uiKitHeaderLowering = SharedModel.isPhone ? 1.5 : 2.0
    static let uiKitHeaderCardRaise = SharedModel.isPhone ? 4.0 : 4.5

    // MARK: App Theme

    /// The pictures of the Home Screen that Light and Dark show, as tall as
    /// the Settings app's in Display & Brightness. They're pictures, so they
    /// keep their size whatever the text size.
    static let themePreviewHeight = 150.0
    /// A picture's corner radius, as a fraction of its height: about a
    /// screen's own, a little rounder on iPad so it still reads as a screen
    /// at this size.
    static let themePreviewCornerFraction = SharedModel.isPhone ? 0.065 : 0.03
    /// The dark edge around a picture, which makes it a phone or an iPad.
    static let themePreviewBezel = 2.5
    /// A folder's small icons and the gaps between them, as fractions of the
    /// folder's width: 13 and 3 points on a 64 point folder.
    static let themePreviewFolderIconRatio = 13.0 / 64
    static let themePreviewFolderGapRatio = 3.0 / 64
    /// Space between a picture, its name and its check.
    static let themeChoiceSpacing = 10.0
    /// Space above and below the pictures.
    static let themeChoicesPadding = 8.0
    /// How long Automatic's switch takes to settle after a tap, before the
    /// theme changes under it.
    static let themeSwitchSettling = Duration.milliseconds(300)

    // MARK: The Zeus card

    /// The Zeus mark in the card at the top of Settings, as big as the Apple
    /// Account's picture is in the Settings app.
    static let cardMarkSize = 60.0
    /// The Zeus mark at the top of the Zeus page.
    static let headerMarkSize = 64.0
    /// How much of the Zeus mark's tile the bolt takes up, top to bottom: 640
    /// of the 1024 points on Zeus's app icon.
    static let boltRatio = 0.625
    /// The tile behind the bolt, as on Zeus's app icon: the pink zContainer's
    /// own icon has too, fading from the top left corner to the bottom right.
    static let zeusTile = LinearGradient(
        colors: [OnboardingDesign.markGradientStart, OnboardingDesign.markGradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Space between the mark and the text beside it, as between the Apple
    /// Account's picture and its name.
    static let cardSpacing = 8.0
    /// Space between a title and the line under it.
    static let subtitleSpacing = 2.0
    /// Space between the parts of the Zeus page's header.
    static let headerSpacing = 8.0

    // MARK: Add to Home Screen

    /// The icon at the top of Add to Home Screen's sheet, as big as Safari's
    /// Add to Home Screen shows a web page's.
    static let shortcutIconSize = 60.0
    /// Space between that icon and its name.
    static let shortcutSpacing = 14.0

    // MARK: Search

    /// How small the Home button's rings are drawn in the bottom bar beside
    /// the search field, where the button is a toolbar button's size.
    static let toolbarHomeGlyphScale = 0.55
    /// The room the rings take in that button.
    static let toolbarHomeGlyphSize = 24.0

    // MARK: Badges and checks

    /// The height of the red badge on a row that needs attention, which fits
    /// a row without making it taller than the Settings app's, 52 points.
    static let badgeSize = 22.0
    /// The space at each end of a badge's number, as a fraction of its height.
    static let badgePaddingRatio = 0.3
}
