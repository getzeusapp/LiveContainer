//
//  HomeButtonEdge.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UIKit

/// The edge of the screen zContainer's Home button sits against. On an iPad
/// it's the edge a physical Home button is beside on the iPads that have
/// one, which turns with the iPad: below the screen in portrait, on the left
/// or the right in landscape, and above it upside down. On an iPhone it's
/// always the bottom.
enum HomeButtonEdge: Equatable {
    case bottom
    case top
    case left
    case right

    /// The edge beside the Home button of an iPad showing its screen in
    /// `orientation`, or the bottom on an iPhone. In landscape left, as
    /// UIKit names it, the Home button is on the left.
    init(_ orientation: UIInterfaceOrientation, isPhone: Bool = SharedModel.isPhone) {
        guard !isPhone else {
            self = .bottom
            return
        }
        switch orientation {
        case .landscapeLeft:
            self = .left
        case .landscapeRight:
            self = .right
        case .portraitUpsideDown:
            self = .top
        default:
            self = .bottom
        }
    }

    /// Whether the button stands at the left or right side of the screen.
    var isSide: Bool {
        self == .left || self == .right
    }
}

private struct HomeButtonEdgeKey: EnvironmentKey {
    static let defaultValue = HomeButtonEdge.bottom
}

extension EnvironmentValues {
    /// The edge zContainer's Home button sits against in this window.
    var homeButtonEdge: HomeButtonEdge {
        get { self[HomeButtonEdgeKey.self] }
        set { self[HomeButtonEdgeKey.self] = newValue }
    }
}
