//
//  HomeWidgetResizeHandle.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UIKit

/// The handle on a widget's bottom right corner in edit mode, as iOS 26.5's
/// SpringBoard draws it: a quarter circle of clear Liquid Glass hugging the
/// corner, with round ends. It grows out of the corner when edit mode starts
/// and shrinks back into it when edit mode ends. While a finger is on it, it
/// is a little bigger and brighter, and it springs back when let go.
/// Dragging it pulls the corner with the finger.
///
/// Its glass is drawn in a hosting view of its own, as SpringBoard's is, so
/// it tilts as one with the widget as it jiggles: SwiftUI draws the glass of
/// a tilted view as the upright box around it, which grows and shrinks.
struct HomeWidgetResizeHandle: View {
    /// The widget's size on screen and its corner radius.
    let size: CGSize
    let cornerRadius: Double
    /// Called as the handle moves, with where the finger is and where it
    /// first touched, on the Home Screen, and when it's let go.
    let onChange: (_ finger: CGPoint, _ start: CGPoint) -> Void
    let onEnd: () -> Void

    @GestureState private var isTouched = false
    @Environment(\.displayScale) private var displayScale
    @Environment(SystemAppearance.self) private var system: SystemAppearance?

    var body: some View {
        let metrics = HomeWidgetHandleMetrics(cornerRadius: cornerRadius, displayScale: displayScale)

        HomeWidgetHandleGlassHost(metrics: metrics, isHighlighted: isTouched, isDark: system?.isDark ?? true)
            .frame(width: metrics.side, height: metrics.side)
            .scaleEffect(isTouched ? HomeWidgetDesign.resizeHandlePressedScale : 1)
            .animation(isTouched ? HomeWidgetDesign.resizeHandlePress : HomeWidgetDesign.resizeHandleRelease, value: isTouched)
            // The square around the corner, reaching past it on every side.
            .contentShape(Rectangle().inset(by: metrics.edge - HomeWidgetDesign.resizeHandleHitOutset))
            .gesture(drag)
            .position(metrics.center(in: size))
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .accessibilityHidden(true)
    }

    /// A finger on the handle lights it up at once; moving it resizes the
    /// widget.
    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(HomeDesign.coordinateSpace))
            .updating($isTouched) { _, isTouched, _ in
                isTouched = true
            }
            .onChanged { value in
                if value.translation != .zero {
                    onChange(value.location, value.startLocation)
                }
            }
            .onEnded { _ in
                onEnd()
            }
    }

    /// How the handle comes and goes with edit mode, as SpringBoard's does:
    /// it grows out of a dot by the corner, and shrinks back into it.
    static func transition(size: CGSize, cornerRadius: Double) -> AnyTransition {
        let center = HomeWidgetHandleMetrics.center(in: size, cornerRadius: cornerRadius)
        let anchor = UnitPoint(x: center.x / max(size.width, 1), y: center.y / max(size.height, 1))
        return AnyTransition.modifier(
            active: HomeWidgetHandleAppearance(isHidden: true, anchor: anchor),
            identity: HomeWidgetHandleAppearance(isHidden: false, anchor: anchor)
        )
        .animation(HomeWidgetDesign.resizeHandleAppearance)
    }
}

/// Where the handle goes and how big it is, as SpringBoard measures it from
/// its settings: its view is the square of the widget's corner radius
/// centered on that corner's rounding, grown on each side by half the line
/// width, rounded up to whole pixels.
struct HomeWidgetHandleMetrics {
    let cornerRadius: Double
    /// How far the view reaches past the corner's square on each side.
    let edge: Double

    init(cornerRadius: Double, displayScale: Double) {
        self.cornerRadius = cornerRadius
        let scale = max(displayScale, 1)
        edge = (HomeWidgetDesign.resizeHandleLineWidth / 2 * scale).rounded(.up) / scale
    }

    /// The side of the handle's view.
    var side: Double {
        cornerRadius + 2 * edge
    }

    /// The handle's center in a widget of `size`.
    func center(in size: CGSize) -> CGPoint {
        Self.center(in: size, cornerRadius: cornerRadius)
    }

    static func center(in size: CGSize, cornerRadius: Double) -> CGPoint {
        CGPoint(x: size.width - cornerRadius / 2, y: size.height - cornerRadius / 2)
    }
}

/// The handle hidden by edit mode ending, or showing: shrunk to a tenth
/// toward the corner and faded out, or as it is.
private struct HomeWidgetHandleAppearance: ViewModifier {
    let isHidden: Bool
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        let shift = isHidden ? HomeWidgetDesign.resizeHandleHiddenShift : 0
        content
            .scaleEffect(isHidden ? HomeWidgetDesign.resizeHandleHiddenScale : 1, anchor: anchor)
            .offset(x: shift, y: shift)
            .opacity(isHidden ? 0 : 1)
    }
}

/// The handle's glass in a hosting view of its own, which the handle tilts
/// and scales as a whole.
private struct HomeWidgetHandleGlassHost: UIViewControllerRepresentable {
    let metrics: HomeWidgetHandleMetrics
    let isHighlighted: Bool
    let isDark: Bool

