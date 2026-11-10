//
//  HomeGlass.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The glass behind the dock, the search pill and the Home Screen's buttons:
/// Liquid Glass on iOS 26 and later, and before that a dark fill with a light
/// rim, which is how the glass looks over a dark wallpaper. Glass that runs
/// to the screen's edges gets a hairline along its top instead of the rim.
struct HomeGlass: ViewModifier {
    /// The glass's outline.
    let shape: HomeGlassShape
    /// Whether the glass reacts to touches, as a button's does.
    var isInteractive = false
    /// Which glass it is.
    var style = HomeGlassStyle.regular

    @Environment(\.colorScheme) private var colorScheme
    @Environment(SystemAppearance.self) private var system: SystemAppearance?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), SharedModel.isLiquidGlassEnabled {
            if style == .dock {
                let isDark = system?.isDark ?? true
                content
                    // What the glass holds keeps the Home Screen's appearance.
                    .environment(\.colorScheme, colorScheme)
                    .glassEffect(clearGlass(isDark: isDark), in: shape.liquidGlassShape)
                    .environment(\.colorScheme, isDark ? .dark : .light)
            } else {
                content.glassEffect(isInteractive ? .regular.interactive() : .regular, in: shape.liquidGlassShape)
            }
        } else {
            content.background {
                shape.fallbackShape
                    .fill(HomeDesign.fallbackGlassFill)
                    .stroke(shape.hasFullRim ? AnyShapeStyle(HomeDesign.fallbackGlassRim) : AnyShapeStyle(.clear), lineWidth: 1)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(HomeDesign.fallbackGlassHairline)
                            .frame(height: shape.hasFullRim ? 0 : 1)
                    }
            }
        }
    }

    /// Clear glass, lit a little in Light Mode, as SpringBoard's dock is.
    @available(iOS 26.0, *)
    private func clearGlass(isDark: Bool) -> Glass {
        let glass: Glass = isDark ? .clear : .clear.tint(HomeDesign.lightModeClearGlassTint)
        return isInteractive ? glass.interactive() : glass
    }
}

/// The kinds of glass on the Home Screen.
enum HomeGlassStyle {
    /// The Home Screen's own glass, dark whatever the appearance, behind its
    /// buttons and search.
    case regular
    /// The clear glass of the dock and the search pill. As on iOS, it shows
    /// the wallpaper through it, follows Light and Dark Mode and is lit a
    /// little in Light Mode. Folders' glass is HomeFolderGlass.
    case dock
}

extension View {
    /// Puts the Home Screen's glass behind this view, in the given shape and style.
    func homeGlass(_ shape: HomeGlassShape, isInteractive: Bool = false, style: HomeGlassStyle = .regular) -> some View {
        modifier(HomeGlass(shape: shape, isInteractive: isInteractive, style: style))
    }
}
