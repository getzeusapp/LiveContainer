//
//  HomeAddAppMenu.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The add button edit mode shows at the top left: a glass capsule on
/// iPhone, as wide as Done's, and round on iPad. It installs an app from an
/// IPA in Files or from a link, through the same install as everything else,
/// and chooses a photo for the wallpaper.
struct HomeAddAppMenu: View {
    /// The button's height, and its width on iPad, which HomeMetrics picks
    /// for the screen.
    let size: Double

    @Environment(HomeScreenModel.self) private var model
    @Environment(AppLaunchCoordinator.self) private var coordinator
    @State private var isChoosingWallpaper = false

    var body: some View {
        Menu {
            Section {
                Button("lc.appList.installFromIpa".loc, systemImage: "doc.badge.plus", action: model.chooseIPA)
                    .disabled(coordinator.isInstalling)
                Button("lc.appList.installFromUrl".loc, systemImage: "link.badge.plus", action: model.askForInstallURL)
                    .disabled(coordinator.isInstalling)
            }
            Section {
                Button("zc.home.chooseWallpaper".loc, systemImage: "camera.macro", action: chooseWallpaper)
            }
        } label: {
            if SharedModel.isPhone {
                Label("zc.home.addApp".loc, systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(.system(size: HomeDesign.editCapsuleGlyphSize, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: HomeDesign.editCapsuleWidth, height: size)
                    .homeGlass(.capsule, isInteractive: true)
                    // Lights up under a trackpad or mouse pointer.
                    .contentShape(.hoverEffect, .capsule)
                    .hoverEffect(.highlight)
                    .frame(minHeight: HomeDesign.minimumTouchSize)
                    .contentShape(.rect)
            } else {
                Label("zc.home.addApp".loc, systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .homeGlass(.circle, isInteractive: true)
                    // Lights up under a trackpad or mouse pointer.
                    .contentShape(.hoverEffect, .circle)
                    .hoverEffect(.highlight)
                    .frame(width: HomeDesign.minimumTouchSize, height: HomeDesign.minimumTouchSize)
                    .contentShape(.circle)
            }
        }
        .wallpaperPicker(isPresented: $isChoosingWallpaper)
    }

    private func chooseWallpaper() {
        isChoosingWallpaper = true
    }
}
