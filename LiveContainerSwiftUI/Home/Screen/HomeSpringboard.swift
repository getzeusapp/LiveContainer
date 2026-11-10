//
//  HomeSpringboard.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Everything on the Home Screen itself, laid out on the whole screen: the
/// pages, the dock, the search pill (or the Home button in its place), the
/// open folder, edit mode's buttons over it, the icon being dragged over
/// everything, and the launch zoom. Positions come
/// from HomeMetrics, in the screen's coordinate space, which the drag gesture
/// uses too.
struct HomeSpringboard: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model
    @Environment(WallpaperStore.self) private var wallpaper
    @Environment(SystemAppearance.self) private var system
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.homeButtonEdge) private var homeButtonEdge
    @EnvironmentObject private var sceneDelegate: SceneDelegate
    /// Whether the iPad's dock shows recent apps, as Settings > Appearance says.
    @AppStorage(HomeDockRecents.settingKey) private var showsDockRecents = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                // On iPhone the pages sink back and blur as search comes in,
                // as far as a pull down has brought it. iPad's search leaves
                // them as they are.
                HomePagesView(metrics: metrics, zoomNamespace: zoomNamespace)
                    .scaleEffect(1 - (1 - HomeDesign.searchScale) * model.searchBackdropPresence)
                    .blur(radius: HomeDesign.searchBlur * model.searchBackdropPresence)

                // The dock only fades away as search comes in on iPhone, as on
                // iOS. Blurring or shrinking glass makes it redraw unevenly
                // every frame. On iPad it stays.
                HomeDock(metrics: metrics, zoomNamespace: zoomNamespace)
                    .opacity(1 - model.searchBackdropPresence)

                // The row above the dock fades away as search comes in, on
                // iPad too, where search shows the Home button there instead.
                Group {
                    // iPadOS and iPhones with a Home button have no search pill,
                    // only the page dots.
                    HomePillRow(
                        homeButtonScale: metrics.pillButtonScale,
                        isBare: metrics.isDockFlush || !SharedModel.isPhone,
                        isOnBrightBackdrop: isPillOnBrightBackdrop
                    )
                        .position(metrics.pillCenter)

                    // An iPad turned so its Home button is beside the screen,
                    // or above it, has zContainer's Home button there instead.
                    if homeButtonEdge != .bottom {
                        HomeEdgeButton(edge: homeButtonEdge, metrics: metrics)
                    }
                }
                .opacity(1 - model.searchPresence)
            }
            .accessibilityHidden(model.isFolderShown)

            HomeFolderView(metrics: metrics, zoomNamespace: zoomNamespace)

            if model.isEditing {
                HomeEditControls(metrics: metrics)
                    .transition(.opacity)
            }

            HomeLiftedIcon(metrics: metrics)

            if let zoom = model.launchZoom {
                HomeLaunchZoomView(zoom: zoom, metrics: metrics)
                    .id(zoom.id)
            }
        }
        .frame(width: metrics.size.width, height: metrics.size.height)
        .coordinateSpace(.named(HomeDesign.coordinateSpace))
        // Measured in the Home Screen's coordinate space, as edit mode's drag is.
        .onDrop(of: [HomeIconDropDelegate.iconType], delegate: HomeIconDropDelegate(model: model))
        .onChange(of: metrics, initial: true, publishMetrics)
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                publishMetrics()
            }
        }
        .onChange(of: showsDockRecents) {
            model.setShowsDockRecents(showsDockRecents)
        }
    }

    /// Whether the wallpaper behind the search pill is bright, where its text
    /// and dots turn dark.
    private var isPillOnBrightBackdrop: Bool {
        let pill = CGRect(
            x: metrics.pillCenter.x - HomeDesign.pillBackdropWidth / 2,
            y: metrics.pillCenter.y - HomeDesign.pillHeight / 2,
            width: HomeDesign.pillBackdropWidth,
            height: HomeDesign.pillHeight
        )
        let brightness = wallpaper.brightness(behind: pill, onScreenOf: metrics.size, isDark: system.isDark) ?? 0
        return brightness > HomeDesign.brightBackdrop
    }

    /// Hands this screen's metrics to the model, for dragging, the launch zoom
    /// and search. Only the main window's Home Screen does: on iPad, a second
    /// window that opens only to close again would leave its own size behind.
    /// The main window hands them over again whenever it comes to the front,
    /// in case another window's size got there meanwhile. On iPad they also
    /// go to `padMetrics`, which search follows as the window changes size.
    private func publishMetrics() {
        guard MainWindow.isMain(sceneDelegate.window?.windowScene), model.metrics != metrics else {
            return
        }
        model.metrics = metrics
        if !SharedModel.isPhone {
            model.padMetrics = metrics
        }
    }
}
