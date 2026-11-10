//
//  OnboardingDesign.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The look and timing of onboarding in one place, matched to Zeus's own
/// onboarding. Sizes are in points at the default text size; the views scale
/// the ones that sit beside text with Dynamic Type.
enum OnboardingDesign {
    // MARK: Colors

    /// zContainer's accent, Zeus's pink, which tints onboarding the way it
    /// tints Zeus.
    static let accent = AppAccent.color
    /// The pink gradient behind the apps on zContainer's icon, from its top
    /// left corner to its bottom right, as `Scripts/zc/art/AppIcon.svg` has it.
    static let markGradientStart = Color(red: 0xE6 / 255, green: 0x4B / 255, blue: 0xAE / 255)
    static let markGradientEnd = Color(red: 0xA3 / 255, green: 0x15 / 255, blue: 0x6F / 255)
    /// The page behind onboarding: the grouped background of its forms, so
    /// the welcome screen and the steps share one color. SwiftUI has no
    /// grouped background color of its own.
    static let background = Color(uiColor: .systemGroupedBackground)

    // MARK: Layout

    /// The widest onboarding's content and buttons get, so lines stay easy to
    /// read on iPad and on wide windows.
    static let contentWidth = 540.0
    /// Space either side of the footer's buttons.
    static let pageMargin = 20.0
    /// Space above and below the footer's buttons.
    static let footerPadding = 12.0
    /// Space between the footer's buttons.
    static let footerSpacing = 4.0
    /// Space under a note above the footer's main button.
    static let noteSpacing = 12.0
    /// The smallest a button can be to tap, across and down.
    static let minimumTapTarget = 44.0
    /// Space either side of a plain button's title, inside its tap area.
    static let plainButtonPadding = 16.0

    // MARK: The welcome screen

    /// Space above zContainer's icon.
    static let welcomeTopPadding = 40.0
    /// Space under the features, above the footer.
    static let welcomeBottomPadding = 32.0
    /// Space either side of the features: wider than a page's margins, as on
    /// the welcome screens of Apple's own apps.
    static let welcomeMargin = 32.0
    /// Space between the title and the features.
    static let welcomeSpacing = 44.0
    /// Space between the features.
    static let featureSpacing = 26.0

    // MARK: Headers and rows

    /// Space between a header's symbol and its title.
    static let headerSpacing = 20.0
    /// Space between a header's title and its explanation.
    static let titleSpacing = 10.0
    /// The symbol at the top of a step.
    static let headerSymbolSize = 72.0
    /// How much of a header's tile its symbol takes up, across and down.
    static let headerGlyphRatio = 0.5
    /// Space between a row's icon and its text.
    static let rowSpacing = 14.0
    /// Space between a row's title and the line under it.
    static let rowTextSpacing = 2.0
    /// Extra space above and below a checklist row.
    static let rowPadding = 4.0

    // MARK: Icons

    /// zContainer's icon on the welcome screen and at the end.
    static let markSize = 100.0
    /// The corner radius of a tile or an icon, as a fraction of its size: the
    /// shape of an app icon.
    static let iconCornerRatio = 0.225
    /// The hairline around zContainer's icon, which keeps its edge crisp on a
    /// page of any color.
    static let markOutlineWidth = 1.0
    /// The squircle icons beside the features and the rows of a checklist.
    static let iconSize = 44.0
    /// How much of a squircle icon its glyph takes up, across and down.
    static let glyphRatio = 0.46
    /// How thick a squircle icon's outline is, for its size.
    static let iconStrokeRatio = 0.055
    /// How strongly a squircle icon is filled until its step is done.
    static let iconFillOpacity = 0.15
    /// The check that pops onto zContainer's icon at the end, the ring of
    /// page color that cuts it out of the icon, and how far it hangs over the
    /// icon's corner.
    static let badgeSize = 34.0
    static let badgeRing = 4.0
    static let badgeOffset = 8.0

    // MARK: Motion

    /// The spring most changes settle with.
    static let spring = Animation.spring(duration: 0.35)
    /// The bouncy spring the check pops onto the icon with.
    static let pop = Animation.spring(duration: 0.5, bounce: 0.45)
    /// How long the check waits before popping onto the icon, so the page
    /// has finished sliding in first.
    static let badgeDelay = 0.3

    /// How long the welcome screen waits before its words come in, so the
    /// icon's outline is drawing by then, and how long each part waits after
    /// the one above it.
    static let revealDelay = 0.9
    static let revealStagger = 0.08
    /// How far each part rises as it comes in, and how soft it starts.
    static let revealOffset = 12.0
    static let revealBlur = 8.0
    /// The gentle spring each part settles in with.
    static let revealSpring = Animation.spring(duration: 0.6, bounce: 0.12)

    /// How zContainer's icon arrives on the welcome screen: its pink tile
    /// swells in after a beat, then its sixteen apps pop onto it one diagonal
    /// at a time from the top left, `markAppStagger` seconds apart.
    static let markTileArrival = Animation.spring(duration: 0.5, bounce: 0.2).delay(0.25)
    static let markAppArrival = Animation.spring(duration: 0.45, bounce: 0.35)
    static let markAppStagger = 0.05
    /// How the icon comes in with Reduce Motion on: it only fades.
    static let markFade = Animation.easeOut(duration: 0.35)

    /// How onboarding fades in over the Home Screen when Settings opens it.
    static let coverFade = Animation.easeInOut(duration: 0.35)
    /// How the Home Screen comes in at the end: onboarding fades away while
    /// the icons settle from a little closer, as they do after unlocking.
    static let homeArrival = Animation.spring(duration: 0.7, bounce: 0.08)
    /// How much closer the Home Screen starts.
    static let homeArrivalScale = 1.08
}
