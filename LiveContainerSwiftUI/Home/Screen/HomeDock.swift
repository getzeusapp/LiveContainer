//
//  HomeDock.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The dock: icons without names on a glass panel at the bottom of the
/// screen, or on the trailing side on an iPhone in landscape, centered as on
/// iOS. An iPhone's dock holds up to four. An iPad's floats as iPadOS 26.5's
/// does, as HomePadDock lays it out: the person's icons, then a divider and
/// the apps opened most recently, on glass as wide as they need but never
/// narrower than four icons, all of it shrinking when it doesn't fit across
/// the screen. On iPhones with a Home button it runs the full width, flush
/// with the bottom. Not to be confused with MultitaskDockView, the dock of
/// multitasking windows.
struct HomeDock: View {
    /// Where things go on this screen.
    let metrics: HomeMetrics
    /// The namespace Settings and app settings zoom out of icons in.
    let zoomNamespace: Namespace.ID

    @Environment(HomeScreenModel.self) private var model
    @Environment(\.prefersDarkAppIcons) private var darkModeIcon

    var body: some View {
        let contents = model.dockContents

        Group {
            if let dock = metrics.padDock(contents) {
                padDock(dock, contents: contents)
            } else {
                phoneDock(contents)
            }
        }
        .frame(width: metrics.size.width, height: metrics.size.height, alignment: .topLeading)
    }

    // MARK: iPhone

    private func phoneDock(_ contents: HomeDockContents) -> some View {
        let glass = metrics.dockGlass(contents)
        let iconMetrics = metrics.dockIconMetrics(contents)

        return ZStack(alignment: .topLeading) {
            Group {
                if metrics.isDockFlush {
                    // A flat band with no rim, as iOS draws the dock of iPhones
                    // with a Home button: glass bigger than the dock, cut to it.
                    Color.clear
                        .frame(width: glass.width + Self.flushOverhang * 2, height: glass.height + Self.flushOverhang * 2)
                        .homeGlass(.edgeToEdge, style: .dock)
                        .frame(width: glass.width, height: glass.height)
                        .clipped()
                } else {
                    // SpringBoard's own radius for this screen, which is less
                    // than the screen's corners' less the inset on the newest
                    // iPhones.
                    Color.clear
                        .frame(width: glass.width, height: glass.height)
                        .homeGlass(.rounded(metrics.dockCornerRadius), style: .dock)
                }
            }
            .contentShape(.rect)
            .position(x: glass.midX, y: glass.midY)
            .accessibilityHidden(true)

            ForEach(model.dockPlacements) { placement in
                cell(placement.item, isLifted: placement.isLifted, metrics: iconMetrics)
                    .position(phoneCenter(of: placement.slot, contents: contents))
            }
        }
    }

    /// How far a full-width dock's glass reaches past each of its edges
    /// before it's cut to the dock, which takes the glass's rim off.
    private static let flushOverhang = 8.0

    private func phoneCenter(of slot: HomeSlot, contents: HomeDockContents) -> CGPoint {
        guard case .dock(let index) = slot else {
            return CGPoint(x: metrics.dockFrame.midX, y: metrics.dockFrame.midY)
        }
        return metrics.dockIconCenter(at: index, in: contents)
    }

    // MARK: iPad

