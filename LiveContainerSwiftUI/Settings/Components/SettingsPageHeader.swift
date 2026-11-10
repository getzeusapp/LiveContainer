//
//  SettingsPageHeader.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The card at the top of a page of Settings, as the Settings app has at the
/// top of General and of each app's page: the page's icon, large, its name in
/// bold and, under it in gray, what the page is for. The icon keeps its size
/// whatever the text size, as an app's icon does.
struct SettingsPageHeader<Icon: View>: View {
    /// The page's name and what it's for, already localized.
    let title: String
    let detail: String
    /// The page's icon, `SettingsDesign.pageHeaderIconSize` points square.
    @ViewBuilder let icon: Icon

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 0) {
                icon
                    .dynamicTypeSize(.large)
                    .padding(.bottom, SettingsDesign.pageHeaderIconSpacing)
                Text(title)
                    .font(.title2.bold())
                    .padding(.bottom, SettingsDesign.pageHeaderTitleSpacing)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .listRowInsets(SettingsDesign.pageHeaderInsets)
        }
    }
}

extension SettingsPageHeader where Icon == SettingsIcon {
    /// The card at the top of one of Settings' own pages, with the icon of
    /// its row.
    init(page: SettingsPage, detail: String) {
        let icon = page.rowIcon
        self.init(title: page.title, detail: detail) {
            SettingsIcon(systemImage: icon?.systemImage ?? "gear", color: icon?.color ?? .gray, graphicIcon: icon?.graphicIcon, size: SettingsDesign.pageHeaderIconSize)
        }
    }
}

extension SettingsPageHeader where Icon == SettingsAppIcon {
    /// The card at the top of an app's page, with the app's icon.
    init(app: LCAppModel) {
        self.init(title: app.displayName, detail: String(format: "zc.settings.app.detail".loc, app.displayName)) {
            SettingsAppIcon(app: app, size: SettingsDesign.pageHeaderIconSize)
        }
    }
}
