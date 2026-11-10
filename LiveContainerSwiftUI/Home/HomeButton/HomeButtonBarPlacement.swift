//
//  HomeButtonBarPlacement.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Puts the Home button bar under a screen, on the grouped background
/// Settings pages use, and ends the screen above it, so nothing on any of its
/// pages goes under the button. Laid over the screen as a safe area bar, it
/// left Settings' pages running on under the button. On an iPad turned so its
/// Home button is beside the screen, or above it, the bar runs along that
/// edge instead. The screen keeps its place among the views whichever edge
/// it is, so turning the iPad doesn't start it over.
struct HomeButtonBarPlacement: ViewModifier {
    /// What pressing the button does.
    let action: () -> Void
    /// Whether the bar shows. It always does on iPhone. Settings on an iPad
    /// wide enough for its sidebar leaves it out while the iPad's Home button
    /// is below the screen, as it puts the Home button at the bottom of the
    /// sidebar instead.
    let isShown: Bool

    @Environment(\.homeButtonEdge) private var edge
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        // The left and right of the screen itself, whatever the reading
        // direction, which the screen keeps.
        HStack(spacing: 0) {
            if edge == .left {
                bar(isVertical: true)
            }
            VStack(spacing: 0) {
                if edge == .top {
                    bar(isVertical: false)
                }
                content
                if edge == .bottom {
                    bar(isVertical: false)
                }
            }
            .environment(\.layoutDirection, layoutDirection)
            if edge == .right {
                bar(isVertical: true)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func bar(isVertical: Bool) -> some View {
        if isShown {
            HomeButtonBar(action: action, isVertical: isVertical)
                .background {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                }
        }
    }
}

extension View {
    /// Shows the Home button centered along the bottom of this screen, or
    /// beside an iPad's Home button as it's turned. Apply it outside the
    /// screen's navigation stack, so every page shows it. `isShown` false
    /// leaves the bar out, for a screen that shows the button somewhere else.
    func homeButtonBar(isShown: Bool = true, action: @escaping () -> Void) -> some View {
        modifier(HomeButtonBarPlacement(action: action, isShown: isShown))
    }
}
