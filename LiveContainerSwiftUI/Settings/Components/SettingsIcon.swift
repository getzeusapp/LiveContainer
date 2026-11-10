//
//  SettingsIcon.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The icon beside a row of Settings: the Settings app's own for the same
/// thing, where `graphicIcon` names one and the system draws it, and
/// otherwise a white symbol on a rounded square of color, shaded lighter at
/// the top, as the Settings app draws them. It grows with the text size.
struct SettingsIcon: View {
    /// The SF Symbol drawn on the tile.
    let systemImage: String
    /// The tile's color.
    let color: Color
    /// The Settings app's icon for the same thing, as an IconServices graphic
    /// icon type, such as com.apple.graphic-icon.gear.
    let graphicIcon: String?

    @ScaledMetric private var size: Double

    /// An icon `size` points square at the default text size: a row's, unless
    /// it's the larger one at the top of a page.
    init(systemImage: String, color: Color, graphicIcon: String? = nil, size: Double = SettingsDesign.iconSize) {
        self.systemImage = systemImage
        self.color = color
        self.graphicIcon = graphicIcon
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        let key = graphicIcon.map { SettingsGraphicIcons.Key(type: $0, size: size) }

        Group {
            if let key, let image = SettingsGraphicIcons.shared.image(key) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: size, height: size)
                    .accessibilityHidden(true)
            } else {
                tile
            }
        }
        .task(id: key) {
            if let key {
                await SettingsGraphicIcons.shared.load(key)
            }
        }
    }

    /// The symbol on its tile.
    @ViewBuilder
    private var tile: some View {
        let tile = RoundedRectangle(cornerRadius: size * SettingsDesign.iconCornerRatio)

        Image(systemName: systemImage)
            .font(.system(size: size * SettingsDesign.glyphRatio, weight: .medium))
            // Not the larger scale a list gives the icons of its labels.
            .imageScale(.medium)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background {
                tile
                    .fill(color)
                    .overlay {
                        tile.fill(LinearGradient(
                            stops: [
                                .init(color: .white.opacity(SettingsDesign.iconSheen), location: 0),
                                .init(color: .white.opacity(0), location: SettingsDesign.iconSheenEnd),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                    }
            }
            .accessibilityHidden(true)
    }
}
