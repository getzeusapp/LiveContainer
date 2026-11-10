//
//  HomeScreenModel+Widgets.swift
//  LiveContainerSwiftUI
//

import SwiftUI

extension HomeScreenModel {
    /// The widget an item stands for, as the Home Screen shows it now.
    func widget(for item: HomeItem) -> HomeWidget? {
        guard case .widget(let id) = item else {
            return nil
        }
        return displayedLayout.widgets[id]
    }

    /// Adds a widget at the top of the page showing, as iOS's widget gallery
    /// does, and ends editing's gallery.
    func addWidget(_ widget: HomeWidget) {
        let page = page ?? 0
        withAnimation(HomeDesign.reflow) {
            layout.addWidget(widget, toPage: page)
            isAddingWidget = false
        }
        HomeLayoutStorage.save(layout)
    }

    /// Removes the widget the person asked to remove.
    func removePendingWidget() {
        guard case .widget(let id) = pendingWidgetRemoval else {
            return
        }
        pendingWidgetRemoval = nil
        withAnimation(HomeDesign.reflow) {
            layout.removeWidget(id)
        }
        HomeLayoutStorage.save(layout)
    }

    // MARK: Resizing

    /// Follows a widget's handle as it's dragged, as SpringBoard does: the
    /// corner goes with the finger, at `finger` on the page, which first
    /// touched at `start`; see HomeWidgetResize. The widget follows with a
    /// quick spring, and when the size the other icons make room for
    /// changes, they move with a slower one. Nothing is saved until it's let
    /// go, and one widget is resized at a time.
    func widgetResizeChanged(_ item: HomeItem, finger: CGPoint, start: CGPoint) {
        guard isEditing, drag == nil, let metrics, case .widget(let id) = item else {
            return
        }
        if let resize = widgetResize, resize.item != item || resize.isSettling {
            return
        }
        if widgetResize == nil {
            guard let widget = layout.widgets[id], case .page(let page, let index)? = layout.slot(of: item),
                  let frame = layout.widgetFrame(ofPage: page, index: index, on: metrics),
                  let resize = HomeWidgetResize(item: item, id: id, widget: widget, frame: frame, start: start, metrics: metrics) else {
                return
            }
            widgetResize = resize
            widgetResizePreview = layout
        }
        guard var resize = widgetResize else {
            return
        }
        let roomFor = resize.size
        resize.follow(finger)
        withAnimation(HomeWidgetDesign.resizeTracking) {
            widgetResize = resize
        }
        if resize.size != roomFor {
            var preview = layout
            preview.widgets[id]?.size = resize.size
            preview.respill(keeping: item)
            withAnimation(HomeWidgetDesign.resizeReflow) {
                widgetResizePreview = preview
            }
        }
    }

    /// Lets go of a widget's handle: it settles at the size the other icons
    /// made room for, in its place there, its content coming into focus at
    /// that size, and once it has, the layout is saved if its size changed.
    func widgetResizeEnded(_ item: HomeItem) {
        guard var resize = widgetResize, resize.item == item, !resize.isSettling, let metrics else {
            return
        }
        let preview = widgetResizePreview ?? layout
        var place = resize.frame
        if case .page(let page, let index)? = preview.slot(of: item), let frame = preview.widgetFrame(ofPage: page, index: index, on: metrics) {
            place = frame
        }
        resize.settle(into: place)
        withAnimation(HomeWidgetDesign.resizeSettle) {
            widgetResize = resize
        } completion: { [weak self] in
            guard let self, widgetResize?.item == item, widgetResize?.isSettling == true else {
                return
            }
            layout = preview
            widgetResize = nil
            widgetResizePreview = nil
            if resize.size != resize.originalSize {
                HomeLayoutStorage.save(layout)
            }
        }
    }
}
