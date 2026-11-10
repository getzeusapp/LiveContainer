//
//  HomeGlassShape.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The outlines the Home Screen's glass comes in.
enum HomeGlassShape {
    /// A capsule, for the search pill and the edit mode buttons.
    case capsule
    /// A circle, for round buttons.
    case circle
    /// A rounded rectangle with a fixed corner radius, with continuous
    /// corners, as the floating dock's are.
    case rounded(Double)
    /// A rectangle that runs to the screen's sides and bottom edge, for the
    /// dock on iPhones with a Home button.
    case edgeToEdge

    /// The outline Liquid Glass takes.
    @available(iOS 26.0, *)
    var liquidGlassShape: AnyShape {
        switch self {
        case .capsule:
            AnyShape(.capsule)
        case .circle:
            AnyShape(.circle)
        case .rounded(let radius):
            AnyShape(.rect(cornerRadius: radius, style: .continuous))
        case .edgeToEdge:
            AnyShape(.rect)
        }
    }

    /// Whether the glass's light rim runs all the way around it before iOS 26.
    /// Glass that runs to the screen's edges has only a hairline along its top.
    var hasFullRim: Bool {
        if case .edgeToEdge = self {
            false
        } else {
            true
        }
    }

    /// The outline before iOS 26.
    var fallbackShape: AnyShape {
        switch self {
        case .capsule:
            AnyShape(.capsule)
        case .circle:
            AnyShape(.circle)
        case .rounded(let radius):
            AnyShape(.rect(cornerRadius: radius, style: .continuous))
        case .edgeToEdge:
            AnyShape(.rect)
        }
    }
}
