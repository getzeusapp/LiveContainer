//
//  HomeEditControls.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The buttons edit mode shows where the status bar was, as iOS 26 does:
/// Edit at the top left, whose menu adds widgets, customizes and changes the
/// wallpaper, and Done at the top right, two glass capsules of the same size.
/// With a trackpad or mouse, they light up under the pointer. On iPad,
/// Return on a keyboard presses Done; an iPhone keeps Return doing nothing
/// here, as it always has.
struct HomeEditControls: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        let size = CGSize(width: metrics.editButtonWidth, height: metrics.editButtonSize)

        HStack {
            HomeEditMenu(size: size)
            Spacer()
            Button(action: model.endEditing) {
                HomeEditCapsule(title: "lc.common.done".loc, size: size)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(SharedModel.isPhone ? nil : .defaultAction)
        }
        .padding(.horizontal, metrics.editControlsInset)
        .frame(width: metrics.size.width)
        .position(x: metrics.size.width / 2, y: metrics.editControlsCenterY)
        // iPadOS's widget gallery covers them.
        .opacity(model.isAddingWidget && !SharedModel.isPhone ? 0 : 1)
    }
}
