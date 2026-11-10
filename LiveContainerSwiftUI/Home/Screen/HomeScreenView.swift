//
//  HomeScreenView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// zContainer's main screen: a Home Screen like the iPhone's, on the halo
/// wallpaper it comes with or a photo chosen for it, under the real status
/// bar. It shows the apps inside zContainer on
/// pages of icons with a dock, opens them with a tap, and opens Settings, an
/// app's settings and search over itself. It is the main window's root, so it
/// also runs HomeRouter's launch checks and links.
struct HomeScreenView: View {
    @Environment(HomeScreenModel.self) private var model
    @Environment(HomeRouter.self) private var router
    @Environment(AppLaunchCoordinator.self) private var coordinator
    @Environment(OnboardingModel.self) private var onboarding
    @Namespace private var zoomNamespace

    var body: some View {
        let presence = model.searchPresence

        ZStack {
            // The Home Screen is laid out from the screen's top left corner,
            // as on iOS. A reader that covers the whole screen reads its safe
            // area as empty, so the outer reader stays in the safe area and
            // the insets are where the whole screen sits around it.
            GeometryReader { safeArea in
                GeometryReader { screen in
                    HomeSpringboard(
                        metrics: HomeMetrics(
                            size: screen.size,
                            safeArea: Self.insets(of: safeArea.size, within: screen.frame(in: .named(Self.safeAreaSpace))),
                            isPhone: SharedModel.isPhone
                        ),
                        zoomNamespace: zoomNamespace
                    )
                }
                .ignoresSafeArea()
            }
            .coordinateSpace(.named(Self.safeAreaSpace))
            // Search's keyboard leaves the Home Screen where it is.
            .ignoresSafeArea(.keyboard)
            // Search covers the Home Screen for touches and for VoiceOver alike.
            .allowsHitTesting(!model.isSearching)
            .accessibilityHidden(model.isSearching)

            // Search's dimming covers the whole screen and only fades, so
            // it has no edge as search slides in. iPad has none.
            Color.black
                .opacity(HomeDesign.searchDimming * model.searchBackdropPresence)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if model.isSearching || model.searchPull > 0 {
                // Search slides down and fades in with the pull, and only
                // takes touches and the keyboard once it is open.
                HomeSearchView()
                    .opacity(presence)
                    .offset(y: -HomeDesign.searchPullOffset * (1 - presence))
                    .allowsHitTesting(model.isSearching)
                    .transition(.opacity)
            }

            // On iPhone, while the split screen waits for its second app, the
            // apps to open there, in its second half, over black.
            if model.isPickingSplitApp {
                GeometryReader { safeArea in
                    GeometryReader { screen in
                        HomeSplitScreenPicker(
                            size: screen.size,
                            safeArea: Self.insets(of: safeArea.size, within: screen.frame(in: .named(Self.pickerSafeAreaSpace))),
                            metrics: model.metrics ?? .reference
                        )
                    }
                    .ignoresSafeArea()
                }
                .coordinateSpace(.named(Self.pickerSafeAreaSpace))
                .ignoresSafeArea(.keyboard)
                .transition(.opacity)
            }
        }
        .animation(HomeDesign.modeChange, value: model.isPickingSplitApp)
        .background {
            HomeWallpaperImage()
        }
        // The Home Screen is drawn for a dark wallpaper, whatever the
        // appearance setting. Screens opened over it keep the setting.
        .environment(\.colorScheme, .dark)
        // Edit mode's buttons take the status bar's place, and an open folder
        // blurs it away with the rest of the Home Screen, as on iOS.
        .homeStatusBarHidden(model.isEditing || model.isFolderShown)
        // A screen over the Home Screen, onboarding, or a sheet from edit
        // mode's Edit menu, keeps the setting, as iOS's widget gallery is
        // light or dark as iOS is.
        .background {
            HomeWindowAppearance(isDark: !(model.isCoveredByScreen || model.isAddingWidget || model.isCustomizing || onboarding.coversHomeScreen))
        }
        .homePresentations(zoomNamespace: zoomNamespace)
        .homeRouting(router, onRoute: model.handle)
        .onReceive(model.appsPublisher, perform: model.syncApps)
        .onReceive(NotificationCenter.default.publisher(for: .LCPhoneSplitDidChange)) { _ in
            model.phoneSplitDidChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: .multitaskDockAddApp)) { _ in
            model.isAddingMultitaskApp = true
        }
        .onChange(of: coordinator.appSettingsCloseRequests) {
            model.closeAppSettings()
        }
    }

    /// The coordinate space of the safe area, which the whole screen is
    /// measured in to find the insets.
    private static let safeAreaSpace = "HomeSafeArea"
    /// The same, for the split screen's apps on offer.
    private static let pickerSafeAreaSpace = "HomeSplitPickerSafeArea"

    /// The safe area's insets, from its size and the whole screen's frame in
    /// its coordinates, which starts above and before it by the top and
    /// leading insets.
    private static func insets(of safeArea: CGSize, within screen: CGRect) -> EdgeInsets {
        EdgeInsets(
            top: max(-screen.minY, 0),
            leading: max(-screen.minX, 0),
            bottom: max(screen.maxY - safeArea.height, 0),
            trailing: max(screen.maxX - safeArea.width, 0)
        )
    }
}
