//
//  HomeReminders.swift
//  LiveContainerSwiftUI
//

import EventKit
import SwiftUI

/// The reminders the Reminders widget shows, once zContainer may read them:
/// tapping the widget asks, as the widget is the only thing that reads them.
/// It shows the list new reminders go into, as iOS's widget does until
/// another list is picked: its name and color, and the reminders not yet
/// done, oldest first, as the list keeps them. Checking one off in the widget
/// completes it in Reminders.
@MainActor
@Observable
final class HomeReminders {
    static let shared = HomeReminders()

    /// A reminder not yet done.
    struct Reminder: Identifiable, Equatable, Sendable {
        let id: String
        let title: String
        /// When it's due, and whether at a time of day rather than all day.
        let due: Date?
        let isDueAtTime: Bool
    }

    /// The list shown: its name and color.
    struct List: Equatable {
        let title: String
        let color: Color
    }

    /// The list shown, or nil while zContainer may not read reminders.
    private(set) var list: List?
    /// The list's reminders not yet done.
    private(set) var reminders: [Reminder] = []

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var observer: (any NSObjectProtocol)?
    @ObservationIgnored private var hasLoaded = false

    /// Whether zContainer may ask to read reminders, which it hasn't yet.
    var canAsk: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .notDetermined
    }

    private var isAllowed: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    /// Asks to read reminders, then shows them.
    func requestAccess() async {
        guard (try? await store.requestFullAccessToReminders()) == true else {
            return
        }
        hasLoaded = false
        load()
    }

    /// Reads the list once, then again whenever reminders change, in
    /// zContainer or in Reminders.
    func load() {
        guard isAllowed, !hasLoaded else {
            return
        }
        hasLoaded = true
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.reload()
                }
            }
        }
        reload()
    }

    private func reload() {
        guard let calendar = store.defaultCalendarForNewReminders() else {
            list = nil
            reminders = []
            return
        }
        list = List(title: calendar.title, color: Self.color(of: calendar))
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [calendar])
        store.fetchReminders(matching: predicate) { [weak self] found in
            let items = (found ?? [])
                .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
                .map { reminder in
                    let components = reminder.dueDateComponents
                    return Reminder(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "",
                        due: components.flatMap { Calendar.current.date(from: $0) },
                        isDueAtTime: components?.hour != nil
                    )
                }
            Task { @MainActor in
                self?.reminders = items
            }
        }
    }

    /// A list's color, as Reminders shows it: its own, or for the blue lists
    /// start with, iOS's blue, which is lighter in Dark Mode.
    private static func color(of calendar: EKCalendar) -> Color {
        let color = UIColor(cgColor: calendar.cgColor)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        if red < 0.15, abs(green - 0.48) < 0.1, blue > 0.9 {
            return .blue
        }
        return Color(uiColor: color)
    }
}

