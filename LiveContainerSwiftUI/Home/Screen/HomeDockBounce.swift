//
//  HomeDockBounce.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The squash the iPad's dock gives when it can't take what's held over it,
/// as SpringBoardHome's -[SBFloatingDockView bounce] plays it on the glass:
/// two springs added to its scale, one taking 3% off it at once and one,
/// from 0.07 seconds on, putting it back, 0.98 seconds in all. Each time
/// `bounces` goes up by one, animated linearly over that time, it plays.
struct HomeDockBounce: ViewModifier, Animatable {
    /// How many times the dock has bounced, as it animates there.
    var bounces: Double
    /// The glass's center, which it shrinks toward.
    let anchor: UnitPoint

    var animatableData: Double {
        get { bounces }
        set { bounces = newValue }
    }

    func body(content: Content) -> some View {
        let time = (bounces - bounces.rounded(.down)) * Self.duration
        content.scaleEffect(Self.scale(at: time), anchor: anchor)
    }

    /// How long a bounce lasts: the second spring's start and length.
    static let duration = 0.98

    /// The glass's scale `time` seconds into a bounce. Each spring is a
    /// CASpringAnimation, added to the scale, that stops where it is once its
    /// duration is up: the first, with a mass of 3, a stiffness of 1560 and a
    /// damping of 600, after 0.4 seconds; the second, with a mass of 2, a
    /// stiffness of 300 and a damping of 400, after 0.91. Both stop counting
    /// at the end, as the animation group goes.
    static func scale(at time: Double) -> Double {
        guard time > 0, time < duration else {
            return 1
        }
        let squash = -0.03 * springProgress(mass: 3, stiffness: 1560, damping: 600, at: min(time, 0.4))
        let release = time < 0.07 ? 0 : 0.03 * springProgress(mass: 2, stiffness: 300, damping: 400, at: min(time - 0.07, 0.91))
        return 1 + squash + release
    }

    /// How far an overdamped spring at rest has gone toward its target,
    /// from 0 to 1, after `time` seconds, as Core Animation moves it.
    private static func springProgress(mass: Double, stiffness: Double, damping: Double, at time: Double) -> Double {
        let root = (damping * damping - 4 * mass * stiffness).squareRoot()
        let slow = (-damping + root) / (2 * mass)
        let fast = (-damping - root) / (2 * mass)
        return 1 + (fast * exp(slow * time) - slow * exp(fast * time)) / (slow - fast)
    }
}
