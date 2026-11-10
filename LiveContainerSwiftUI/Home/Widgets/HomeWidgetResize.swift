//
//  HomeWidgetResize.swift
//  LiveContainerSwiftUI
//

import CoreGraphics

/// A widget being resized by its handle in edit mode, as iOS 26.5's
/// SpringBoard resizes one. Its top left corner stays put while its other
/// corner follows the finger, a point beyond it, kept within the shape the
/// corners of its sizes make and pulled only a little past it.
///
/// Once the finger has moved 20 points from where it touched, the widget
/// heads for whichever of its other sizes has its corner nearest, and how far
/// the finger has come from where it started toward that corner fades the
/// content from one size's to the other's. Past halfway, the other icons make
/// room for the new size; at 95% the widget takes that size, and heads on
/// from its corner. Let go, it settles at the size the icons made room for.
struct HomeWidgetResize: Equatable {
    let item: HomeItem
    let id: String
    /// Its size when its handle was picked up.
    let originalSize: HomeWidgetSize
    /// Its top left corner on the page, which stays where it is.
    let origin: CGPoint
    /// The sizes it can take, smallest first, and their frames' sizes.
    let sizes: [HomeWidgetSize]
    let frameSizes: [HomeWidgetSize: CGSize]
    /// The widget's corner radius, the same at every size.
    let cornerRadius: Double
    /// Where the corner may go: the shape the sizes' corner points make.
    let path: [CGPoint]

    /// Where the finger's progress is measured from: where it first touched,
    /// then the corner point of each size the widget takes on the way.
    var anchor: CGPoint
    /// Whether the finger has gone far enough to head for another size.
    var isHeadingForSize = false
    /// The size whose content shows in front, which the widget comes from.
    var fromSize: HomeWidgetSize
    /// The size it's heading for, whose content shows behind, or nil.
    var toSize: HomeWidgetSize?
    /// How far along it is from `fromSize` to `toSize`, from 0 to 1, as its
    /// content shows it.
    var progress = 0.0
    /// Its frame on the page, following the finger.
    var frame: CGRect
    /// The size the other icons make room for.
    var size: HomeWidgetSize
    /// Whether it's been let go and is settling into its place.
    var isSettling = false

    /// Picks up the widget `widget`, at `frame` on its page, by its handle,
    /// where the finger touched at `start`. A widget with only one size
    /// can't be resized.
    init?(item: HomeItem, id: String, widget: HomeWidget, frame: CGRect, start: CGPoint, metrics: HomeMetrics) {
        // A stack takes the sizes all its widgets come in.
        let offered = widget.kinds.reduce(Set(HomeWidgetSize.allCases)) { $0.intersection($1.sizes) }
        let sizes = HomeWidgetSize.allCases.filter { offered.contains($0) }.sorted { Self.area(of: $0) < Self.area(of: $1) }
        guard sizes.count > 1 else {
            return nil
        }
        let frameSizes = Dictionary(uniqueKeysWithValues: sizes.map { ($0, Self.frameSize($0, on: metrics)) })
        let cornerRadius = metrics.widgetCornerRadius
        self.item = item
        self.id = id
        originalSize = widget.size
        origin = frame.origin
        self.sizes = sizes
        self.frameSizes = frameSizes
        self.cornerRadius = cornerRadius
        self.frame = frame
        anchor = start
        fromSize = widget.size
        size = widget.size
        path = Self.path(around: sizes.map { Self.cornerPoint(of: frameSizes[$0] ?? .zero, at: frame.origin, cornerRadius: cornerRadius) })
    }

    /// The point a size's corner is grabbed by: where its rounding is
    /// halfway round, on the page.
    func cornerPoint(of size: HomeWidgetSize) -> CGPoint {
        Self.cornerPoint(of: frameSizes[size] ?? .zero, at: origin, cornerRadius: cornerRadius)
    }