    func makeUIViewController(context: Context) -> HomeWidgetHandleGlassController {
        let controller = HomeWidgetHandleGlassController(rootView: glass)
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        controller.sizingOptions = []
        controller.safeAreaRegions = []
        return controller
    }

    func updateUIViewController(_ controller: HomeWidgetHandleGlassController, context: Context) {
        controller.rootView = glass
        controller.tuneGlassSoon()
    }

    private var glass: HomeWidgetHandleGlass {
        HomeWidgetHandleGlass(shape: HomeWidgetHandleShape(edge: metrics.edge), isHighlighted: isHighlighted, isDark: isDark)
    }
}

/// Hosts the handle's glass and makes it SpringBoard's: SwiftUI only offers
/// glass the size of a button, which bends what's behind it like a lens,
/// while SpringBoard's handle uses the small size, made for handles and
/// badges, which bends it about a quarter as much, with a smaller shadow and
/// a flatter face. Core Animation draws the glass with a filter on a
/// backdrop layer, whose settings are set to SpringBoard's once SwiftUI has
/// made it, and again whenever it may have made it anew.
private final class HomeWidgetHandleGlassController: UIHostingController<HomeWidgetHandleGlass> {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        HomeWidgetHandleGlassTuning.apply(to: view.layer)
    }

    /// Tunes the glass after SwiftUI's next update, which may replace it.
    func tuneGlassSoon() {
        DispatchQueue.main.async { [weak self] in
            guard let self, isViewLoaded else {
                return
            }
            HomeWidgetHandleGlassTuning.apply(to: view.layer)
        }
    }
}

/// The settings of SpringBoard's resize handle glass that differ from
/// SwiftUI's clear glass, as iOS 26.5 sets them on the glass filter: the
/// refraction and shadow of its small size, a quarter of a button's, and the
/// flatter face of its "homescreenResizeHandle" kind.
private enum HomeWidgetHandleGlassTuning {
    static let filterName = "glassBackground"
    static let settings: [String: Double] = [
        "inputInnerRefractionAmount": -8,
        "inputInnerRefractionHeight": 2.88,
        "inputOuterRefractionAmount": 1.6,
        "inputOuterRefractionHeight": 1,
        "inputShadowAmount": 5,
        "inputShadowHeight": 3.2,
        "inputFaceColorMatrixBlack": 0.15,
        "inputFaceColorMatrixWhite": 0.96,
        "inputClamp": 1,
    ]

    /// Sets the settings on every glass filter in `layer`'s tree, leaving
    /// it alone where there's none, as before iOS 26.
    static func apply(to layer: CALayer) {
        if layer.filters?.contains(where: { ($0 as AnyObject).value(forKey: "name") as? String == filterName }) == true {
            for (key, value) in settings where (layer.value(forKeyPath: "filters.\(filterName).\(key)") as? Double) != value {
                layer.setValue(value, forKeyPath: "filters.\(filterName).\(key)")
            }
        }
        for sublayer in layer.sublayers ?? [] {
            apply(to: sublayer)
        }
    }
}

/// The handle's glass: iOS 26's clear Liquid Glass in the handle's shape,
/// in the Home Screen's appearance, brightened while touched as SpringBoard
/// lights it, or before iOS 26, a light gray curve with a glossy edge.
private struct HomeWidgetHandleGlass: View {
    let shape: HomeWidgetHandleShape
    let isHighlighted: Bool
    let isDark: Bool

    var body: some View {
        glass
            .brightness(isHighlighted ? HomeWidgetDesign.resizeHandleHighlightBrightness : 0)
            .saturation(isHighlighted && isDark ? HomeWidgetDesign.resizeHandleHighlightSaturation : 1)
            .animation(isHighlighted ? HomeWidgetDesign.resizeHandlePress : HomeWidgetDesign.resizeHandleRelease, value: isHighlighted)
            .environment(\.colorScheme, isDark ? .dark : .light)
    }

    @ViewBuilder
    private var glass: some View {
        if #available(iOS 26.0, *), SharedModel.isLiquidGlassEnabled {
            Color.clear
                .glassEffect(.clear, in: shape)
        } else {
            shape
                .fill(LinearGradient(colors: [Color(white: 0.84), Color(white: 0.5)], startPoint: .top, endPoint: .bottom))
                .overlay {
                    shape.stroke(.white.opacity(0.8), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        }
    }
}

/// The handle's outline, as SpringBoard draws it: a quarter circle of 18
/// points' radius around the widget's corner, its middle line 1 point inside
/// the widget's edges, stroked 13 points thick with round ends. `rect` is
/// the handle's view, which reaches `edge` past the corner on each side.
struct HomeWidgetHandleShape: Shape {
    let edge: Double

    func path(in rect: CGRect) -> Path {
        let inset = HomeWidgetDesign.resizeHandleArcRadius + HomeWidgetDesign.resizeHandleInset
        var arc = Path()
        arc.addArc(
            center: CGPoint(x: rect.maxX - edge - inset, y: rect.maxY - edge - inset),
            radius: HomeWidgetDesign.resizeHandleArcRadius,
            startAngle: .zero,
            endAngle: .degrees(90),
            clockwise: false
        )
        return arc.strokedPath(StrokeStyle(lineWidth: HomeWidgetDesign.resizeHandleLineWidth, lineCap: .round))
    }
}
