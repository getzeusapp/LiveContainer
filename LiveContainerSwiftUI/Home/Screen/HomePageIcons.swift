//
//  HomePageIcons.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The icons and widgets of the pages, side by side, each at its place in
/// its page's grid, plus the icon holding a new app's place while it installs. Only the
/// pages near the one showing are built (HomeScreenModel's `builtPages`), so
/// icons far away don't load, and only the page showing jiggles in edit mode.
struct HomePageIcons: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// How many pages wide the layer is.
    let pageCount: Int
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model
    @Environment(AppLaunchCoordinator.self) private var coordinator
    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        let currentPage = model.page ?? 0
        let shown = model.displayedLayout

        ZStack(alignment: .topLeading) {
            ForEach(model.visibleGridPlacements) { placement in
                if let widget = model.widget(for: placement.item), let frame = widgetFrame(of: placement.slot, in: shown) {
                    // A widget being resized shows in the frame following the
                    // finger, and settles from it into its place, over
                    // everything else on the page, as SpringBoard lifts it
                    // above the icons that make room for it.
                    let live = liveFrame(of: placement.item)
                    let showing = live ?? frame
                    HomeWidgetCell(
                        item: placement.item,
                        widget: widget,
                        size: frame.size,
                        liveSize: live?.size,
                        metrics: metrics,
                        isLifted: placement.isLifted,
                        isOnScreen: placement.slot.page == currentPage
                    )
                    .position(x: Double(placement.slot.page ?? 0) * metrics.size.width + showing.midX, y: showing.midY)
                    .zIndex(live == nil ? 0 : 1)
                } else {
                    HomeIconCell(
                        item: placement.item,
                        app: app(for: placement.item),
                        metrics: metrics,
                        showsLabel: true,
                        isLifted: placement.isLifted,
                        isOnScreen: placement.slot.page == currentPage,
                        darkModeIcon: darkModeIcon,
                        zoomNamespace: zoomNamespace
                    )
                    .position(position(of: placement.slot, in: shown))
                }
            }

            if coordinator.isInstalling {
                HomeInstallingIcon(
                    metrics: metrics,
                    download: coordinator.downloadHelper
                )
                .position(position(of: shown.nextFreeSlot, in: shown))
                .transition(.opacity)
            }
        }
        .frame(width: metrics.size.width * Double(pageCount), height: metrics.size.height, alignment: .topLeading)
    }

    private func app(for item: HomeItem) -> LCAppModel? {
        guard case .app(let key) = item else {
            return nil
        }
        return model.apps[key]
    }

    /// The center of an icon with its name, at a slot on a page, in this
    /// layer's coordinates: at its place in the page's grid.
    private func position(of slot: HomeSlot, in shown: HomeLayout) -> CGPoint {
        guard case .page(let page, let index) = slot else {
            return .zero
        }
        let pageMetrics = shown.metrics(forPage: page, on: metrics)
        let cell = pageMetrics.cellCenter(at: shown.place(ofPage: page, index: index, on: metrics))
        return CGPoint(x: Double(page) * metrics.size.width + cell.x, y: cell.y)
    }

    /// The frame on its page of a widget being resized, following its
    /// handle or settling, or nil for any other.
    private func liveFrame(of item: HomeItem) -> CGRect? {
        guard let resize = model.widgetResize, resize.item == item else {
            return nil
        }
        return resize.frame
    }

    /// The frame on its page of the widget at a slot, or nil for an icon.
    private func widgetFrame(of slot: HomeSlot, in shown: HomeLayout) -> CGRect? {
        guard case .page(let page, let index) = slot else {
            return nil
        }
        return shown.widgetFrame(ofPage: page, index: index, on: metrics)
    }
}
