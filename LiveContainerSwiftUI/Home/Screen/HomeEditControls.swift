//
//  HomeEditControls.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The buttons edit mode shows where the status bar was: add an app at the
/// top left, Done at the top right. On iPhone they're two glass capsules of
/// the same size, Done as a checkmark, as iOS 27 draws them; on iPad, a round
/// add button and Done in words. With a trackpad or mouse, they light up
/// under the pointer. On iPad, Return on a keyboard presses Done; an iPhone
/// keeps Return doing nothing here, as it always has.
struct HomeEditControls: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        HStack {
            HomeAddAppMenu(size: metrics.editButtonSize)
            Spacer()
            Button(action: model.endEditing) {
                doneLabel
                    .foregroundStyle(.white)
                    .homeGlass(.capsule, isInteractive: true)
                    .contentShape(.hoverEffect, .capsule)
                    .hoverEffect(.highlight)
                    .frame(minHeight: HomeDesign.minimumTouchSize)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(SharedModel.isPhone ? nil : .defaultAction)
        }
        .padding(.horizontal, metrics.editControlsInset)
        .frame(width: metrics.size.width)
        .position(x: metrics.size.width / 2, y: metrics.editControlsCenterY)
    }

    /// A checkmark in a capsule as wide as the add button's on iPhone, and
    /// Done in words on iPad.
    @ViewBuilder
    private var doneLabel: some View {
        if SharedModel.isPhone {
            Label("lc.common.done".loc, systemImage: "checkmark")
                .labelStyle(.iconOnly)
                .font(.system(size: HomeDesign.editCapsuleGlyphSize, weight: .bold))
                .frame(width: HomeDesign.editCapsuleWidth, height: metrics.editButtonSize)
        } else {
            Text("lc.common.done".loc)
                .font(.headline)
                .padding(.horizontal, HomeDesign.editButtonPadding)
                .frame(minHeight: metrics.editButtonSize)
        }
    }
}
