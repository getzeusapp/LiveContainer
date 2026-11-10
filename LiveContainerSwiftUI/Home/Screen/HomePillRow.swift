//
//  HomePillRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The row above the dock. On the first page it holds the "Search" pill, as
/// on iOS. When there is more than one page, the page dots take it while the
/// pages move and in edit mode, and a finger dragged along it scrubs through
/// the pages. The dock fills the bottom of the screen, so the Home button
/// takes this row instead whenever pressing it would do something: on the
/// other pages, and in edit mode when there is only one page.
struct HomePillRow: View {
    /// How much the Home button shrinks to fit the row, 1 where it has room.
    let homeButtonScale: Double
    /// Whether the row shows the page dots on their own, as iPhones with a
    /// Home button do, rather than the search pill.
    let isBare: Bool
    /// Whether the wallpaper behind the row is bright.
    let isOnBrightBackdrop: Bool

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.homeButtonEdge) private var homeButtonEdge
    @GestureState private var isScrubbing = false

    var body: some View {
        // On an iPad turned so its Home button isn't below the screen, the
        // button stands beside the screen instead, as HomeEdgeButton.
        let content = model.pillContent(homeButtonInRow: homeButtonEdge == .bottom)

        ZStack {
            if content == .homeButton {
                HomeButton(action: model.goHome)
                    .scaleEffect(homeButtonScale)
                    .transition(transition)
            } else {
                HomeSearchPill(
                    pageCount: model.pageCount,
                    currentPage: model.page ?? 0,
                    showsPageDots: content == .pageDots,
                    isBare: isBare,
                    isOnBrightBackdrop: isOnBrightBackdrop,
                    action: model.openSearch
                )
                .transition(transition)
            }
        }
        .animation(HomeDesign.modeChange, value: content)
        // Over the pill and the Home button alike. A tap still reaches the
        // button underneath; once the finger moves, the scrub takes over.
        .highPriorityGesture(scrub, including: model.pageCount > 1 ? .all : .subviews)
        .onChange(of: isScrubbing, scrubbingChanged)
        .sensoryFeedback(.selection, trigger: model.page) { _, _ in
            isScrubbing
        }
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named(HomeDesign.coordinateSpace))
            .updating($isScrubbing) { _, isScrubbing, _ in
                isScrubbing = true
            }
            .onChanged(scrubChanged)
    }

    private func scrubChanged(_ value: DragGesture.Value) {
        model.scrubPages(atX: value.location.x)
    }

    /// Lets the dots go once the finger lifts, or the scrub is cancelled.
    private func scrubbingChanged(from wasScrubbing: Bool, to isScrubbing: Bool) {
        if wasScrubbing && !isScrubbing {
            model.scrubEnded()
        }
    }

    /// The button and the pill grow out of each other, or only fade with
    /// Reduce Motion on.
    private var transition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.8))
    }
}
