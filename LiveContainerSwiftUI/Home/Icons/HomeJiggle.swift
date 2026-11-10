//
//  HomeJiggle.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The wobble icons make in edit mode, as SpringBoard makes it: three
/// motions at once, each back and forth at its own pace, easing in and out
/// at each end: a tilt around the icon's center, a shift across and a shift
/// up and down. Each icon starts each motion at its own point, so no two
/// move in step. When edit mode ends, the icon eases back to rest. The
/// whole icon moves as one, its glass, name and badge with it.
struct HomeJiggle: ViewModifier {
    /// Whether the icon jiggles. It comes to rest when this turns false.
    let isActive: Bool
    /// Picks where in each motion the icon starts. It is 0 or more.
    let seed: Int
    /// How far it tilts, as a fraction of an icon's tilt: less for a widget.
    var strength = 1.0
    /// The point it tilts around: its icon's center, or a widget's.
    var anchor = UnitPoint.center

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isActive)) { timeline in
            let motion = isActive
                ? HomeJiggleMotion(time: timeline.date.timeIntervalSinceReferenceDate, seed: seed, strength: strength)
                : .rest
            // Only the motion's own change back to rest animates, not every
            // step while it jiggles, nor anything else in the icon.
            content.animation(isActive ? nil : HomeDesign.jiggleSettle) { icon in
                icon
                    .rotationEffect(.radians(motion.tilt), anchor: anchor)
                    .offset(x: motion.x, y: motion.y)
            }
        }
    }
}

/// Where a jiggling icon is at a moment: how far it's tilted and shifted.
struct HomeJiggleMotion: Equatable {
    /// The tilt, in radians.
    var tilt: Double
    /// The shift across and down, in points.
    var x: Double
    var y: Double

    /// Level and in its place.
    static let rest = HomeJiggleMotion(tilt: 0, x: 0, y: 0)

    init(tilt: Double, x: Double, y: Double) {
        self.tilt = tilt
        self.x = x
        self.y = y
    }

    /// Where an icon is at `time`, in seconds. As in SpringBoard, the tilt
    /// starts from one side and the shifts from the other, each at a point
    /// up to a second into its swing that `seed` picks.
    init(time: TimeInterval, seed: Int, strength: Double) {
        tilt = -HomeDesign.jiggleTilt * strength * Self.swing(time + Self.start(seed, motion: 0), oneWay: HomeDesign.jiggleTiltDuration)
        x = HomeDesign.jiggleShift * Self.swing(time + Self.start(seed, motion: 1), oneWay: HomeDesign.jiggleShiftXDuration)
        y = HomeDesign.jiggleShift * Self.swing(time + Self.start(seed, motion: 2), oneWay: HomeDesign.jiggleShiftYDuration)
    }

    /// From 1 to -1 and back, taking `oneWay` seconds each way, easing in
    /// and out at each end.
    private static func swing(_ time: Double, oneWay: Double) -> Double {
        let cycle = (time / oneWay).truncatingRemainder(dividingBy: 2)
        if cycle < 1 {
            return 1 - 2 * HomeDesign.jiggleCurve.value(at: cycle)
        }
        return -1 + 2 * HomeDesign.jiggleCurve.value(at: cycle - 1)
    }

    /// How far into a motion an icon starts, in hundredths of a second up
    /// to 0.99, as SpringBoard picks it, the same for an icon each time.
    private static func start(_ seed: Int, motion: UInt64) -> Double {
        var hash = UInt64(truncatingIfNeeded: seed) &* 0x9E37_79B9_7F4A_7C15 &+ (motion &+ 1) &* 0xBF58_476D_1CE4_E5B9
        hash ^= hash >> 31
        hash = hash &* 0x94D0_49BB_1331_11EB
        hash ^= hash >> 29
        return Double(hash % 100) / 100
    }
}

extension View {
    /// Makes the view jiggle like a Home Screen icon in edit mode while
    /// `isActive` is true, tilting around `anchor`.
    func homeJiggle(isActive: Bool, seed: Int, strength: Double = 1, anchor: UnitPoint = .center) -> some View {
        modifier(HomeJiggle(isActive: isActive, seed: seed, strength: strength, anchor: anchor))
    }
}
