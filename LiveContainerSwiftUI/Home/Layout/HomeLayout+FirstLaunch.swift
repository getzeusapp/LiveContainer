//
//  HomeLayout+FirstLaunch.swift
//  LiveContainerSwiftUI
//

import Foundation

extension HomeLayout {
    /// The layout the Home Screen starts with when none is saved: Settings in
    /// the dock, the widgets iOS's Home Screen starts with at the top of the
    /// first page, and the apps on the pages in LiveContainer's custom order
    /// when one was saved, then in the order they were installed.
    @MainActor
    static func firstLaunch(apps: [LCAppModel], customOrder: [String]) -> HomeLayout {
        var layout = HomeLayout()
        for widget in HomeWidget.firstPageDefaults.reversed() {
            layout.addWidget(widget, toPage: 0)
        }
        for key in firstLaunchOrder(of: apps, customOrder: customOrder) {
            layout.append(.app(key))
        }
        return layout
    }

    /// The apps' keys in first-launch order: those in the custom order first,
    /// as it lists them, then the rest from the oldest install to the newest.
    /// Apps without an install date come first among the rest, by name, since
    /// they were installed before LiveContainer recorded the date.
    @MainActor
    private static func firstLaunchOrder(of apps: [LCAppModel], customOrder: [String]) -> [String] {
        var remaining: [String: LCAppModel] = [:]
        for app in apps {
            if let key = app.homeKey, remaining[key] == nil {
                remaining[key] = app
            }
        }

        var order: [String] = []
        for key in customOrder where remaining.removeValue(forKey: key) != nil {
            order.append(key)
        }

        let rest = remaining.values.sorted { first, second in
            switch (first.appInfo.installationDate, second.appInfo.installationDate) {
            case let (firstDate?, secondDate?):
                firstDate < secondDate
            case (nil, _?):
                true
            case (_?, nil):
                false
            case (nil, nil):
                first.displayName.localizedStandardCompare(second.displayName) == .orderedAscending
            }
        }
        order += rest.compactMap(\.homeKey)
        return order
    }
}
