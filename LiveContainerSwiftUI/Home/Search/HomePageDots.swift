//
//  HomePageDots.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One dot for each page, the one showing in white.
struct HomePageDots: View {
    /// How many pages there are.
    let count: Int
    /// The page showing, counting from 0.
    let current: Int
    /// A dot's size: the search pill's, or the larger dots iPhones with a
    /// Home button show on their own.
    var dotSize = HomeDesign.pageDotSize
    /// The space between dots.
    var spacing = HomeDesign.pageDotSpacing
    /// The dots' color, white unless they sit on something bright.
    var color = Color.white

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { page in
                Circle()
                    .fill(page == current ? color : color.opacity(HomeDesign.pageDotOtherOpacity))
                    .frame(width: dotSize, height: dotSize)
            }
        }
        .animation(HomeDesign.modeChange, value: current)
        .transition(.opacity)
        .accessibilityHidden(true)
    }
}
