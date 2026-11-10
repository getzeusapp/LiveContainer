//
//  HomeWallpaperImage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What the Home Screen shows behind everything: its wallpaper filling the
/// screen, on black until it has loaded. While Dark Mode is on a photo is
/// dimmed, unless that's turned off. As search comes in on iPhone, the
/// blurred copy fades in over it.
struct HomeWallpaperImage: View {
    @Environment(WallpaperStore.self) private var wallpaper
    @Environment(SystemAppearance.self) private var system
    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        let isDimmed = wallpaper.isCustom && wallpaper.dimsInDarkMode && system.isDark

        Color.black
            .overlay {
                if let image = wallpaper.image {
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()

                        if let blurred = wallpaper.blurredImage {
                            Image(uiImage: blurred)
                                .resizable()
                                .scaledToFill()
                                .opacity(model.searchBackdropPresence)
                        }

                        Color.black
                            .opacity(isDimmed ? HomeDesign.wallpaperDimming : 0)
                    }
                    .transition(.opacity)
                }
            }
            .clipped()
            .animation(HomeDesign.modeChange, value: wallpaper.image)
            .animation(HomeDesign.modeChange, value: model.isSearching)
            .animation(HomeDesign.modeChange, value: isDimmed)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
