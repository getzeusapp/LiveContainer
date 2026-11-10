//
//  HomeLayout+Grid.swift
//  LiveContainerSwiftUI
//

import CoreGraphics

extension HomeLayout {
    /// The metrics a page lays out with on a screen: the screen's own, or on
    /// an iPad in portrait, iPadOS's four columns for a page with widgets.
    func metrics(forPage page: Int, on metrics: HomeMetrics) -> HomeMetrics {
        guard page >= 0, page < pages.count, pages[page].contains(where: \.isWidget) else {
            return metrics
        }
        return metrics.forWidgetPage
    }

    /// Where a page's items sit on a screen.
    func grid(forPage page: Int, on metrics: HomeMetrics) -> HomePageGrid {
        let pageMetrics = self.metrics(forPage: page, on: metrics)
        let items = page >= 0 && page < pages.count ? pages[page] : []
        return HomePageGrid(items: items, widgets: widgets, columns: pageMetrics.columns, rows: pageMetrics.rows)
    }

    /// The place on its page of the item at `index`: its top left place for a
    /// widget. One past the page's items, or one that doesn't fit, takes the
    /// place an app added there would.
    func place(ofPage page: Int, index: Int, on metrics: HomeMetrics) -> Int {
        let grid = grid(forPage: page, on: metrics)
        if index >= 0, index < grid.origins.count, let origin = grid.origins[index] {
            return origin
        }
        // Where an app after the page's items would go.
        let items = page >= 0 && page < pages.count ? pages[page] : []
        let pageMetrics = self.metrics(forPage: page, on: metrics)
        let extended = HomePageGrid(items: items + [.app("")], widgets: widgets, columns: pageMetrics.columns, rows: pageMetrics.rows)
        return extended.origins.last.flatMap { $0 } ?? min(index, pageMetrics.iconsPerPage - 1)
    }

    /// The center on screen of the item at `index` on a page: its icon's
    /// center, or a widget's.
    func center(ofPage page: Int, index: Int, on metrics: HomeMetrics) -> CGPoint {
        if let frame = widgetFrame(ofPage: page, index: index, on: metrics) {
            return CGPoint(x: frame.midX, y: frame.midY)
        }
        let pageMetrics = self.metrics(forPage: page, on: metrics)
        return pageMetrics.iconCenter(at: place(ofPage: page, index: index, on: metrics))
    }

    /// The frame on screen of the widget at `index` on a page, or nil when
    /// the item there isn't a widget or doesn't fit.
    func widgetFrame(ofPage page: Int, index: Int, on metrics: HomeMetrics) -> CGRect? {
        guard page >= 0, page < pages.count, index >= 0, index < pages[page].count,
              case .widget(let id) = pages[page][index], let widget = widgets[id] else {
            return nil
        }
        let grid = grid(forPage: page, on: metrics)
        guard index < grid.origins.count, let origin = grid.origins[index] else {
            return nil
        }
        return self.metrics(forPage: page, on: metrics).widgetFrame(origin: origin, span: widget.size.span)
    }
}
