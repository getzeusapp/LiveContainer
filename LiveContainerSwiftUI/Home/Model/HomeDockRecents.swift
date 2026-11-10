//
//  HomeDockRecents.swift
//  LiveContainerSwiftUI
//

import Foundation

/// The recent apps the iPad's dock shows after the person's icons, kept the
/// way iPadOS 26.5's SBFloatingDockSuggestionsModel keeps them, as measured
/// in its Simulator: up to three, of the apps opened that aren't in the dock.
/// While there are fewer than three, an app opened goes in first, next to
/// the divider. Once there are three, it takes the place of the one opened
/// longest ago, and the others stay where they are. Opening one that's there
/// already moves nothing. HomeLayoutStorage saves them, as zContainer quits
/// on the way into an app.
struct HomeDockRecents: Codable, Equatable {
    /// The recent apps in the dock's order, with when each was last opened.
    private(set) var entries: [Entry] = []

    /// A recent app, and when it was last opened.
    struct Entry: Codable, Equatable {
        var item: HomeItem
        var opened: Date
    }

    /// How many recent apps the dock shows at most, as on iPadOS.
    static let capacity = 3

    /// The defaults key of whether the dock shows recent apps, as iPadOS's
    /// Show Suggested and Recent Apps in Dock does. It's on until it's turned
    /// off in Settings > Appearance.
    static let settingKey = "ZCDockShowsRecents"

    /// Whether the dock shows recent apps: on an iPad, unless it's been
    /// turned off.
    static var isEnabled: Bool {
        !SharedModel.isPhone && UserDefaults.standard.object(forKey: settingKey) as? Bool ?? true
    }

    /// The recent apps, in the dock's order.
    var items: [HomeItem] {
        entries.map(\.item)
    }

    /// Notes that `item` was opened at `date`. Apps no longer worth showing,
    /// for which `isShowable` is false, such as those that went into the
    /// dock, leave first, so the app takes a free place before it takes
    /// another app's.
    mutating func noteOpened(_ item: HomeItem, at date: Date = .now, isShowable: (HomeItem) -> Bool) {
        entries.removeAll { !isShowable($0.item) }
        guard isShowable(item) else {
            return
        }
        if let index = entries.firstIndex(where: { $0.item == item }) {
            entries[index].opened = date
        } else if entries.count < Self.capacity {
            entries.insert(Entry(item: item, opened: date), at: 0)
        } else if let oldest = entries.indices.min(by: { entries[$0].opened < entries[$1].opened }) {
            entries[oldest] = Entry(item: item, opened: date)
        }
    }

    /// The recent apps opened most recently according to `opened`, most
    /// recent first, as the dock would have them had it seen them opened in
    /// turn: for the first time recent apps show, from the times apps were
    /// last opened.
    static func seeded(from opened: [(item: HomeItem, date: Date)]) -> HomeDockRecents {
        var recents = HomeDockRecents()
        recents.entries = opened
            .sorted { $0.date > $1.date }
            .prefix(capacity)
            .map { Entry(item: $0.item, opened: $0.date) }
        return recents
    }
}
