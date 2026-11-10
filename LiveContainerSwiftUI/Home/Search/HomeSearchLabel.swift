//
//  HomeSearchLabel.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// "Search" with a magnifying glass, as the search pill shows it.
struct HomeSearchLabel: View {
    /// The text's and the glass's color.
    var color = HomeDesign.pillTextColor

    var body: some View {
        HStack(spacing: HomeDesign.pillSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: HomeDesign.pillGlyphSize, weight: .semibold))
                // Level with the text's ink, top and bottom, as on iOS.
                .offset(y: -HomeDesign.pillContentRaise)
            Text("zc.home.search".loc)
                .font(.system(size: HomeDesign.pillFontSize, weight: .medium))
        }
        // iOS sets the ink a hair above the pill's middle.
        .offset(y: -HomeDesign.pillContentRaise)
        .foregroundStyle(color)
        .transition(.opacity)
    }
}
