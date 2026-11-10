//
//  HomeLiftedIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The copy of the dragged icon that follows the finger in edit mode, over
/// the pages and the dock alike, so moving between them never hides it. It
/// shows from the moment the icon is picked up until it has landed, taking
/// over from the icon and handing back to it in the same place and look,
/// with no fade between them.
///
/// Icons tapped while it's held join it, as on iOS: each flies in from its
/// place to the top of a stack under the finger, the ones under it showing a
/// little lower and to the right, with a badge counting them all. Let go,
/// each lands in its own place.
struct HomeLiftedIcon: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        if let drag = model.drag, let widget = model.widget(for: drag.item), let size = widgetSize(of: drag) {
            HomeLiftedWidgetCopy(widget: widget, size: size, metrics: metrics)
                .position(model.liftedIconCenter)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.identity)
        } else if let drag = model.drag {
            ZStack(alignment: .topLeading) {
                ForEach(drag.items, id: \.self) { item in
                    let depth = depth(of: item, in: drag)
                    let center = iconCenter(of: item, depth: depth, in: drag)
                    HomeLiftedIconCopy(
                        item: item,
                        drag: drag,
                        app: app(for: item),
                        metrics: metrics,
                        darkModeIcon: darkModeIcon,
                        stackDepth: depth,
                        flightOffset: flightOffset(of: item, to: center, in: drag)
                    )
                    // The copy is laid out like an icon with its name, so its
                    // center sits below the icon's, as a page's icons do.
                    .position(x: center.x, y: center.y - metrics.iconSize / 2 + metrics.cellHeight / 2)
                    .zIndex(Double(drag.items.count - depth))
                }
                if drag.items.count > 1, !model.isDropping {
                    HomeStackBadge(count: drag.items.count)
                        .position(badgeCenter)
                        .zIndex(Double(drag.items.count + 1))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(HomeDesign.stackJoin, value: drag.items.count)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .transition(.identity)
        }
    }

    /// How far down the stack an icon is: 0 for the top, the newest.
    private func depth(of item: HomeItem, in drag: HomeDrag) -> Int {
        drag.items.count - 1 - (drag.items.firstIndex(of: item) ?? 0)
    }

    /// Where an icon's center goes: in the stack under the finger, lower and
    /// further right the deeper it is, or once let go, where it lands.
    private func iconCenter(of item: HomeItem, depth: Int, in drag: HomeDrag) -> CGPoint {
        let center = model.liftedIconCenter
        if model.isDropping {
            return item == drag.item ? center : drag.landing[item] ?? center
        }
        let step = Double(min(depth, HomeDesign.stackTilts.count - 1))
        return CGPoint(x: center.x + HomeDesign.stackOffset.width * step, y: center.y + HomeDesign.stackOffset.height * step)
    }

    /// How far an icon that just joined is from the stack, which it flies
    /// in from: from where it was on screen.
    private func flightOffset(of item: HomeItem, to center: CGPoint, in drag: HomeDrag) -> CGSize {
        guard let from = drag.joinedFrom[item] else {
            return .zero
        }
        return CGSize(width: from.x - center.x, height: from.y - center.y)
    }

    /// The badge's center: on the top right corner of the top icon, as it's
    /// raised under the finger, a point outside it each way.
    private var badgeCenter: CGPoint {
        let half = metrics.iconSize * HomeDesign.liftedScale / 2
        let center = model.liftedIconCenter
        let corner = half + HomeDesign.stackBadgeOutset
        return CGPoint(x: center.x + corner, y: center.y - corner)
    }

    /// The size of the dragged widget, as it shows where it was picked up.
    private func widgetSize(of drag: HomeDrag) -> CGSize? {
        guard case .page(let page, let index) = drag.origin else {
            return nil
        }
        return model.layout.widgetFrame(ofPage: page, index: index, on: metrics)?.size
    }

    private func app(for item: HomeItem) -> LCAppModel? {
        guard case .app(let key) = item else {
            return nil
        }
        return model.apps[key]
    }
}

/// The count of the icons being moved together, as iOS badges a stack of
/// them: white on a circle of the system blue, longer for more digits.
struct HomeStackBadge: View {
    let count: Int

    var body: some View {
        Text(count, format: .number)
            .font(.system(size: HomeDesign.stackBadgeFontSize, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, count > 9 ? 6 : 0)
            .frame(minWidth: HomeDesign.stackBadgeSize, minHeight: HomeDesign.stackBadgeSize)
            .background(Color(uiColor: .systemBlue), in: .capsule)
            .contentTransition(.numericText(value: Double(count)))
            .animation(HomeDesign.stackJoin, value: count)
    }
}
