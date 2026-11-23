import Foundation

/// A day on the calendar, with no time of day: the same day wherever the phone is, as a repeat's end
/// date is.
public struct CalendarDay: Comparable, Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (a: CalendarDay, b: CalendarDay) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }
}

extension Engine {
    /// The day `date` falls on, in the engine's calendar and time zone.
    public func calendarDay(of date: Date) -> CalendarDay {
        CalendarDay(
            year: calendar.component(.year, from: date),
            month: calendar.component(.month, from: date),
            day: calendar.component(.day, from: date)
        )
    }

    /// Today, in the engine's calendar and time zone.
    public var today: CalendarDay {
        calendarDay(of: clock.now)
    }

    /// The day `days` calendar days after `day`, or before it for a negative count: My Day's
    /// Previous Day and Next Day (#375). Counted from noon, so a clock change can't land it on the
    /// wrong day.
    public func day(_ day: CalendarDay, movedBy days: Int) -> CalendarDay {
        let noon = DateComponents(year: day.year, month: day.month, day: day.day, hour: 12)
        guard let start = calendar.date(from: noon), let moved = calendar.date(byAdding: .day, value: days, to: start) else { return day }
        return calendarDay(of: moved)
    }

    /// When `day` starts, for a date picker. The calendar finds every day a picker can offer, so the
    /// clock only stands in for a date it can't.
    public func startOfDay(_ day: CalendarDay) -> Date {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? clock.now
    }
}
