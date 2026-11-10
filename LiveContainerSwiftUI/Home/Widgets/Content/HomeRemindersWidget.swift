//
//  HomeRemindersWidget.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Reminders' list widget, as iOS draws it: the list's reminders not yet
/// done, each with a circle that checks it off, under the list's name and how
/// many there are. The small widget puts the name and the count across its
/// top; the medium one puts the list's round icon above them in a column at
/// its left, with the reminders beside them; the large one puts the count
/// and the name at its top left, the icon at its top right and a line under
/// them. Until zContainer may read reminders, which tapping the widget asks,
/// or while the list is empty, it says No Reminders.
struct HomeRemindersWidget: View {
    let size: HomeWidgetSize
    /// The widget's size on screen.
    let frameSize: CGSize

    var body: some View {
        Group {
            switch size {
            case .small:
                small
            case .medium:
                medium
            case .large:
                large
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { HomeWidgetBackground() }
        .onAppear {
            HomeReminders.shared.load()
        }
    }

    // MARK: Sizes

    /// The name and the count across the top, then three reminders.
    private var small: some View {
        let style = HomeReminderRowStyle.small

        return VStack(alignment: .leading, spacing: 0) {
            // As tall as the name's line, so the larger count doesn't push
            // the reminders down.
            HStack(alignment: .top, spacing: 4) {
                listName(size: 15)
                Spacer(minLength: 0)
                count(size: 22)
                    .offset(y: -1.5)
            }
            .frame(height: 17.9, alignment: .top)
            .padding(.horizontal, style.inset)
            .padding(.top, 15.6)
            rows(style: style)
                .padding(.top, 0.75)
        }
    }

    /// The icon, the count and the name in a column at the left, and four
    /// reminders beside them.
    private var medium: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                icon(size: 35)
                    .padding(.top, 14.65)
                Spacer(minLength: 0)
                // A little further in than the icon, as iOS sets them.
                Group {
                    count(size: 31)
                    listName(size: 14.5)
                        .padding(.top, 1)
                        .padding(.bottom, 19)
                }
                .padding(.leading, 1.2)
            }
            .frame(width: 127.6 - 18, alignment: .leading)
            rows(style: .medium)
        }
        .padding(.leading, 18)
    }

    /// The count and the name at the top left, the icon at the top right, a
    /// line under them, then the reminders.
    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    count(size: 29)
                    listName(size: 14)
                        .padding(.top, 1.2)
                }
                Spacer(minLength: 0)
                icon(size: 32.6)
                    .padding(.top, 10.5)
                    .padding(.trailing, 1.1)
            }
            .padding(.top, 12.9)
            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(height: 1)
                .padding(.top, 13.5)
            rows(style: .large)
                .padding(.top, 5.1)
        }
        .padding(.horizontal, 15.8)
    }

    // MARK: Parts

    /// How many reminders there are, in bold.
    private func count(size: Double) -> some View {
        Text(verbatim: "\(HomeReminders.shared.reminders.count)")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(.primary)
            .monospacedDigit()
    }

    /// The list's name, in its color.
    private func listName(size: Double) -> some View {
        Text(HomeReminders.shared.list?.title ?? "zc.widget.reminders".loc)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(listColor)
            .lineLimit(1)
    }

    /// The list's round icon, `size` across.
    private func icon(size: Double) -> some View {
        Image(systemName: "list.bullet")
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(listColor, in: .circle)
    }

    private var listColor: Color {
        HomeReminders.shared.list?.color ?? .blue
    }

    /// As many reminders as the widget has rows for, each in an equal share
    /// of the room left, or No Reminders.
    @ViewBuilder
    private func rows(style: HomeReminderRowStyle) -> some View {
        let shown = Array(HomeReminders.shared.reminders.prefix(style.rows))
        if shown.isEmpty {
            Text("zc.widget.reminders.none".loc)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                ForEach(0..<style.rows, id: \.self) { index in
                    Group {
                        if index < shown.count {
                            HomeReminderRow(reminder: shown[index], style: style)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(height: style.pitch.map { CGFloat($0) })
                    .frame(maxHeight: style.pitch == nil ? .infinity : nil)
                }
                if style.pitch != nil {
                    Spacer(minLength: 0)
                }
            }
            .padding(.top, style.verticalInset)
            .padding(.bottom, style.bottomInset)
            .padding(.horizontal, style == .large ? 0 : style.inset)
        }
    }
}

/// How a size of the widget lays out its reminders.
private struct HomeReminderRowStyle: Equatable {
    /// How many rows there are.
    let rows: Int
    /// Each row's height, or nil to share the room left equally.
    let pitch: Double?
    let circle: Double
    let titleSize: Double
    /// The space between the circle and the title.
    let gap: Double
    /// The space at the sides, and above and below the rows.
    let inset: Double
    let verticalInset: Double
    let bottomInset: Double

    static let small = HomeReminderRowStyle(rows: 3, pitch: 41.3, circle: 22, titleSize: 12.5, gap: 10.5, inset: 18.5, verticalInset: 0, bottomInset: 0)
    static let medium = HomeReminderRowStyle(rows: 4, pitch: nil, circle: 21.6, titleSize: 12.75, gap: 10.6, inset: 0, verticalInset: 4.2, bottomInset: 6)
    static let large = HomeReminderRowStyle(rows: 7, pitch: 32.4, circle: 20.6, titleSize: 12, gap: 10.4, inset: 0, verticalInset: 0, bottomInset: 0)
}

/// One reminder: its circle and its title, with when it's due under it.
private struct HomeReminderRow: View {
    let reminder: HomeReminders.Reminder
    let style: HomeReminderRowStyle

    var body: some View {
        HStack(spacing: style.gap) {
            Circle()
                .strokeBorder(.tertiary, lineWidth: 1.5)
                .frame(width: style.circle, height: style.circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(reminder.title)
                    .font(.system(size: style.titleSize))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let due = reminder.due {
                    Text(dueText(due))
                        .font(.system(size: style.titleSize - 1))
                        .foregroundStyle(isOverdue(due) ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// When it's due: Today or Tomorrow, or the date, with the time when it
    /// has one, as Reminders writes it.
    private func dueText(_ due: Date) -> String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(due) {
            day = "zc.widget.reminders.today".loc
        } else if calendar.isDateInTomorrow(due) {
            day = "zc.widget.reminders.tomorrow".loc
        } else if calendar.isDateInYesterday(due) {
            day = "zc.widget.reminders.yesterday".loc
        } else {
            day = due.formatted(date: .numeric, time: .omitted)
        }
        guard reminder.isDueAtTime else {
            return day
        }
        return "\(day), \(due.formatted(date: .omitted, time: .shortened))"
    }

    private func isOverdue(_ due: Date) -> Bool {
        reminder.isDueAtTime ? due < .now : Calendar.current.startOfDay(for: due) < Calendar.current.startOfDay(for: .now)
    }
}
