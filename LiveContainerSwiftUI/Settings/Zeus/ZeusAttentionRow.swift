//
//  ZeusAttentionRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The row under the Zeus card when zContainer can't sign apps, like "Finish
/// Setting Up Your iPhone" under the Apple Account in the Settings app: what
/// is wrong, and a red badge with a 1.
struct ZeusAttentionRow: View {
    /// What is wrong.
    let attention: ZeusAttention
    /// Whether the row draws the chevron of a row that opens a page, for a
    /// button that opens one itself. A navigation link's row gets it from
    /// the list.
    var showsChevron = false

    var body: some View {
        // The badge keeps to the trailing edge, and a title too long for a
        // narrow sidebar wraps beside it rather than pushing it under.
        HStack {
            Text(attention.title)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            SettingsBadge(count: 1)
                .accessibilityHidden(true)

            if showsChevron {
                // The weight of the chevron the list draws on rows that open a page.
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
    }
}
