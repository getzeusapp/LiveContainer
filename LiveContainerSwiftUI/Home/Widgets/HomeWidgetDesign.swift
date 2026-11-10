//
//  HomeWidgetDesign.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UIKit

/// A widget's background, as iOS 26.5 draws it: white in Light, and in Dark a
/// gray that's lighter at the top, from (52, 52, 54) to (28, 28, 30) three
/// quarters of the way down, measured from the iPad's widgets.
struct HomeWidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            LinearGradient(
                stops: [
                    .init(color: Self.gray(52), location: 0),
                    .init(color: Self.gray(43), location: 0.25),
                    .init(color: Self.gray(31), location: 0.5),
                    .init(color: Self.gray(28), location: 0.75),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            Color.white
        }
    }

    /// A gray of `level` out of 255, a touch bluer, as iOS's dark grays are.
    private static func gray(_ level: Double) -> Color {
        Color(red: level / 255, green: level / 255, blue: (level + 2) / 255)
    }
}

/// The light along a widget's left and right edges, as iOS 26.5 draws one
/// on every widget: a hairline of white at the very edge, and a fainter one
/// inside it, fading out where the edges round into the corners, and none
/// along the top and bottom.
struct HomeWidgetRim: View {
    let size: CGSize
    let cornerRadius: Double

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark = colorScheme == .dark

        ZStack {
            shape
                .strokeBorder(sides, lineWidth: HomeWidgetDesign.rimLine)
                .opacity(isDark ? 0.58 : 0.85)
            shape
                .inset(by: HomeWidgetDesign.rimLine)
                .strokeBorder(sides, lineWidth: HomeWidgetDesign.rimLine)
                .opacity(isDark ? 0.33 : 0.25)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// White at the left and right edges, clear before the corners round off.
    private var sides: LinearGradient {
        let fade = min(cornerRadius * 0.3 / max(size.width, 1), 0.5)
        return LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white.opacity(0), location: fade),
                .init(color: .white.opacity(0), location: 1 - fade),
                .init(color: .white, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// The look of the Home Screen's widgets in one place, matched to iOS 26.5's
/// own. Sizes are in points for the iPhone 17 Pro's 164.33 point small
/// widgets; a widget scales them with its size.
enum HomeWidgetDesign {
    /// The side of the small widget the sizes are measured for.
    static let referenceSide = 164.33
    /// The side iPadOS lays a small widget out at before making it the size
    /// of its places: the iPad's widgets show the same text as an iPhone's
    /// about 0.92 times as big, measured with the large Reminders widget on
    /// an iPad Air 11-inch and an iPhone 17 Pro.
    static let padLayoutSide = 148.0

    /// A widget's background: white in Light, and in Dark the gray iOS's
    /// widgets have, a step up from black.
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1)
            : .white
    })

    /// The space between a widget's edges and what it shows.
    static let contentInset = 18.0

    /// The gray bars News draws where stories go while it has none.
    static let placeholder = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 79 / 255, green: 79 / 255, blue: 81 / 255, alpha: 1)
            : UIColor(red: 229 / 255, green: 229 / 255, blue: 234 / 255, alpha: 1)
    })

    /// What a Maps widget shows until its map is drawn: the color of land.
    static let mapPlaceholder = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.17, green: 0.18, blue: 0.19, alpha: 1)
            : UIColor(red: 0.93, green: 0.92, blue: 0.88, alpha: 1)
    })

    /// The line across News' and Reminders' larger widgets.
    static let divider = Color(uiColor: .opaqueSeparator)

    /// How much less than an icon a widget tilts in edit mode, as SpringBoard
    /// tilts it: one over its longer side in app icons' places on iOS's grid,
    /// which is two for a small widget and four for the others, on iPhone
    /// and iPad alike.
    static func jiggleStrength(_ size: HomeWidgetSize) -> Double {
        switch size {
        case .small:
            0.5
        case .medium, .large:
            0.25
        }
    }

    /// The minus badge's center from a widget's top left corner, inside the
    /// rounder corner than an icon's, as SpringBoard places it.
    static let minusBadgeInset = 6.3

    /// The resize handle on a widget's bottom right corner in edit mode, from
    /// iOS 26.5's SBHIconResizingSettings: the line's width, the radius of
    /// the quarter circle it follows, and how far inside the widget's edges
    /// that circle's ends are.
    static let resizeHandleLineWidth = 13.0
    static let resizeHandleArcRadius = 18.0
    static let resizeHandleInset = 1.0
    /// How far past the corner's square the handle takes touches, on each side.
    static let resizeHandleHitOutset = 15.0
    /// The handle while a finger is on it: bigger, brighter and, in Dark
    /// Mode, more colorful, getting there quickly and springing back when
    /// let go.
    static let resizeHandlePressedScale = 1.2
    static let resizeHandleHighlightBrightness = 0.1
    static let resizeHandleHighlightSaturation = 1.6
    static let resizeHandlePress = Animation.spring(duration: 0.2, bounce: 0)
    static let resizeHandleRelease = Animation.spring(duration: 0.70316, bounce: 0.5)
    /// The handle hidden as edit mode starts and ends: a tenth of its size,
    /// shifted toward the corner by two ninths of its 36-point line length,
    /// and how it springs between that and showing.
    static let resizeHandleHiddenScale = 0.1
    static let resizeHandleHiddenShift = 8.0
    static let resizeHandleAppearance = Animation.spring(duration: 0.34071, bounce: 0.1)
    /// Resizing a widget by its handle, from iOS 26.5's
    /// SBWidgetIconResizeGestureHandler: how far the finger goes before the
    /// widget heads for another size; how far past the corners' shape it can
    /// pull the corner, at most; how wide the band between two corners is,
    /// each side; and how far toward the next size the widget is when it
    /// starts to show it and when it takes it.
    static let resizeStretchDistance = 20.0
    static let resizeOvershootLimit = 20.0
    static let resizeBandHalfWidth = 10.0
    static let resizeDeparture = 0.03
    static let resizeArrival = 0.95
    /// How much a widget being resized blurs at most, as SpringBoard's
    /// backdrop blur over each size's content goes up to.
    static let resizeBlur = 15.0
    /// How the widget follows the finger, how the other icons make room, and
    /// how it settles at its size when let go, as SpringBoard springs them.
    static let resizeTracking = Animation.spring(response: 0.15, dampingFraction: 0.86)
    static let resizeReflow = Animation.spring(duration: 0.67, bounce: 0.15)
    static let resizeSettle = Animation.spring(response: 0.531, dampingFraction: 0.845)

    /// The width of each of the rim's two hairlines.
    static let rimLine = 0.5

    /// Your location on the Maps widget: the white ring and the blue dot in
    /// it.
    static let locationRing = 22.0
    static let locationDot = 15.0
    /// The shaded area of a roughly known location, as a share of the map's
    /// height.
    static let approximateAreaShare = 0.55

    /// The dots beside a stack that show which of its widgets is up.
    static let stackDotSize = 5.0
    static let stackDotSpacing = 4.0
    static let stackDotsInset = 6.0
}
