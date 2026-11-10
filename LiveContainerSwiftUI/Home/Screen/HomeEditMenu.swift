//
//  HomeEditMenu.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Edit, the glass capsule edit mode shows at the top left, as iOS's does,
/// and its menu: Add Widget, which opens the widget gallery, Customize, which
/// picks the app theme, and Edit Wallpaper, which chooses a photo, as on iOS;
/// then installing an app from an IPA in Files or from a link, through the
/// same install as everything else.
struct HomeEditMenu: View {
    /// The capsule's size, which HomeMetrics picks for the screen.
    let size: CGSize

    @Environment(HomeScreenModel.self) private var model
    @Environment(AppLaunchCoordinator.self) private var coordinator
    @State private var isChoosingWallpaper = false

    var body: some View {
        Menu {
            Section {
                Button("zc.home.addWidget".loc, systemImage: "widget.small.badge.plus", action: addWidget)
                Button("zc.home.customize".loc, systemImage: "paintbrush", action: customize)
                Button("zc.home.editWallpaper".loc, systemImage: "camera.macro", action: chooseWallpaper)
            }
            Section {
                Button("lc.appList.installFromIpa".loc, systemImage: "doc.badge.plus", action: model.chooseIPA)
                    .disabled(coordinator.isInstalling)
                Button("lc.appList.installFromUrl".loc, systemImage: "link.badge.plus", action: model.askForInstallURL)
                    .disabled(coordinator.isInstalling)
            }
        } label: {
            HomeEditCapsule(title: "zc.home.edit".loc, size: size)
        }
        // Its items' symbols white, as iOS's are, not in the accent.
        .tint(.primary)
        .wallpaperPicker(isPresented: $isChoosingWallpaper)
    }

    private func addWidget() {
        model.isAddingWidget = true
    }

    private func customize() {
        model.isCustomizing = true
    }

    private func chooseWallpaper() {
        isChoosingWallpaper = true
    }
}

/// One of edit mode's glass capsules, Edit or Done, with its word in white,
/// as iOS draws them, at least `size` across, wider for a longer word. It
/// lights up under a trackpad or mouse pointer, and takes touches across the
/// least touch size.
struct HomeEditCapsule: View {
    let title: String
    let size: CGSize

    var body: some View {
        Text(title)
            .font(.system(size: HomeDesign.editCapsuleFontSize, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, HomeDesign.editCapsulePadding)
            .frame(minWidth: size.width, minHeight: size.height, maxHeight: size.height)
            .homeGlass(.capsule, isInteractive: true)
            .contentShape(.hoverEffect, .capsule)
            .hoverEffect(.highlight)
            .frame(minHeight: HomeDesign.minimumTouchSize)
            .contentShape(.rect)
    }
}
