//
//  SettingsSearchResults.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What Settings' list shows while something is typed into its search field:
/// the pages, settings and apps whose names hold it, each opening its page,
/// with its page's icon and, for a setting or an app, the page it's on under
/// its name, as the Settings app lists its search results.
struct SettingsSearchResults: View {
    /// What's typed.
    let query: String

    @EnvironmentObject private var sharedModel: SharedModel

    var body: some View {
        let results = SettingsSearch.results(for: query, apps: sharedModel.apps)

        if results.isEmpty {
            Section {
                ContentUnavailableView.search(text: query)
            }
            .listRowBackground(Color.clear)
        } else {
            Section {
                ForEach(results) { item in
                    SettingsPageLink(page: item.page) {
                        SettingsSearchRow(item: item)
                    }
                }
            }
        }
    }
}

/// One search result: its icon, its name and the page it's on.
private struct SettingsSearchRow: View {
    let item: SettingsSearchItem

    @EnvironmentObject private var sharedModel: SharedModel

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: SettingsDesign.subtitleSpacing) {
                Text(item.title)
                if let location = item.location {
                    Text(location)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            icon
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch item.page {
        case .zeus, .attention:
            ZeusMark(size: SettingsDesign.iconSize)
        case .app(let key):
            if let app = sharedModel.apps.first(where: { $0.homeKey == key }) {
                SettingsAppIcon(app: app)
            }
        default:
            if let icon = item.page.rowIcon {
                SettingsIcon(systemImage: icon.systemImage, color: icon.color, graphicIcon: icon.graphicIcon)
            }
        }
    }
}
