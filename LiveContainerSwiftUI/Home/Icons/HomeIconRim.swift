//
//  HomeIconRim.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The faint light rim iOS 26 draws just inside the edge of every Home Screen
/// icon, which keeps a dark icon's edge in sight on a dark wallpaper. Like
/// iOS's, it lightens what's under it by the same amount whatever its color:
/// by about 18 of 255 at the edge, fading out over the first point.
struct HomeIconRim: ViewModifier {
    /// The icon's corner radius.
    let cornerRadius: Double

    func body(content: Content) -> some View {
        content.overlay {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(HomeDesign.iconRimOpacity), lineWidth: HomeDesign.iconRimWidth)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(HomeDesign.iconRimOpacity), lineWidth: HomeDesign.iconRimWidth / 2)
            }
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

extension View {
    /// Draws iOS's light rim inside the edge of an icon with this corner radius.
    func homeIconRim(cornerRadius: Double) -> some View {
        modifier(HomeIconRim(cornerRadius: cornerRadius))
    }
}
