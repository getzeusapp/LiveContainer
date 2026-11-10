//
//  HomeWidgetCell.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A widget on a page, and everything it does: a long press shows its menu,
/// and in edit mode it jiggles, shows its minus badge and can be held and
/// dragged to a new place, or resized by the handle on its corner, the
/// widget stretching with the finger, its content blurred, as iOS does. A
/// tap does nothing. On iPhone the name of the widget showing sits under it,
/// as iOS labels widgets; iPadOS doesn't.
struct HomeWidgetCell: View {
    /// The widget's item on the page.
    let item: HomeItem
    let widget: HomeWidget
    /// The widget's size on screen, at its size.
    let size: CGSize
    /// Its size as its handle stretches it, while it's being resized.
    var liveSize: CGSize?
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// Whether this widget is being dragged. Its view stays put and hidden
    /// while a copy follows the finger, so the drag gesture on it keeps going.
    let isLifted: Bool
    /// Whether the widget is on the page showing. Only those jiggle in edit mode.
    let isOnScreen: Bool

    @Environment(HomeScreenModel.self) private var model
    @Environment(OnboardingModel.self) private var onboarding
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isHeld = false
    /// The widget showing at the top of a stack.
    @State private var shownKind: HomeWidgetKind?

    var body: some View {
        let kind = shownKind ?? widget.kinds.first ?? .calendar
        let shape = RoundedRectangle(cornerRadius: metrics.widgetCornerRadius, style: .continuous)
        let shown = liveSize ?? size

        content(shown: shown)
            .contentShape(shape)
            .contentShape(.contextMenuPreview, shape)
        .contextMenu {
            HomeIconMenu(item: item, app: nil)
        }
        .highPriorityGesture(editDrag, including: model.isEditing ? .all : .subviews)
        .onChange(of: isHeld) { wasHeld, isHeld in
            if wasHeld && !isHeld {
                model.iconReleased(item)
            }
        }
        .overlay(alignment: .top) {
            if SharedModel.isPhone {
                // Under the widget, as far below it as an icon's name is.
                HomeIconLabel(title: kind.title)
                    .frame(width: shown.width, height: HomeDesign.labelLineHeight)
                    .offset(y: shown.height + HomeDesign.labelSpacing)
                    .accessibilityHidden(true)
            }
        }
        // The badge and the resize handle sit over the widget, outside the
        // drag gesture, so touching them isn't taken for the start of a drag.
        .overlay(alignment: .topLeading) {
            if model.isEditing && !isLifted {
                HomeWidgetResizeHandle(size: shown, cornerRadius: metrics.widgetCornerRadius) { finger, start in
                    model.widgetResizeChanged(item, finger: finger, start: start)
                } onEnd: {
                    model.widgetResizeEnded(item)
                }
                .transition(HomeWidgetResizeHandle.transition(size: shown, cornerRadius: metrics.widgetCornerRadius))
                HomeMinusBadge(title: model.title(of: item), action: requestRemoval)
                    .position(x: HomeWidgetDesign.minusBadgeInset, y: HomeWidgetDesign.minusBadgeInset)
            }
        }
        .homeJiggle(
            isActive: model.isEditing && isOnScreen && !reduceMotion && !isLifted && !isResizing,
            seed: jiggleSeed,
            strength: HomeWidgetDesign.jiggleStrength(widget.size)
        )
        .opacity(isLifted ? 0 : 1)
        .animation(nil, value: isLifted)
        // Once it's on screen, with nothing over the Home Screen, it asks
        // for what it shows, as iOS asks when a widget first needs it.
        .task(id: isShowing ? kind : nil) {
            if isShowing {
                HomeWidgetAccess.shared.request(for: kind)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.title(of: item))
        .accessibilityHidden(isLifted)
    }

    /// Whether this widget's handle is being dragged.
    private var isResizing: Bool {
        model.widgetResize?.item == item
    }

    /// What the widget shows while it's resized, or nil.
    private var resizeLook: HomeWidgetResizeLook? {
        guard let resize = model.widgetResize, resize.item == item else {
            return nil
        }
        return resize.look
    }

    /// The widget, at `shown` size. While it's resized, as SpringBoard draws
    /// it, its content laid out at the size it's coming from shows in front,
    /// stretched to the frame, fading and blurring as the corner nears the
    /// next size, whose content, laid out at that size and stretched to the
    /// frame too, comes into focus behind it.
    private func content(shown: CGSize) -> some View {
        let radius = metrics.widgetCornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let look = resizeLook
        let maxBlur = HomeWidgetDesign.resizeBlur

        return ZStack(alignment: .topLeading) {
            if let look {
                if let next = look.to {
                    layer(at: next, shown: shown)
                        .blur(radius: maxBlur * (1 - look.progress), opaque: true)
                }
                layer(at: look.from, shown: shown)
                    .blur(radius: maxBlur * look.progress, opaque: true)
                    .opacity(1 - look.progress)
            } else {
                layer(at: widget.size, shown: shown)
            }
        }
        .frame(width: shown.width, height: shown.height, alignment: .topLeading)
        .clipShape(shape)
        .overlay {
            HomeWidgetRim(size: shown, cornerRadius: radius)
        }
    }

    /// The widget's content laid out at `widgetSize`, stretched to `shown`.
    private func layer(at widgetSize: HomeWidgetSize, shown: CGSize) -> some View {
        var laidOutWidget = widget
        laidOutWidget.size = widgetSize
        let laidOut = widgetSize == widget.size ? size : HomeWidgetResize.frameSize(widgetSize, on: metrics)

        return ZStack(alignment: .topLeading) {
            HomeWidgetBackground()
            HomeWidgetView(widget: laidOutWidget, size: laidOut, cornerRadius: metrics.widgetCornerRadius, shownKind: $shownKind, contentScale: metrics.widgetContentScale, showsRim: false)
        }
        .frame(width: laidOut.width, height: laidOut.height)
        .scaleEffect(x: shown.width / max(laidOut.width, 1), y: shown.height / max(laidOut.height, 1), anchor: .topLeading)
        .frame(width: shown.width, height: shown.height, alignment: .topLeading)
    }

    /// Whether the widget is in sight: on the page showing, with neither
    /// onboarding nor a screen over the Home Screen, outside edit mode.
    private var isShowing: Bool {
        isOnScreen && !onboarding.isPresented && model.presentedScreen == nil && !model.isEditing
    }

    /// A number that stays the same for this widget, so it always jiggles its own way.
    private var jiggleSeed: Int {
        item.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
    }

    /// Holding a widget in edit mode for a moment picks it up; moving the
    /// finger then drags it, as an icon's cell does.
    private var editDrag: some Gesture {
        LongPressGesture(minimumDuration: HomeDesign.pickUpDelay, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(HomeDesign.coordinateSpace)))
            .updating($isHeld) { value, isHeld, _ in
                if case .second(true, _) = value {
                    isHeld = true
                }
            }
            .onChanged(dragChanged)
    }

    private func dragChanged(_ value: SequenceGesture<LongPressGesture, DragGesture>.Value) {
        guard case .second(true, let drag?) = value else {
            return
        }
        model.dragChanged(item, finger: drag.location, start: drag.startLocation)
    }

    private func requestRemoval() {
        model.requestRemoval(of: item)
    }
}
