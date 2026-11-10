//
//  HomeLiftedWidgetCopy.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The dragged widget as it follows the finger: the widget as it showed where
/// it was picked up, risen a little with its shadow under it, as iOS lifts a
/// widget, and back down once dropped.
struct HomeLiftedWidgetCopy: View {
    let widget: HomeWidget
    /// The widget's size on screen.
    let size: CGSize
    /// Where things go on this screen.
    let metrics: HomeMetrics

    @Environment(HomeScreenModel.self) private var model
    @State private var isRaised = false
    @State private var shownKind: HomeWidgetKind?

    var body: some View {
        let isUp = isRaised && !model.isDropping

        HomeWidgetView(widget: widget, size: size, cornerRadius: metrics.widgetCornerRadius, shownKind: $shownKind, contentScale: metrics.widgetContentScale)
            .scaleEffect(isUp ? HomeDesign.liftedWidgetScale : 1)
            .shadow(
                color: .black.opacity(isUp ? HomeDesign.liftedShadowOpacity : 0),
                radius: HomeDesign.liftedShadowRadius,
                y: HomeDesign.liftedShadowOffset
            )
            .onAppear {
                withAnimation(HomeDesign.reflow) {
                    isRaised = true
                }
            }
    }
}
