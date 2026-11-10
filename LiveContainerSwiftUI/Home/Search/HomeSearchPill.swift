//
//  HomeSearchPill.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The small "Search" pill above the dock, which opens search. While the
/// pages move, and in edit mode, it shows the page dots instead, as on iOS.
struct HomeSearchPill: View {
    /// How many pages there are.
    let pageCount: Int
    /// The page showing, counting from 0.
    let currentPage: Int
    /// Whether the dots show in place of "Search".
    let showsPageDots: Bool
    /// Whether only the page dots show, on no glass, as on iPad and iPhones
    /// with a Home button, whose Home Screens have no search pill.
    let isBare: Bool
    /// Whether the wallpaper behind is bright, where the text and dots turn
    /// dark, as iOS does, to stay readable.
    let isOnBrightBackdrop: Bool
    /// Opens search.
    let action: () -> Void

    /// The text's and the dots' color.
    private var contentColor: Color {
        isOnBrightBackdrop ? HomeDesign.pillDarkTextColor : .white
    }

    var body: some View {
        if isBare {
            bareDots
        } else {
            pill
        }
    }

    /// The page dots alone, when there's more than one page, as iPad and
    /// iPhones with a Home button show them above the dock. Search opens by
    /// pulling the pages down.
    @ViewBuilder
    private var bareDots: some View {
        if pageCount > 1 {
            HomePageDots(count: pageCount, current: currentPage, dotSize: HomeDesign.bareDotSize, spacing: HomeDesign.bareDotSpacing, color: contentColor)
                .frame(height: HomeDesign.minimumTouchSize)
                .contentShape(.rect)
                .accessibilityElement()
                .accessibilityLabel("zc.home.pageIndicator %lld %lld".localizeWithFormat(currentPage + 1, pageCount))
        }
    }

    private var pill: some View {
        Button(action: action) {
            Group {
                if showsPageDots && pageCount > 1 {
                    HomePageDots(count: pageCount, current: currentPage, color: contentColor)
                } else {
                    HomeSearchLabel(color: isOnBrightBackdrop ? HomeDesign.pillDarkTextColor : HomeDesign.pillTextColor)
                }
            }
            .frame(height: HomeDesign.pillHeight)
            .padding(.horizontal, showsPageDots && pageCount > 1 ? HomeDesign.pageDotsPadding : HomeDesign.pillPadding)
            .homeGlass(.capsule, isInteractive: true, style: .dock)
            // Lights up under a trackpad or mouse pointer, which can't pull
            // the pages down to open search.
            .contentShape(.hoverEffect, .capsule)
            .hoverEffect(.highlight)
            // A taller touch area than the pill, which is only 30 points high.
            .padding(.vertical, (HomeDesign.minimumTouchSize - HomeDesign.pillHeight) / 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .animation(HomeDesign.modeChange, value: showsPageDots)
        .accessibilityLabel("zc.home.search".loc)
        .accessibilityValue("zc.home.pageIndicator %lld %lld".localizeWithFormat(currentPage + 1, pageCount))
    }
}
