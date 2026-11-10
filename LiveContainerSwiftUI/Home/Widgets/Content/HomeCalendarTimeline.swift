//
//  HomeCalendarTimeline.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The large Up Next widget, as iOS 26.5 draws it: two columns of hours, the
/// rest of today under the day and the date, with a red line at the time
/// now, and tomorrow from nine in the morning under TOMORROW, each with its
/// events at their times and its all-day events under its heading. Today
/// shows five hours, from two before now, and tomorrow eight, each name
/// under its hour's line, as the clock writes it. Measured on an iPad Air
/// 11-inch, in points of the widget as it's laid out.
struct HomeCalendarTimeline<Header: View>: View {
    let date: Date
    /// The widget's size, as it's laid out.
    let frameSize: CGSize
    /// The day and the date.
    @ViewBuilder let header: Header

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let events = HomeCalendarEvents.shared
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let nowHour = calendar.component(.hour, from: date)
        // From the hour before now, five hours, ending at midnight at the
        // latest, as iOS keeps the rest of the day in view.
        let todayStart = min(max(nowHour - 1, 0), 24 - Self.todayHours + 1)
        let todayEnd = todayStart + Self.todayHours - 1
        let tomorrowsTimed = events.tomorrow.filter { !$0.isAllDay && $0.start >= tomorrow }
        let firstTomorrow = tomorrowsTimed.map { calendar.component(.hour, from: $0.start) }.min() ?? Self.morning
        let tomorrowStart = min(firstTomorrow, Self.morning)
        let todayAllDay = events.events.filter(\.isAllDay)
        let tomorrowAllDay = events.tomorrow.filter(\.isAllDay)
        // The two days split the widget down its middle.
        let middle = frameSize.width / 2

