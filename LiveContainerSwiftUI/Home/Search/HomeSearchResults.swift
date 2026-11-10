//
//  HomeSearchResults.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// What search found for the text typed: the Top Hit and the other apps, as
/// Spotlight lays them out, or that nothing matched.
struct HomeSearchResults: View {
    /// The apps found, the best match first.
    let apps: [LCAppModel]
    /// What was searched for.
    let query: String
    /// How many apps a panel row holds.
    let columns: Int
    /// Where things go on this screen, for the icons' size.
    let metrics: HomeMetrics

    var body: some View {
        if !apps.isEmpty {
            HomeSearchFoundApps(apps: apps, columns: columns, metrics: metrics)
        } else {
            ContentUnavailableView.search(text: query)
        }
    }
}
