import Foundation

/// The 7-day history of a repeating sent reminder (GLOSSARY.md): today and the 7 days before, each
/// with its occurrence's status as the recipient's status report gave it. What a Sent row and the
/// sent reminder's details show.
public struct SevenDayHistory: Equatable, Sendable {
    /// Eight days, oldest first, today last.
    public var days: [Day]

    /// One day of the history.
    public struct Day: Equatable, Sendable {
        public var day: CalendarDay
        /// The status of the occurrence due that day, or `nil` when none was.
        public var status: ReportedStatus?
        public var isToday: Bool
    }
}

extension Engine {
    /// The 7-day history a status report's `occurrences` give. The days are the recipient's, as the
    /// occurrences name them. They end at the engine's today, or at the latest one's day when later,
    /// so a recipient a time zone ahead keeps their today: the report doesn't say the day it was
    /// made. Two occurrences on one day show the later one's status.
    public func sevenDayHistory(of occurrences: [StatusReport.OccurrenceStatus]) -> SevenDayHistory {
        let latest = occurrences.map(\.day).max().map(startOfDay)
        let today = max(calendar.startOfDay(for: clock.now), latest ?? .distantPast)
        let days = (0...Self.statusReportDays).reversed().compactMap { back in
            calendar.date(byAdding: .day, value: -back, to: today).map(calendarDay(of:))
        }
        return SevenDayHistory(days: days.map { day in
            SevenDayHistory.Day(
                day: day,
                status: occurrences.filter { $0.day == day }.max { $0.dueTime < $1.dueTime }?.label,
                isToday: day == days.last
            )
        })
    }
}

extension Engine {
    /// The weekday's initial, such as "T" for Thursday, in the engine's locale: a history cell's.
    public func weekdayInitial(of day: CalendarDay) -> String {
        startOfDay(day).formatted(dayStyle.weekday(.narrow))
    }

    /// The weekday's whole name, such as "Thursday", in the engine's locale: what VoiceOver reads
    /// for a history cell.
    public func weekdayName(of day: CalendarDay) -> String {
        startOfDay(day).formatted(dayStyle.weekday(.wide))
    }

    private var dayStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    }
}
