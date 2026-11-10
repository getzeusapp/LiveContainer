//
//  HomeEdgeButton.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Home Screen's Home button on an iPad turned so its Home button isn't
/// below the screen: against the edge the iPad's Home button is beside,
/// halfway along a side in landscape, or at the top, in line with edit mode's
/// buttons, upside down. Like the button in the row above the dock, which it
/// takes the place of, it shows when pressing it would do something.
struct HomeEdgeButton: View {
    /// The edge it stands against.
    let edge: HomeButtonEdge
    /// Where things go on this screen.
    let metrics: HomeMetrics

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isShown = model.homeButtonDoesSomething

        ZStack {
            if isShown {
                HomeButton(action: model.goHome)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(HomeDesign.modeChange, value: isShown)
        .position(center)
    }

    /// The button's center: as far from its edge as the bars on other
    /// screens keep it.
    private var center: CGPoint {
        let reach = HomeDesign.homeButtonBarPadding + HomeDesign.homeButtonSize / 2
        switch edge {
        case .left:
            return CGPoint(x: reach, y: metrics.size.height / 2)
        case .right:
            return CGPoint(x: metrics.size.width - reach, y: metrics.size.height / 2)
        case .top:
            return CGPoint(x: metrics.size.width / 2, y: metrics.editControlsCenterY)
        case .bottom:
            return metrics.pillCenter
        }
    }
}
