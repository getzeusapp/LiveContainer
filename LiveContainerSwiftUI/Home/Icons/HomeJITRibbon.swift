//
//  HomeJITRibbon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The sash across the top-right corner of an app that always opens with
/// JIT, like the ribbon iOS once put across a newly installed app's icon. It
/// runs past the icon, so the icon's shape cuts its ends.
struct HomeJITRibbon: View {
    /// The icon's size, which the sash scales with.
    let iconSize: Double

    var body: some View {
        Text("JIT")
            .font(.system(size: iconSize * 0.15, weight: .heavy))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 0.5, y: 0.5)
            .frame(width: iconSize * 0.9, height: iconSize * 0.19)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.35, green: 0.62, blue: 1.0), Color(red: 0.05, green: 0.36, blue: 0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
            .rotationEffect(.degrees(45))
            .position(x: iconSize * 0.78, y: iconSize * 0.22)
            .frame(width: iconSize, height: iconSize)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
