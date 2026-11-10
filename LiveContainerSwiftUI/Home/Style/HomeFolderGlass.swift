//
//  HomeFolderGlass.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UIKit

/// The glass of a folder's icon, of the folder that forms behind an icon
/// about to take another in, and of an open folder's panel: clear Liquid
/// Glass that follows Light and Dark Mode on iOS 26 and later, as iOS draws
/// folders, and before that the Home Screen blurred under a thin dark
/// material, with a light rim.
///
/// On iOS 26 it's UIKit's glass, as SpringBoard's is, so it tilts as one
/// with an icon as it jiggles: SwiftUI's glass is drawn as the upright box
/// around a tilted shape, so it grows and shrinks as the icon tilts.
struct HomeFolderGlass: ViewModifier {
    /// The glass's corner radius: an app icon's, or the open panel's.
    let cornerRadius: Double

    @Environment(SystemAppearance.self) private var system: SystemAppearance?

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), SharedModel.isLiquidGlassEnabled {
            content.background {
                HomeFolderGlassView(cornerRadius: cornerRadius, isDark: system?.isDark ?? true)
            }
        } else {
            content
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(HomeDesign.folderGlassRim, lineWidth: HomeDesign.folderGlassRimWidth)
                }
        }
    }
}

/// Clear Liquid Glass with round corners, in the Home Screen's appearance.
/// Its corners round off smoothly as they change, as when the open folder's
/// panel zooms out of its icon.
@available(iOS 26.0, *)
private struct HomeFolderGlassView: UIViewRepresentable, Animatable {
    var cornerRadius: Double
    /// Whether the Home Screen is in Dark Mode, which the glass follows.
    let isDark: Bool

    var animatableData: Double {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIGlassEffect(style: .clear))
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        view.cornerConfiguration = .corners(radius: .fixed(cornerRadius))
        view.overrideUserInterfaceStyle = isDark ? .dark : .light
    }
}

extension View {
    /// Puts a folder's glass behind this view.
    func homeFolderGlass(cornerRadius: Double) -> some View {
        modifier(HomeFolderGlass(cornerRadius: cornerRadius))
    }
}