        ZStack(alignment: .topLeading) {
            header
                .padding(.leading, Self.headerLeading)
                .padding(.top, Self.top)
            Text("zc.widget.calendar.tomorrow".loc.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.leading, middle + Self.tomorrowTitleFromMiddle)
                .padding(.top, Self.top)
            column(
                day: today,
                hours: todayStart...todayEnd,
                firstHourCenter: Self.todayFirstHour + allDayRoom(todayAllDay),
                allDay: todayAllDay,
                allDayTop: Self.todayFirstHour - 12,
                timed: events.todaysTimed,
                now: date,
                labelRight: Self.todayLabelRight,
                lineStart: Self.todayLabelRight + Self.todayLineGap,
                lineEnd: middle - Self.todayLineEndFromMiddle
            )
            column(
                day: tomorrow,
                hours: tomorrowStart...min(tomorrowStart + Self.hoursShown - 1, 24),
                firstHourCenter: Self.tomorrowFirstHour + allDayRoom(tomorrowAllDay),
                allDay: tomorrowAllDay,
                allDayTop: Self.tomorrowFirstHour - 8,
                timed: tomorrowsTimed,
                now: nil,
                labelRight: middle + Self.tomorrowLabelRightFromMiddle,
                lineStart: middle + Self.tomorrowLabelRightFromMiddle + Self.tomorrowLineGap,
                lineEnd: frameSize.width - Self.trailing
            )
        }
        .frame(width: frameSize.width, height: frameSize.height, alignment: .topLeading)
    }

    /// One day's hours: each hour's line and its name right-aligned at its
    /// start, centered on it, its events at their times, its all-day events
    /// above, and on today's, the red line at now, over the hours' names.
    private func column(
        day: Date,
        hours: ClosedRange<Int>,
        firstHourCenter: Double,
        allDay: [HomeCalendarEvents.Event],
        allDayTop: Double,
        timed: [HomeCalendarEvents.Event],
        now: Date?,
        labelRight: Double,
        lineStart: Double,
        lineEnd: Double
    ) -> some View {
        let lastHourCenter = frameSize.height - Self.bottom
        let pitch = hours.count > 1 ? (lastHourCenter - firstHourCenter) / Double(hours.count - 1) : 0
        func y(_ time: Date) -> Double {
            let hoursIn = time.timeIntervalSince(day) / 3600
            return firstHourCenter + (hoursIn - Double(hours.lowerBound)) * pitch
        }

        return ZStack(alignment: .topLeading) {
            ForEach(Array(hours), id: \.self) { hour in
                let center = firstHourCenter + Double(hour - hours.lowerBound) * pitch
                Rectangle()
                    .fill(Color(uiColor: .separator))
                    .frame(width: max(lineEnd - lineStart, 0), height: Self.lineWidth)
                    .offset(x: lineStart, y: center - Self.lineWidth / 2)
                // Right-aligned against the line, a longer name reaching
                // further left.
                Text(hourName(hour, on: day))
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .frame(width: labelRight, height: 0, alignment: .trailing)
                    .offset(y: center)
            }
            ForEach(timed) { event in
                let top = max(y(event.start), firstHourCenter)
                let bottom = min(y(event.end), lastHourCenter)
                if bottom > top {
                    eventBlock(event, height: max(bottom - top, Self.minimumBlock))
                        .frame(width: max(lineEnd - lineStart, 0))
                        .offset(x: lineStart, y: top)
                }
            }
            if let now, hours.contains(Calendar.current.component(.hour, from: now)) {
                let nowY = y(now)
                Circle()
                    .fill(.red)
                    .frame(width: Self.nowDot, height: Self.nowDot)
                    .offset(x: Self.nowDotLeft, y: nowY - Self.nowDot / 2)
                Rectangle()
                    .fill(.red)
                    .frame(width: max(lineEnd - Self.nowDotLeft - Self.nowDot / 2, 0), height: Self.nowLine)
                    .offset(x: Self.nowDotLeft + Self.nowDot / 2, y: nowY - Self.nowLine / 2)
            }
            if !allDay.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(allDay.prefix(2)) { event in
                        HomeCalendarEventRow(event: event, isSmall: false)
                    }
                }
                .frame(width: max(lineEnd - lineStart, 0))
                .offset(x: lineStart, y: allDayTop)
            }
        }
    }

    /// An event at its time: a block tinted with its calendar's color, a bar
    /// of it down its side, and its title.
    private func eventBlock(_ event: HomeCalendarEvents.Event, height: Double) -> some View {
        HStack(alignment: .top, spacing: 4) {
            RoundedRectangle(cornerRadius: 1)
                .fill(HomeCalendarColors.accent(event.color, colorScheme))
                .frame(width: 2.5)
            Text(event.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(HomeCalendarColors.text(event.color, colorScheme))
                .lineLimit(max(Int(height / 12), 1))
                .padding(.top, 1.5)
            Spacer(minLength: 0)
        }
        .frame(height: height, alignment: .topLeading)
        .background(HomeCalendarColors.pill(event.color, colorScheme).opacity(colorScheme == .dark ? 1 : 2.2), in: .rect(cornerRadius: 4))
        .clipShape(.rect(cornerRadius: 4))
    }

    /// An hour's name as the clock shows it, without a leading zero: 9 and
    /// 1 on a 12-hour clock, 9 and 13 on a 24-hour one.
    private func hourName(_ hour: Int, on day: Date) -> String {
        let uses24Hour = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current)?.contains("H") ?? false
        if uses24Hour {
            return "\(hour % 24)"
        }
        let twelve = hour % 12
        return "\(twelve == 0 ? 12 : twelve)"
    }

    /// The room a column's all-day events take above its hours.
    private func allDayRoom(_ events: [HomeCalendarEvents.Event]) -> Double {
        events.isEmpty ? 0 : Double(min(events.count, 2)) * 20
    }

    // MARK: Measurements

    /// How many hours a column shows: today's five from the hour before now,
    /// and tomorrow's eight from the morning.
    private static var todayHours: Int { 5 }
    private static var hoursShown: Int { 8 }
    /// The hour tomorrow starts at, unless it has an event earlier.
    private static var morning: Int { 9 }
    /// The space from the widget's edges: to the left of the day, to the
    /// right of tomorrow's lines, above the headings, and from the bottom to
    /// the last hour's line.
    private static var headerLeading: Double { 17.4 }
    private static var trailing: Double { 16.9 }
    private static var top: Double { 15.8 }
    private static var bottom: Double { 24.3 }
    /// Where each day's first hour's line is, from the top.
    private static var todayFirstHour: Double { 83 }
    private static var tomorrowFirstHour: Double { 46.2 }
    /// Where today's hours' names end, how far after them their lines start,
    /// and how far before the middle the lines end.
    private static var todayLabelRight: Double { 27.7 }
    private static var todayLineGap: Double { 2.75 }
    private static var todayLineEndFromMiddle: Double { 4.35 }
    /// Where tomorrow's hours' names end, from the middle, and how far after
    /// them their lines start; TOMORROW's place, from the middle.
    private static var tomorrowLabelRightFromMiddle: Double { 15.8 }
    private static var tomorrowLineGap: Double { 2.15 }
    private static var tomorrowTitleFromMiddle: Double { 18.45 }
    private static var lineWidth: Double { 0.55 }
    /// The line at now: its dot, where the dot starts, and the line's
    /// thickness.
    private static var nowDot: Double { 5.4 }
    private static var nowDotLeft: Double { 16.9 }
    private static var nowLine: Double { 1.1 }
    /// The shortest an event's block is drawn.
    private static var minimumBlock: Double { 14 }
}