    private static func cornerPoint(of frameSize: CGSize, at origin: CGPoint, cornerRadius: Double) -> CGPoint {
        let reach = cornerRadius * (1 - 0.5.squareRoot())
        return CGPoint(x: origin.x + frameSize.width - reach, y: origin.y + frameSize.height - reach)
    }

    /// Follows the finger at `finger`, on the page.
    mutating func follow(_ finger: CGPoint) {
        frame = frame(following: finger)
        if !isHeadingForSize, Self.distance(finger, anchor) >= HomeWidgetDesign.resizeStretchDistance {
            isHeadingForSize = true
        }
        if isHeadingForSize {
            headForSize(finger)
        }
    }

    /// Lets go: it settles at the size the icons made room for, in `frame`,
    /// its content coming into focus at that size.
    mutating func settle(into frame: CGRect) {
        self.frame = frame
        progress = size == toSize ? 1 : 0
        isSettling = true
    }

    /// The frame for the finger at `finger`: its corner a point beyond the
    /// finger, or beyond the nearest point of the corners' shape, pulled a
    /// little toward the finger, at most 20 points, the further the more.
    /// Smaller than the smallest size, it keeps that size's shape.
    private func frame(following finger: CGPoint) -> CGRect {
        var corner = finger
        if !Self.contains(path, finger) {
            let nearest = Self.nearestPoint(on: path, to: finger)
            let distance = Self.distance(finger, nearest)
            if distance > 0 {
                let limit = HomeWidgetDesign.resizeOvershootLimit
                let pull = limit * (1 - 1 / (0.55 * distance / limit + 1))
                corner = CGPoint(x: nearest.x + (finger.x - nearest.x) * pull / distance, y: nearest.y + (finger.y - nearest.y) * pull / distance)
            } else {
                corner = nearest
            }
        }
        let local = CGPoint(x: corner.x - origin.x, y: corner.y - origin.y)
        let reach = CGSize(width: max(1, local.x + 1) - min(0, local.x), height: max(1, local.y + 1) - min(0, local.y))
        var shown = reach
        if sizes.count >= 3, let smallest = frameSizes[sizes[0]], smallest.width >= reach.width, smallest.height >= reach.height {
            shown.height = smallest.width / smallest.height * reach.width
        }
        return CGRect(
            x: origin.x + (reach.width - shown.width) / 2,
            y: origin.y + (reach.height - shown.height) / 2,
            width: shown.width,
            height: shown.height
        )
    }

    /// Heads for the size whose corner is nearest the finger, other than the
    /// one it's coming from: how far along it is, which size the icons make
    /// room for, and whether it has arrived.
    private mutating func headForSize(_ finger: CGPoint) {
        let near = Self.contains(path, finger) ? finger : Self.nearestPoint(on: path, to: finger)
        var best: (size: HomeWidgetSize, distance: Double)?
        for candidate in sizes where candidate != fromSize {
            let distance = Self.distance(near, cornerPoint(of: candidate))
            if best == nil || distance < best!.distance {
                best = (candidate, distance)
            }
        }
        guard let best else {
            toSize = nil
            progress = 0
            return
        }
        let target = cornerPoint(of: best.size)
        let toward = CGPoint(x: target.x - anchor.x, y: target.y - anchor.y)
        let length = toward.x * toward.x + toward.y * toward.y
        let along = length > 0 ? min(max(((near.x - anchor.x) * toward.x + (near.y - anchor.y) * toward.y) / length, 0), 1) : 1
        toSize = best.size
        size = along > 0.5 ? best.size : fromSize
        if along >= HomeWidgetDesign.resizeArrival {
            fromSize = best.size
            toSize = nil
            progress = 0
            anchor = target
        } else if along < HomeWidgetDesign.resizeDeparture {
            toSize = nil
            progress = 0
        } else {
            progress = min(max((along - HomeWidgetDesign.resizeDeparture) / (HomeWidgetDesign.resizeArrival - HomeWidgetDesign.resizeDeparture), 0), 1)
        }
    }

    /// What the widget shows now.
    var look: HomeWidgetResizeLook {
        HomeWidgetResizeLook(from: fromSize, to: toSize, progress: progress)
    }

