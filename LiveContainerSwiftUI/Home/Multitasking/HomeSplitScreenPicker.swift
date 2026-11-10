//
//  HomeSplitScreenPicker.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The second half of an iPhone's split screen while it waits for its app:
/// the apps that can open there, in the Home Screen's order, on a panel
/// shaped like the app it waits for, over the black the split screen is
/// drawn on. The first app's window covers the first half. Picking an app
/// opens it beside the first; the close button ends the split screen, and
/// the first app fills the screen again.
struct HomeSplitScreenPicker: View {
    /// The whole screen's size.
    let size: CGSize
    /// Where the screen's safe area leaves room around the panel.
    let safeArea: EdgeInsets
    /// Where things go on this screen, for the icons' size.
    let metrics: HomeMetrics

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        let panel = Self.secondHalf(of: size)
        let candidates = model.splitScreenCandidates

        ZStack(alignment: .topLeading) {
            Color.black

            VStack(spacing: 0) {
                // While the app picked, or added from the dock, opens, only
                // that it's on its way.
                if model.isOpeningSplitApp {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    header
                    if candidates.isEmpty {
                        Text("zc.splitScreen.noApps".loc)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Self.margin)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        grid(of: candidates, panel: panel)
                    }
                }
            }
            .padding(.leading, max(safeArea.leading - panel.minX, 0))
            .padding(.trailing, max(panel.maxX - (size.width - safeArea.trailing), 0))
            .padding(.top, max(safeArea.top - panel.minY, 0))
            .frame(width: panel.width, height: panel.height, alignment: .top)
            .background(Color(uiColor: .secondarySystemBackground))
            // Rounded toward the first half, as the app it waits for will be.
            // The outer corners run off the screen, which rounds them itself.
            .clipShape(Self.panelShape(stacksVertically: Self.stacksVertically(size)))
            .offset(x: panel.minX, y: panel.minY)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        .frame(width: size.width, height: size.height)
    }

    /// The title, centered, with the close button on the leading side, as
    /// iOS 26's sheets have it, clear of the multitask dock's tab, which
    /// rests at the trailing edge where the halves meet.
    private var header: some View {
        ZStack {
            Text("zc.splitScreen.chooseApp".loc)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 44)
            HStack {
                closeButton
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Self.margin)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var closeButton: some View {
        Button(action: model.cancelSplitScreenPicker) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(.quaternary, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("lc.common.cancel".loc)
    }

    private func grid(of candidates: [LCAppModel], panel: CGRect) -> some View {
        ScrollView {
            HomeAppPickerGrid(apps: candidates, metrics: metrics, onPick: model.openBesideSplitApp)
                .padding(.horizontal, 8)
            .padding(.bottom, max(panel.maxY - (size.height - safeArea.bottom), 0) + 12)
        }
        .scrollIndicators(.hidden)
        .disabled(model.isOpeningSplitApp)
    }

    /// The side margin of the panel's title and close button.
    private static let margin = 20.0

    /// The gap between the two halves, where the divider goes. As in
    /// LCWindowSnapManager.
    private static let gap = 10.0

    /// Whether the halves are stacked top and bottom, as in portrait.
    private static func stacksVertically(_ size: CGSize) -> Bool {
        size.height >= size.width
    }

    /// The split screen's second half when it starts, even: as
    /// LCWindowSnapManager places it on iPhone, below the middle of the
    /// screen and the divider's gap, or right of them in landscape.
    static func secondHalf(of size: CGSize) -> CGRect {
        if stacksVertically(size) {
            let start = (size.height * 0.5).rounded() + gap / 2
            return CGRect(x: 0, y: start, width: size.width, height: size.height - start)
        }
        let start = (size.width * 0.5).rounded() + gap / 2
        return CGRect(x: start, y: 0, width: size.width - start, height: size.height)
    }

    /// The panel's shape: rounded at the corners facing the first half.
    private static func panelShape(stacksVertically: Bool) -> UnevenRoundedRectangle {
        let radius = LCPhoneSplitCornerRadius
        return stacksVertically
            ? UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius, style: .continuous)
            : UnevenRoundedRectangle(topLeadingRadius: radius, bottomLeadingRadius: radius, style: .continuous)
    }
}
