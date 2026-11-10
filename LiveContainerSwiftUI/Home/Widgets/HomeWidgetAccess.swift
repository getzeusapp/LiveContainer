//
//  HomeWidgetAccess.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Asks for what each widget shows the first time it's on screen, as iOS asks
/// before a widget reads something of yours: the calendars for Calendar,
/// reminders for Reminders, the photo library for Photos, and where you are
/// for Maps. Only one question shows at a time, and each is asked once.
@MainActor
final class HomeWidgetAccess {
    static let shared = HomeWidgetAccess()

    /// The question being asked, which the next one waits for.
    private var current: Task<Void, Never>?

    /// Asks what a widget of `kind` needs, unless zContainer has been
    /// allowed or refused before, after any question already showing.
    func request(for kind: HomeWidgetKind) {
        guard needsAsking(kind) else {
            return
        }
        let previous = current
        current = Task {
            await previous?.value
            guard needsAsking(kind) else {
                return
            }
            await ask(kind)
        }
    }

    private func needsAsking(_ kind: HomeWidgetKind) -> Bool {
        switch kind {
        case .calendar:
            HomeCalendarEvents.shared.canAsk
        case .reminders:
            HomeReminders.shared.canAsk
        case .photos:
            HomeFeaturedPhotos.shared.canAsk
        case .maps:
            HomeMapLocation.shared.canAsk
        case .news:
            false
        }
    }

    private func ask(_ kind: HomeWidgetKind) async {
        switch kind {
        case .calendar:
            await HomeCalendarEvents.shared.requestAccess()
        case .reminders:
            await HomeReminders.shared.requestAccess()
        case .photos:
            await HomeFeaturedPhotos.shared.requestAccess()
        case .maps:
            HomeMapLocation.shared.requestAccess()
            // Location's question answers through the location manager;
            // the next question waits until this one is answered.
            while HomeMapLocation.shared.canAsk, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
            }
        case .news:
            break
        }
    }
}
