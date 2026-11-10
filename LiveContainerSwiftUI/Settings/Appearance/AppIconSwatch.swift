//
//  AppIconSwatch.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// One of zContainer's icons in Settings > Appearance: a picture of it,
/// rounded the way the Home Screen rounds icons, with its name under it, ringed
/// in the accent color when it's the one in use.
struct AppIconSwatch: View {
    let choice: AppIconChoice
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var size = 56.0

    /// How round the Home Screen draws an icon's corners, for its width.
    private static let cornerRatio = HomeDesign.iconCornerFraction
    /// How thick the ring around the icon in use is.
    private static let ring = 2.5

    var body: some View {
        let corner = size * Self.cornerRatio

        Button(action: action) {
            VStack(spacing: 6) {
                // The picture keeps its size, and the ring shows around it with
                // a gap, so choosing one doesn't make it jump.
                AppIconPreview(name: choice.previewImageName)
                    .frame(width: size, height: size)
                    .clipShape(.rect(cornerRadius: corner, style: .continuous))
                    .padding(Self.ring * 2)
                    .overlay {
                        RoundedRectangle(cornerRadius: corner + Self.ring * 2, style: .continuous)
                            .strokeBorder(.tint, lineWidth: Self.ring)
                            .opacity(isSelected ? 1 : 0)
                    }

                Text(choice.title)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(choice.title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
