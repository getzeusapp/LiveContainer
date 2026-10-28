//
//  HomeAppIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// An app's icon as the Home Screen shows it: the icon IconServices drew for
/// the Home Screen, without its mask and border, clipped to the icon shape
/// here, in its dark version when the icon style asks for it, with the app's
/// name under it. While the app is being signed, the icon dims
/// and fills with iOS's progress pie. An app that always opens with JIT
/// wears a JIT sash across its corner.
struct HomeAppIcon: View {
    @ObservedObject var app: LCAppModel
    /// Where things go on this screen, for the icon's size.
    let metrics: HomeMetrics
    /// Whether the name shows under the icon. Icons in the dock have none.
    let showsLabel: Bool
    /// Whether the icon shows in its dark version, as the icon style asks.
    let darkModeIcon: Bool
    /// Marks the icon as the place its settings zoom out of.
    let zoomSource: HomeZoomSource

    var body: some View {
        VStack(spacing: HomeDesign.labelSpacing) {
            // LCAppInfo keeps each icon in memory after drawing it once, and on
            // disk after the first launch, so it shows at once after the first
            // time. That first time it's drawn off the main thread.
            HomeAppIconImage(app: app, isDark: darkModeIcon)
                .frame(width: metrics.iconSize, height: metrics.iconSize)
                // Under the clip, so the icon's corner cuts the sash's ends.
                .overlay {
                    if app.uiIsJITNeeded || app.appInfo.is32bit {
                        HomeJITRibbon(iconSize: metrics.iconSize)
                    }
                }
                .clipShape(.rect(cornerRadius: metrics.iconCornerRadius))
                .overlay {
                    if app.isSigningInProgress {
                        HomeProgressPie(progress: app.signProgress, cornerRadius: metrics.iconCornerRadius)
                    }
                }
                .modifier(HomeIconPointerLift(cornerRadius: metrics.iconCornerRadius))
                .modifier(zoomSource)
                .accessibilityHidden(true)

            if showsLabel {
                HomeIconLabel(title: app.displayName)
            }
        }
    }
}
