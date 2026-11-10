//
//  HomeWidget.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A widget on the Home Screen: one of iOS's own, which zContainer draws the
/// way iOS does, at one of the sizes iOS offers, or a stack of them, which
/// swipes from one to the next as iOS's Smart Stack does. The layout saves it
/// in its `widgets`, by the id its HomeItem carries.
struct HomeWidget: Codable, Equatable, Sendable {
    /// How big it is.
    var size: HomeWidgetSize
    /// The widgets, top first. More than one makes a stack.
    var kinds: [HomeWidgetKind]

    /// Whether it's a stack of widgets rather than one.
    var isStack: Bool {
        kinds.count > 1
    }
}

/// The sizes iOS offers widgets in.
enum HomeWidgetSize: String, Codable, CaseIterable, Sendable {
    case small
    case medium
    case large

    /// How many of the page's places it takes, across and down. On iPhone a
    /// small widget takes four apps' places, two by two, as on iOS; an iPad
    /// widget page's places are bigger, and a small widget takes one.
    var span: (columns: Int, rows: Int) {
        switch (self, SharedModel.isPhone) {
        case (.small, true):
            (2, 2)
        case (.medium, true):
            (4, 2)
        case (.large, true):
            (4, 4)
        case (.small, false):
            (1, 1)
        case (.medium, false):
            (2, 1)
        case (.large, false):
            (2, 2)
        }
    }

    /// How many places it takes.
    var cellCount: Int {
        span.columns * span.rows
    }
}

/// The widgets zContainer draws: iOS's own, from the apps iOS's Home Screen
/// starts with them for.
enum HomeWidgetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Calendar's Up Next: the day, the date and what's on.
    case calendar
    /// Maps' map of where you are.
    case maps
    /// News' Today: the top stories.
    case news
    /// Photos' featured photos.
    case photos
    /// Reminders' list.
    case reminders

    var id: Self {
        self
    }

    /// The app's name, which shows under the widget on iPhone and in the
    /// widget gallery.
    var title: String {
        switch self {
        case .calendar:
            "zc.widget.calendar".loc
        case .maps:
            "zc.widget.maps".loc
        case .news:
            "zc.widget.news".loc
        case .photos:
            "zc.widget.photos".loc
        case .reminders:
            "zc.widget.reminders".loc
        }
    }

    /// The widget's own name, as the widget gallery shows it under the app's.
    var widgetTitle: String {
        switch self {
        case .calendar:
            "zc.widget.calendar.upNext".loc
        case .maps:
            "zc.widget.maps.map".loc
        case .news:
            "zc.widget.news.today".loc
        case .photos:
            "zc.widget.photos.featured".loc
        case .reminders:
            "zc.widget.reminders.list".loc
        }
    }

    /// What the widget shows, as the widget gallery says under its name.
    var detail: String {
        switch self {
        case .calendar:
            "zc.widget.calendar.detail".loc
        case .maps:
            "zc.widget.maps.detail".loc
        case .news:
            "zc.widget.news.detail".loc
        case .photos:
            "zc.widget.photos.detail".loc
        case .reminders:
            "zc.widget.reminders.detail".loc
        }
    }

    /// The sizes the widget comes in, as iOS offers it.
    var sizes: [HomeWidgetSize] {
        HomeWidgetSize.allCases
    }
}

extension HomeWidget {
    /// The widgets iOS 26.5's Home Screen starts with on its first page, in
    /// order: on iPhone, Maps and a stack of Calendar, News and Photos, both
    /// small; on iPad, as SpringBoard lays them out, a large stack of News,
    /// Maps and Photos and a large Reminders, then a medium Calendar beside
    /// a large one, and a medium Maps under the medium Calendar.
    static var firstPageDefaults: [HomeWidget] {
        if SharedModel.isPhone {
            [
                HomeWidget(size: .small, kinds: [.maps]),
                HomeWidget(size: .small, kinds: [.calendar, .news, .photos]),
            ]
        } else {
            [
                HomeWidget(size: .large, kinds: [.news, .maps, .photos]),
                HomeWidget(size: .large, kinds: [.reminders]),
                HomeWidget(size: .medium, kinds: [.calendar]),
                HomeWidget(size: .large, kinds: [.calendar]),
                HomeWidget(size: .medium, kinds: [.maps]),
            ]
        }
    }
}