    /// A widget's frame at a size, on a page with widgets.
    static func frameSize(_ size: HomeWidgetSize, on metrics: HomeMetrics) -> CGSize {
        metrics.forWidgetPage.widgetFrame(origin: 0, span: size.span).size
    }

    /// How many of iOS's app places a size takes, which orders the sizes.
    private static func area(of size: HomeWidgetSize) -> Int {
        switch size {
        case .small:
            4
        case .medium:
            8
        case .large:
            16
        }
    }

    // MARK: Geometry

    /// The shape the corner may move in, as SpringBoard makes it: around
    /// three or more corner points, the smallest shape holding them all; for
    /// two, a band 10 points either side of the line between them.
    private static func path(around points: [CGPoint]) -> [CGPoint] {
        if points.count >= 3 {
            return convexHull(points)
        }
        guard points.count == 2 else {
            return points
        }
        let (start, end) = (points[0], points[1])
        let dx = end.x - start.x
        let dy = end.y - start.y
        let half = HomeWidgetDesign.resizeBandHalfWidth
        let offset: CGPoint
        if dx == 0 {
            offset = CGPoint(x: half, y: 0)
        } else if dy == 0 {
            offset = CGPoint(x: 0, y: half)
        } else {
            let angle = atan(dy / dx)
            offset = CGPoint(x: half * cos(angle), y: half * sin(angle))
        }
        return [
            CGPoint(x: start.x + offset.x, y: start.y - offset.y),
            CGPoint(x: end.x + offset.x, y: end.y - offset.y),
            CGPoint(x: end.x - offset.x, y: end.y + offset.y),
            CGPoint(x: start.x - offset.x, y: start.y + offset.y),
        ]
    }

    /// The smallest convex shape holding `points`, going round it.
    private static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> Double {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        var lower: [CGPoint] = []
        for point in sorted {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 {
                lower.removeLast()
            }
            lower.append(point)
        }
        var upper: [CGPoint] = []
        for point in sorted.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 {
                upper.removeLast()
            }
            upper.append(point)
        }
        return Array(lower.dropLast() + upper.dropLast())
    }

    /// Whether `point` is inside `polygon`, by the even-odd rule.
    private static func contains(_ polygon: [CGPoint], _ point: CGPoint) -> Bool {
        guard polygon.count >= 3 else {
            return false
        }
        var inside = false
        var previous = polygon[polygon.count - 1]
        for current in polygon {
            if (current.y > point.y) != (previous.y > point.y),
               point.x < (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x {
                inside.toggle()
            }
            previous = current
        }
        return inside
    }

    /// The point on `polygon`'s edge nearest `point`.
    private static func nearestPoint(on polygon: [CGPoint], to point: CGPoint) -> CGPoint {
        guard var previous = polygon.last else {
            return point
        }
        var best = previous
        var bestDistance = Double.infinity
        for current in polygon {
            let dx = current.x - previous.x
            let dy = current.y - previous.y
            let length = dx * dx + dy * dy
            let along = length > 0 ? min(max(((point.x - previous.x) * dx + (point.y - previous.y) * dy) / length, 0), 1) : 0
            let candidate = CGPoint(x: previous.x + along * dx, y: previous.y + along * dy)
            let distance = distance(point, candidate)
            if distance < bestDistance {
                best = candidate
                bestDistance = distance
            }
            previous = current
        }
        return best
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }
}

/// What a widget being resized shows at a moment, as SpringBoard draws it:
/// its content laid out at the size it's coming from, in front, and at the
/// size it's heading for, behind, each stretched to the widget's frame.
struct HomeWidgetResizeLook: Equatable {
    /// The size whose content shows in front.
    var from: HomeWidgetSize
    /// The size it's heading for, whose content shows behind, or nil.
    var to: HomeWidgetSize?
    /// How far it is from `from` to `to`, from 0 to 1: the front content
    /// fades out and blurs by it, and the one behind comes into focus.
    var progress: Double
}
