//
//  HomeSettingsArtwork.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// zContainer's Settings icon: the iOS Settings app's own icon, light or dark
/// as apps' icons are, from HomeSystemSettingsIcon. Until that's ready, or
/// where the Settings app can't be read, it's drawn in the same style: a
/// silver tile with a dark, finely toothed gear, a light ring inside it, and
/// a wheel of three spokes around the hub, turning near black with a light
/// gray gear in its dark version.
struct HomeSettingsArtwork: View {
    /// The icon's width and height.
    let size: Double
    /// The icon's corner radius.
    let cornerRadius: Double

    @Environment(\.prefersDarkAppIcons) private var isDark

    /// How many teeth the gear has.
    private static let teeth = 36

    var body: some View {
        Group {
            if let icon = HomeSystemSettingsIcon.shared.image(isDark: isDark) {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                drawnIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .homeIconRim(cornerRadius: cornerRadius)
        .accessibilityHidden(true)
        .task {
            HomeSystemSettingsIcon.shared.load()
        }
    }

    /// The stand-in, drawn in the Settings icon's style.
    private var drawnIcon: some View {
        Canvas { context, canvasSize in
            let side = canvasSize.width
            let center = CGPoint(x: side / 2, y: side / 2)
            // The gear and the spokes, and the rings between them.
            let dark = isDark
                ? Gradient(colors: [Color(white: 0.78), Color(white: 0.56)])
                : Gradient(colors: [Color(white: 0.36), Color(white: 0.17)])
            let light = isDark
                ? Gradient(colors: [Color(white: 0.2), Color(white: 0.09)])
                : Gradient(colors: [Color(white: 0.93), Color(white: 0.7)])
            let top = CGPoint(x: side / 2, y: side * 0.08)
            let bottom = CGPoint(x: side / 2, y: side * 0.92)

            context.fill(
                Self.gear(center: center, outerRadius: side * 0.43, innerRadius: side * 0.385),
                with: .linearGradient(dark, startPoint: top, endPoint: bottom)
            )
            context.fill(Self.circle(center: center, radius: side * 0.335), with: .linearGradient(light, startPoint: top, endPoint: bottom))
            context.fill(Self.circle(center: center, radius: side * 0.3), with: .linearGradient(dark, startPoint: top, endPoint: bottom))
            context.fill(Self.circle(center: center, radius: side * 0.258), with: .linearGradient(light, startPoint: bottom, endPoint: top))

            for angle in [-90.0, 30.0, 150.0] {
                context.fill(
                    Self.spoke(center: center, angle: angle, length: side * 0.27, width: side * 0.075),
                    with: .linearGradient(dark, startPoint: top, endPoint: bottom)
                )
            }
            context.fill(Self.circle(center: center, radius: side * 0.1), with: .linearGradient(dark, startPoint: top, endPoint: bottom))
            context.fill(Self.circle(center: center, radius: side * 0.04), with: .color(Color(white: isDark ? 0.22 : 0.78)))
        }
        .background(LinearGradient(colors: tile, startPoint: .top, endPoint: .bottom))
    }

    /// The tile's colors, from top to bottom.
    private var tile: [Color] {
        isDark ? [Color(white: 0.17), Color(white: 0.05)] : [Color(white: 0.87), Color(white: 0.6)]
    }

    /// A circle around `center`.
    private static func circle(center: CGPoint, radius: Double) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    /// The gear's outline: a disc whose edge rises into evenly spaced teeth
    /// with slightly narrower tips.
    private static func gear(center: CGPoint, outerRadius: Double, innerRadius: Double) -> Path {
        let step = 2 * Double.pi / Double(teeth)
        func point(_ angle: Double, _ radius: Double) -> CGPoint {
            CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        }
        var path = Path()
        for tooth in 0..<teeth {
            let middle = Double(tooth) * step - Double.pi / 2
            let corners = [
                point(middle - step * 0.3, innerRadius),
                point(middle - step * 0.18, outerRadius),
                point(middle + step * 0.18, outerRadius),
                point(middle + step * 0.3, innerRadius),
            ]
            if tooth == 0 {
                path.move(to: corners[0])
            } else {
                path.addLine(to: corners[0])
            }
            for corner in corners.dropFirst() {
                path.addLine(to: corner)
            }
        }
        path.closeSubpath()
        return path
    }

    /// A spoke from the hub out to the dark ring, pointing at `angle` degrees.
    private static func spoke(center: CGPoint, angle: Double, length: Double, width: Double) -> Path {
        Path(roundedRect: CGRect(x: 0, y: -width / 2, width: length, height: width), cornerRadius: width / 2)
            .applying(CGAffineTransform(rotationAngle: angle * .pi / 180))
            .applying(CGAffineTransform(translationX: center.x, y: center.y))
    }
}
