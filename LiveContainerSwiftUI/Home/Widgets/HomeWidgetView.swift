//
//  HomeWidgetView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What a widget shows, at its size, light or dark as zContainer's theme is,
/// with its corners rounded as iOS rounds widgets. A stack's widgets sit one
/// above the next and swipe up and down, a page at a time, with dots at the
/// side while they move, as iOS's Smart Stack does.
struct HomeWidgetView: View {
    let widget: HomeWidget
    /// The widget's size on screen.
    let size: CGSize
    let cornerRadius: Double
    /// The widget showing at the top of a stack.
    @Binding var shownKind: HomeWidgetKind?
    /// How much smaller than an iPhone's the widget's content is drawn, as
    /// iPadOS draws a widget laid out at an iPhone's size, made smaller to
    /// fit its smaller places. 1 on iPhone.
    var contentScale = 1.0
    /// Whether it draws the light along its edges, which a view drawing the
    /// widget at another size draws itself.
    var showsRim = true

    @Environment(SystemAppearance.self) private var system
    @State private var isScrolling = false

    var body: some View {
        let laidOut = CGSize(width: size.width / contentScale, height: size.height / contentScale)

        Group {
            if widget.isStack {
                stack(laidOut: laidOut)
            } else if let kind = widget.kinds.first {
                HomeWidgetContent(kind: kind, size: widget.size, frameSize: laidOut)
            }
        }
        .frame(width: laidOut.width, height: laidOut.height)
        .scaleEffect(contentScale)
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if showsRim {
                HomeWidgetRim(size: size, cornerRadius: cornerRadius)
            }
        }
        // The Home Screen's window stays dark for the status bar; widgets are
        // light or dark as zContainer's theme is, as iOS's follow Dark Mode.
        .environment(\.colorScheme, system.isDark ? .dark : .light)
    }

    private func stack(laidOut size: CGSize) -> some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(widget.kinds) { kind in
                    HomeWidgetContent(kind: kind, size: widget.size, frameSize: size)
                        .frame(width: size.width, height: size.height)
                        .id(kind)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $shownKind)
        .modifier(StackScrollTracking(isScrolling: $isScrolling))
        .overlay(alignment: .trailing) {
            stackDots
                .opacity(isScrolling ? 1 : 0)
        }
    }

    /// One dot for each of a stack's widgets, the one showing brighter.
    private var stackDots: some View {
        let shown = shownKind ?? widget.kinds.first
        return VStack(spacing: HomeWidgetDesign.stackDotSpacing) {
            ForEach(widget.kinds) { kind in
                Circle()
                    .fill(.secondary)
                    .opacity(kind == shown ? 1 : 0.4)
                    .frame(width: HomeWidgetDesign.stackDotSize, height: HomeWidgetDesign.stackDotSize)
            }
        }
        .padding(.trailing, HomeWidgetDesign.stackDotsInset)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One widget's content, by its kind and size.
struct HomeWidgetContent: View {
    let kind: HomeWidgetKind
    let size: HomeWidgetSize
    /// The widget's size on screen.
    let frameSize: CGSize

    var body: some View {
        switch kind {
        case .calendar:
            HomeCalendarWidget(size: size, frameSize: frameSize)
        case .maps:
            HomeMapsWidget(frameSize: frameSize)
        case .news:
            HomeNewsWidget(size: size, frameSize: frameSize)
        case .photos:
            HomePhotosWidget(frameSize: frameSize)
        case .reminders:
            HomeRemindersWidget(size: size, frameSize: frameSize)
        }
    }
}

/// Tells a stack when its widgets are moving, on iOS 18 and later, which show
/// its dots meanwhile; iOS 17 shows none.
private struct StackScrollTracking: ViewModifier {
    @Binding var isScrolling: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { _, phase in
                withAnimation(.easeInOut(duration: 0.25)) {
                    isScrolling = phase.isScrolling
                }
            }
        } else {
            content
        }
    }
}
