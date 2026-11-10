//
//  HomeCalendarWidget.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Calendar's Up Next widget, as iOS draws it, with what's on in your
/// calendars: the day in red capitals and the date large under it, then
/// today's events, all-day ones as tinted pills, a holiday with a star and a
/// birthday with a gift, then the rest with their times, or No Events Today.
/// The medium widget shows the week ahead's events beside today's, day by
/// day, or the month, with today circled in red, when there are none. The
/// large one shows the rest of today and tomorrow hour by hour, with a red
/// line at the time now. It asks to read the calendars when it first shows.
struct HomeCalendarWidget: View {
    let size: HomeWidgetSize
    /// The widget's size on screen.
    let frameSize: CGSize

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Redrawn every minute, so the date is today's and past events go.
        TimelineView(.everyMinute) { context in
            content(on: context.date)
                .onAppear {
                    HomeCalendarEvents.shared.refresh(for: context.date)
                }
                .onChange(of: context.date) {
                    HomeCalendarEvents.shared.refresh(for: context.date)
                }
        }
        .background { HomeWidgetBackground() }
    }

    @ViewBuilder
    private func content(on date: Date) -> some View {
        let events = HomeCalendarEvents.shared

        switch size {
        case .small:
            today(on: date)
                .padding(Self.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .overlay(alignment: .top) {
                    if events.events.isEmpty {
                        noEvents(leading: Self.inset)
                    }
                }
        case .medium:
            // The week ahead, or the month, keeps to the right, nearer the
            // edge than the day is to the left, as iOS's does.
            HStack(alignment: .top, spacing: 0) {
                today(on: date)
                    .padding(.top, Self.mediumTodayTop)
                    .padding(.leading, Self.mediumTodayLeading)
                    .padding(.trailing, 15.2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if events.upcoming.isEmpty {
                    HomeCalendarMonth(date: date)
                        .padding(.top, Self.largerInset)
                        .padding(.trailing, HomeCalendarMonth.trailingInset)
                } else {
                    upcoming(events.upcoming, on: date)
                        .padding(.top, Self.mediumTodayTop)
                        .padding(.trailing, Self.upcomingTrailing)
                        .frame(width: Self.upcomingWidth, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .top) {
                if events.events.isEmpty {
                    noEvents(leading: Self.mediumTodayLeading)
                }
            }
        case .large:
            HomeCalendarTimeline(date: date, frameSize: frameSize, header: { today(on: date, showsEvents: false) })
        }
    }

    /// The day, the date and, unless the widget shows them elsewhere, what's
    /// on.
    private func today(on date: Date, showsEvents: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(date.formatted(.dateTime.weekday(.wide)).uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.red)
                .lineLimit(1)
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: size == .small ? 34 : 32, weight: .regular))
                .foregroundStyle(.primary)
                .padding(.top, size == .small ? -3 : -1.9)
            if showsEvents {
                events
                    .padding(.top, 4)
            }
        }
    }

    /// Today's events, as many as fit.
    @ViewBuilder
    private var events: some View {
        let shown = Array(HomeCalendarEvents.shared.events.prefix(maximumEvents))
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(shown) { event in
                    HomeCalendarEventRow(event: event, isSmall: size == .small)
                }
            }
        }
    }

    /// No Events Today, lower down, two thirds of the way down the widget,
    /// as iOS sets it.
    private func noEvents(leading: Double) -> some View {
        Text("zc.widget.calendar.noEvents".loc)
            .font(.system(size: 14.3, weight: .regular))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, leading)
            .frame(height: 0)
            .offset(y: frameSize.height * Self.noEventsCenter)
    }

    /// The week ahead's days with events, each under its day in gray
    /// capitals, as many as fit.
    private func upcoming(_ days: [HomeCalendarEvents.Day], on date: Date) -> some View {
        var rows = 0
        let shown: [(HomeCalendarEvents.Day, [HomeCalendarEvents.Event])] = days.compactMap { day in
            guard rows < Self.upcomingRows else {
                return nil
            }
            let events = Array(day.events.prefix(Self.upcomingRows - rows))
            rows += events.count + 1
            return (day, events)
        }

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(shown, id: \.0.id) { day, events in
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayTitle(day.date, today: date))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    ForEach(events) { event in
                        HomeCalendarEventRow(event: event, isSmall: false)
                    }
                }
            }
        }
    }

    /// TOMORROW, or the day's name and date, as Up Next heads a later day.
    private func dayTitle(_ day: Date, today: Date) -> String {
        if Calendar.current.isDate(day, inSameDayAs: Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today) {
            return "zc.widget.calendar.tomorrow".loc.uppercased()
        }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased()
    }

    /// How many events fit under the date.
    private var maximumEvents: Int {
        switch size {
        case .small, .medium:
            2
        case .large:
            4
        }
    }

    /// The space between the widget's edges and what it shows.
    private static var inset: Double {
        SharedModel.isPhone ? 18.33 : 14
    }

    /// The space around the medium and large widgets' contents.
    static let largerInset = 15.25
    /// Where the medium widget's day starts.
    static let mediumTodayTop = 15.8
    static let mediumTodayLeading = 16.35
    /// The medium widget's week ahead: its width, its space from the right
    /// edge, and how many lines it has room for, days' names among them.
    private static let upcomingWidth = 156.2
    private static let upcomingTrailing = 14.2
    private static let upcomingRows = 4
    /// How far down the widget No Events Today is centered.
    private static let noEventsCenter = 0.665
}