    /// The iPad's dock. As SpringBoard resizes its dock, the glass, the
    /// divider and where each row of icons starts change over 0.3 seconds,
    /// easing in and out, while the icons move to their places in their row
    /// with its spring. Recent apps come and go from a hundredth of their
    /// size, fading, over half a second, the dock resizing along with them.
    /// When it can't take what's held over it, it bounces.
    private func padDock(_ dock: HomePadDock, contents: HomeDockContents) -> some View {
        let iconMetrics = metrics.dockIconMetrics(contents)
        let contentScale = dock.iconSize / max(metrics.iconSize, 1)
        let recents = model.dockRecents
        let center = UnitPoint(
            x: dock.platter.midX / max(metrics.size.width, 1),
            y: dock.platter.midY / max(metrics.size.height, 1)
        )

        return ZStack(alignment: .topLeading) {
            Color.clear
                .homeGlass(.rounded(dock.cornerRadius), style: .dock)
                .contentShape(.rect)
                .padDockResizing { glass in
                    glass
                        .frame(width: dock.platter.width, height: dock.platter.height)
                        .position(x: dock.platter.midX, y: dock.platter.midY)
                }
                .accessibilityHidden(true)

            Rectangle()
                .fill(.white.opacity(HomeDesign.padDockDividerOpacity))
                .padDockResizing { line in
                    line
                        .opacity(dock.showsDivider ? 1 : 0)
                        .frame(width: dock.divider.width, height: dock.divider.height)
                        .position(x: dock.divider.midX, y: dock.divider.midY)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            row(at: dock.iconsOrigin) {
                ForEach(model.dockPlacements) { placement in
                    cell(placement.item, isLifted: placement.isLifted, metrics: iconMetrics, contentScale: contentScale)
                        .padDockReflowing { icon in
                            icon.position(place(at: placement.slot.dockIndex, in: dock))
                        }
                }
            }

            row(at: dock.recentsOrigin) {
                ForEach(Array(recents.enumerated()), id: \.element) { index, item in
                    cell(item, isLifted: false, metrics: iconMetrics, contentScale: contentScale, isRecent: true)
                        .transition(.scale(scale: HomeDesign.padDockRecentHiddenScale).combined(with: .opacity))
                        .padDockReflowing { icon in
                            icon.position(place(at: index, in: dock))
                        }
                }
            }
        }
        .modifier(HomeDockBounce(bounces: Double(model.dockBounces), anchor: center))
    }

    /// A row of the dock's icons, the person's or the recent apps, which
    /// starts at `origin` on screen.
    private func row(at origin: CGPoint, @ViewBuilder icons: () -> some View) -> some View {
        ZStack(alignment: .topLeading) {
            icons()
        }
        .frame(width: metrics.size.width, height: metrics.size.height, alignment: .topLeading)
        .padDockResizing { row in
            row.offset(x: origin.x, y: origin.y)
        }
    }

    /// The center of the icon at `index` in a row of the dock's icons, from
    /// where the row starts.
    private func place(at index: Int, in dock: HomePadDock) -> CGPoint {
        CGPoint(x: Double(index) * (dock.iconSize + dock.spacing) + dock.iconSize / 2, y: dock.iconSize / 2)
    }

    // MARK: Icons

    private func cell(_ item: HomeItem, isLifted: Bool, metrics: HomeMetrics, contentScale: Double = 1, isRecent: Bool = false) -> some View {
        HomeIconCell(
            item: item,
            app: app(for: item),
            metrics: metrics,
            showsLabel: false,
            isLifted: isLifted,
            isOnScreen: true,
            darkModeIcon: darkModeIcon,
            zoomNamespace: zoomNamespace,
            isRecent: isRecent,
            contentScale: contentScale
        )
    }

    private func app(for item: HomeItem) -> LCAppModel? {
        guard case .app(let key) = item else {
            return nil
        }
        return model.apps[key]
    }
}

private extension HomeSlot {
    /// The slot's place in the dock, or 0 for a slot elsewhere.
    var dockIndex: Int {
        if case .dock(let index) = self {
            index
        } else {
            0
        }
    }
}

private extension View {
    /// Applies `body`'s modifiers as the iPad's dock resizes, as SpringBoard
    /// resizes its dock: what animates takes 0.3 seconds, easing in and out,
    /// unless a recent app coming or going sets the pace, as SpringBoard's
    /// dock resizes inside that animation.
    func padDockResizing(@ViewBuilder _ body: (PlaceholderContentView<Self>) -> some View) -> some View {
        transaction({ transaction in
            guard let animation = transaction.animation, animation != HomeDesign.padDockRecentsChange else {
                return
            }
            transaction.animation = HomeDesign.padDockResize
        }, body: body)
    }

    /// Applies `body`'s modifiers as icons move to their places in a row of
    /// the iPad's dock, with SpringBoard's spring for icons making room,
    /// unless a recent app coming or going sets the pace.
    func padDockReflowing(@ViewBuilder _ body: (PlaceholderContentView<Self>) -> some View) -> some View {
        transaction({ transaction in
            guard let animation = transaction.animation, animation != HomeDesign.padDockRecentsChange else {
                return
            }
            transaction.animation = HomeDesign.padDockReflow
        }, body: body)
    }
}
