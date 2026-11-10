//
//  ZeusCard.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The card at the top of Settings, where the Settings app has the Apple
/// Account: Zeus's icon, "Zeus" in bold, and a line on the certificate Zeus
/// gave zContainer, its team and when it expires. When something is wrong,
/// the row under it says what. VoiceOver reads the card as one element. At
/// the largest text sizes the icon moves above the text, so the text gets
/// the row's whole width.
struct ZeusCard: View {
    @Environment(ZeusConnection.self) private var connection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SettingsDesign.headerSpacing))
            : AnyLayout(HStackLayout(spacing: SettingsDesign.cardSpacing))

        layout {
            ZeusMark(size: SettingsDesign.cardMarkSize)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            VStack(alignment: .leading, spacing: SettingsDesign.subtitleSpacing) {
                Text("zc.settings.zeus".loc)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.primary)

                Text(connection.summary)
                    .font(.subheadline)
                    .foregroundStyle(connection.isExpired ? Color.red : Color.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
