//
//  HomeCalendarEvents.swift
//  LiveContainerSwiftUI
//

import EventKit
import SwiftUI

/// The events the Calendar widget shows, once zContainer may read the
/// calendars: today's, all-day events first, as Calendar's widget lists them,
/// holidays and birthdays among them, then the rest from now on; and those of
/// the week ahead, day by day, which Up Next shows beside today's. The
/// widget asks for access when it first shows, as iOS asks before a widget
/// reads something of yours.
@MainActor
@Observable
final class HomeCalendarEvents {
    static let shared = HomeCalendarEvents()

    struct Event: Identifiable, Equatable {
        let id: String
        let title: String
        let isAllDay: Bool
        let start: Date
        let end: Date
        let color: Color
        /// The symbol iOS puts before a holiday or a birthday, or nil.
        let symbol: String?
    }

    /// A later day and its events.
    struct Day: Identifiable, Equatable {
        let date: Date
        let events: [Event]

        var id: Date {
            date
        }
    }

    /// Today's events not yet over, or none while zContainer may not read
    /// the calendars.
    private(set) var events: [Event] = []
    /// Today's events with a time, ended or not, for the large widget's day.
    private(set) var todaysTimed: [Event] = []
    /// The days of the week ahead that have events, soonest first.
    private(set) var upcoming: [Day] = []
    /// Tomorrow's events.
    private(set) var tomorrow: [Event] = []

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var observer: (any NSObjectProtocol)?
    @ObservationIgnored private var loadedMinute: Date?

    /// How many days ahead Up Next looks.
    private static let daysAhead = 7

    /// Whether zContainer may ask to read the calendars, which it hasn't yet.
    var canAsk: Bool {
        EKEventStore.authorizationStatus(for: .event) == .notDetermined
    }

    /// Asks to read the calendars, then shows today's events.
    func requestAccess() async {
        guard (try? await store.requestFullAccessToEvents()) == true else {
            return
        }
        loadedMinute = nil
        refresh(for: .now)
    }

    /// Reads the events from now on, once a minute at most, so ones that
    /// have ended go, and again whenever the calendars change.
    func refresh(for date: Date) {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            return
        }
        let calendar = Calendar.current
        let minute = calendar.dateInterval(of: .minute, for: date)?.start ?? date
        guard minute != loadedMinute else {
            return
        }
        loadedMinute = minute
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.loadedMinute = nil
                    self?.refresh(for: .now)
                }
            }
        }
        let today = calendar.startOfDay(for: date)
        guard let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: today),
              let end = calendar.date(byAdding: .day, value: Self.daysAhead + 1, to: today) else {
            return
        }
        let predicate = store.predicateForEvents(withStart: today, end: end, calendars: nil)
        let all = store.events(matching: predicate)
            .sorted { first, second in
                first.isAllDay != second.isAllDay ? first.isAllDay : first.startDate < second.startDate
            }
            .map(Self.event)

        let todays = all.filter { $0.start < tomorrowStart && $0.end > today }
        let new = todays.filter { $0.isAllDay || $0.end > date }
        if new != events {
            events = new
        }
        let timed = todays.filter { !$0.isAllDay }
        if timed != todaysTimed {
            todaysTimed = timed
        }

        var days: [Day] = []
        for offset in 1...Self.daysAhead {
            guard let start = calendar.date(byAdding: .day, value: offset, to: today),
                  let next = calendar.date(byAdding: .day, value: 1, to: start) else {
                continue
            }
            // An event that started earlier and goes on into a later day
            // counts on the day it starts, as Up Next lists it.
            let dayEvents = all.filter { event in
                event.start >= start && event.start < next
                    || event.isAllDay && event.start < start && event.end > start && offset == 1
            }
            if !dayEvents.isEmpty {
                days.append(Day(date: start, events: dayEvents))
            }
        }
        if days != upcoming {
            upcoming = days
        }
        let tomorrows = all.filter { $0.start < (calendar.date(byAdding: .day, value: 1, to: tomorrowStart) ?? end) && $0.end > tomorrowStart }
        if tomorrows != tomorrow {
            tomorrow = tomorrows
        }
    }

    private static func event(_ event: EKEvent) -> Event {
        Event(
            id: event.calendarItemIdentifier + "\(event.startDate.timeIntervalSince1970)",
            title: event.title ?? "",
            isAllDay: event.isAllDay,
            start: event.startDate,
            end: event.endDate,
            color: Color(cgColor: event.calendar.cgColor),
            symbol: symbol(for: event)
        )
    }

    /// The star iOS puts before a holiday, and the gift before a birthday.
    private static func symbol(for event: EKEvent) -> String? {
        switch event.calendar.type {
        case .birthday:
            "gift.circle.fill"
        case .subscription where event.isAllDay:
            "star.circle.fill"
        default:
            nil
        }
    }
}