/// An event in the Calendar widget: an all-day one as its title in a pill
/// tinted with its calendar's color, after a star for a holiday or a gift
/// for a birthday; one at a time as a bar of its calendar's color, its title
/// and when it is.
struct HomeCalendarEventRow: View {
    let event: HomeCalendarEvents.Event
    let isSmall: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if event.isAllDay {
            allDay
        } else {
            timed
        }
    }

    private var allDay: some View {
        HStack(spacing: isSmall ? 2 : 0) {
            if let symbol = event.symbol {
                // The symbol knocked out of its circle, showing the widget
                // through it.
                Image(systemName: symbol)
                    .font(.system(size: 15.5))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(colorScheme == .dark ? Self.darkKnockout : .white, HomeCalendarColors.accent(event.color, colorScheme))
            }
            Text(event.title)
                .font(.system(size: isSmall ? 13 : 12.4, weight: .semibold))
                .foregroundStyle(HomeCalendarColors.text(event.color, colorScheme))
                .lineLimit(1)
        }
        .padding(.horizontal, event.symbol == nil ? 7 : isSmall ? 1 : 0)
        .padding(.vertical, isSmall ? 1 : 0)
        .frame(maxWidth: .infinity, minHeight: isSmall ? nil : 16.9, maxHeight: isSmall ? nil : 16.9, alignment: .leading)
        .background(HomeCalendarColors.pill(event.color, colorScheme), in: .capsule)
    }

    /// The widget's gray where an event's symbol is knocked out, in Dark.
    private static let darkKnockout = Color(red: 30 / 255, green: 30 / 255, blue: 32 / 255)

    private var timed: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.color)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(event.start.formatted(date: .omitted, time: .shortened) + "–" + event.end.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The colors Calendar's widget draws an event in, from its calendar's.
enum HomeCalendarColors {
    /// An event's title: its calendar's color, deepened in Light and
    /// lightened in Dark, so it reads on its pill.
    static func text(_ color: Color, _ scheme: ColorScheme) -> Color {
        let (hue, saturation, brightness) = hsb(of: color)
        if scheme == .dark {
            return accent(color, scheme)
        }
        return Color(hue: hue, saturation: saturation, brightness: brightness * 0.5)
    }

    /// An event's symbol's circle and bar: its calendar's color, a little
    /// brighter in Dark, as Calendar lightens its colors there.
    static func accent(_ color: Color, _ scheme: ColorScheme) -> Color {
        guard scheme == .dark else {
            return color
        }
        let (hue, saturation, brightness) = hsb(of: color)
        return Color(hue: hue, saturation: saturation * 0.957, brightness: min(brightness * 1.045, 1))
    }

    /// An all-day event's pill, and a timed event's block: a wash of its
    /// calendar's color in Light, and in Dark a deep shade of it, as iOS
    /// 26.5's Calendar widget draws them.
    static func pill(_ color: Color, _ scheme: ColorScheme) -> Color {
        guard scheme == .dark else {
            return color.opacity(0.07)
        }
        let (hue, saturation, _) = hsb(of: color)
        return Color(hue: hue, saturation: saturation * 0.65, brightness: 0.2)
    }

    private static func hsb(of color: Color) -> (Double, Double, Double) {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return (hue, saturation, brightness)
    }
}

/// A month, as Calendar's widgets show it: its name in red capitals, the days
/// of the week, and its dates, weekends in gray and today in a red circle,
/// in columns and rows as far apart as iPadOS spaces them, measured on an
/// iPad Air 11-inch's medium widget.
private struct HomeCalendarMonth: View {
    let date: Date

    /// The space between the month and the widget's right edge.
    static let trailingInset = 11.15
    /// A column's width and a week's height.
    private static let column = 20.7
    private static let week = 15.0
    /// Today's circle.
    private static let todaySize = 18.0

    var body: some View {
        let calendar = Calendar.current
        let weeks = monthWeeks(calendar)

        VStack(alignment: .leading, spacing: 0) {
            Text(date.formatted(.dateTime.month(.wide)).uppercased())
                .font(.system(size: 10.45, weight: .semibold))
                .foregroundStyle(.red)
                .lineLimit(1)
                // Over the first day of the week's letter, not its column.
                .padding(.leading, 4.7)
                .padding(.top, 0.6)
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols(calendar).enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(isWeekend(column: index, calendar) ? .secondary : .primary)
                        .frame(width: Self.column)
                }
            }
            .padding(.top, 1.8)
            VStack(spacing: 0) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 0) {
                        ForEach(Array(week.enumerated()), id: \.offset) { column, day in
                            dayCell(day, column: column, calendar: calendar)
                        }
                    }
                    .frame(height: Self.week)
                }
            }
            .padding(.top, 1.2)
        }
        .frame(width: Self.column * 7, alignment: .leading)
    }

    @ViewBuilder
    private func dayCell(_ day: Int?, column: Int, calendar: Calendar) -> some View {
        if let day {
            let isToday = day == calendar.component(.day, from: date)
            Text(verbatim: "\(day)")
                .font(.system(size: 9.25, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isToday ? .white : isWeekend(column: column, calendar) ? .secondary : .primary)
                .frame(width: Self.column, height: Self.week)
                .background {
                    if isToday {
                        Circle()
                            .fill(.red)
                            .frame(width: Self.todaySize, height: Self.todaySize)
                    }
                }
        } else {
            Color.clear
                .frame(width: Self.column, height: Self.week)
        }
    }

    /// The month's dates in weeks, with blanks before the first so each falls
    /// under its day of the week, and after the last to fill its week.
    private func monthWeeks(_ calendar: Calendar) -> [[Int?]] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var days: [Int?] = Array(repeating: nil, count: leading) + range.map { Optional($0) }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<($0 + 7)]) }
    }

    /// The days of the week's initials, from the first day of the week.
    private func weekdaySymbols(_ calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Whether a column of the month falls on a Saturday or Sunday.
    private func isWeekend(column: Int, _ calendar: Calendar) -> Bool {
        let weekday = (calendar.firstWeekday - 1 + column) % 7 + 1
        return weekday == 1 || weekday == 7
    }
}
