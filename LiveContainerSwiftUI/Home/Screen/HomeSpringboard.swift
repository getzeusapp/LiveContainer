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
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sceneDelegate: SceneDelegate

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                // The pages sink back and blur as search comes in, as far as a
                // pull down has brought it.
                HomePagesView(metrics: metrics, zoomNamespace: zoomNamespace)
                    .scaleEffect(1 - (1 - HomeDesign.searchScale) * model.searchPresence)
                    .blur(radius: HomeDesign.searchBlur * model.searchPresence)

                // The dock and the search pill only fade away as search comes in,
                // as on iOS. Blurring or shrinking glass makes it redraw unevenly
                // every frame.
                Group {
                    HomeDock(metrics: metrics, zoomNamespace: zoomNamespace)

                    HomePillRow(homeButtonScale: metrics.pillButtonScale)
                        .position(metrics.pillCenter)
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
