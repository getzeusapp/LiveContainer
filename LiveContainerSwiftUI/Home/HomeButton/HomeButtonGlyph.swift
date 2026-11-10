//
//  HomeButtonGlyph.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The rings on the Home button, drawn like AssistiveTouch's: white circles
/// stacked from a faint halo to a bright dot in the middle, or circles of
/// another color where the button sits on light glass.
struct HomeButtonGlyph: View {
    /// The circles' color.
    var color = Color.white

    var body: some View {
        ZStack {
            ForEach(HomeDesign.homeButtonRings, id: \.size) { ring in
                Circle()
                    .fill(color.opacity(ring.opacity))
                    .frame(width: ring.size, height: ring.size)
            }
        }
        .accessibilityHidden(true)
    }
}
