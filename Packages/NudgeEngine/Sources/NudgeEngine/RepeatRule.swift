import Foundation

/// How often a reminder comes due again: a preset, or a custom rule in the RRULE subset of
/// ADR 0003. A reminder with no repeat rule repeats Never.
public struct RepeatRule: Equatable, Sendable {
    /// RRULE's `FREQ`.
    public enum Frequency: Equatable, Sendable {
        case daily
        case weekly
        case monthly
        case yearly
    }

    /// What a rule does in a month without its day (the 31st, or 29 February).
    public enum MissingDay: Equatable, Sendable {
        /// RFC 5545: that month has no occurrence. Custom rules do this.
        case skip
        /// It falls on the month's last day instead. The presets do this (ADR 0003).
        case lastDayOfMonth
    }

    /// RRULE's `BYDAY` weekdays (`MO`, `TU` …).
    public enum Weekday: Int, CaseIterable, Sendable {
        // Raw values are Foundation's `Calendar` weekday numbers.
        case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    }

    public var frequency: Frequency
    /// RRULE's `INTERVAL`: every how many days, weeks, months or years.
    public var interval: Int
    /// RRULE's `BYDAY`. `nil` means the first due time's weekday.
    public var weekdays: Set<Weekday>?
    /// RRULE's `BYMONTHDAY`. `nil` means the first due time's day of the month.
    public var monthDay: Int?
    /// RRULE's `BYMONTH`, 1 to 12. `nil` means the first due time's month.
    public var month: Int?
    /// Not part of RRULE: it is what tells a preset from a custom rule with the same parts.
    public var missingDay: MissingDay

    /// `nil` if `interval` is below 1, which RFC 5545 doesn't allow.
    public init?(
        frequency: Frequency,
        interval: Int = 1,
        weekdays: Set<Weekday>? = nil,
        monthDay: Int? = nil,
        month: Int? = nil,
        missingDay: MissingDay = .skip
    ) {
        guard interval >= 1 else { return nil }
        self.init(validFrequency: frequency, interval: interval, weekdays: weekdays, monthDay: monthDay, month: month, missingDay: missingDay)
    }

    /// For the presets, whose parts are known to be valid, so they need no unwrapping.
    private init(
        validFrequency frequency: Frequency,
        interval: Int = 1,
        weekdays: Set<Weekday>? = nil,
        monthDay: Int? = nil,
        month: Int? = nil,
        missingDay: MissingDay = .skip
    ) {
        self.frequency = frequency
        self.interval = interval
        self.weekdays = weekdays
        self.monthDay = monthDay
        self.month = month
        self.missingDay = missingDay
    }

    public static let everyDay = RepeatRule(validFrequency: .daily)
    public static let everyWeekday = RepeatRule(validFrequency: .weekly, weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday])
    public static let everyWeek = RepeatRule(validFrequency: .weekly)
    public static let everyTwoWeeks = RepeatRule(validFrequency: .weekly, interval: 2)
    public static let everyMonth = RepeatRule(validFrequency: .monthly, missingDay: .lastDayOfMonth)
    public static let everyYear = RepeatRule(validFrequency: .yearly, missingDay: .lastDayOfMonth)
}

extension RepeatRule {
    /// How far a search for a due time looks, as in the mockup's `nextOccurrence`: long enough
    /// for a custom "every 10 years" rule. A rule with no due time in it has no next occurrence.
    private static let searchDays = 366 * 11

    /// The latest due time at or before `date`, or `nil` if `date` is before the first due time.
    func latestDueTime(atOrBefore date: Date, firstDueTime: Date, calendar: Calendar) -> Date? {
        guard date >= firstDueTime else { return nil }
        return dueTimes(from: date, by: -1, firstDueTime: firstDueTime, calendar: calendar).first { $0 <= date }
    }

    /// The first due time after `date`, or `nil` if there is none.
    func nextDueTime(after date: Date, firstDueTime: Date, calendar: Calendar) -> Date? {
        dueTimes(from: max(date, firstDueTime), by: 1, firstDueTime: firstDueTime, calendar: calendar).first { $0 > date }
    }

    /// Due times day by day from the day of `date`, forwards (`step` 1) or backwards (-1), never
    /// before the first due time. Every repeat, preset or custom, goes through here.
    private func dueTimes(from date: Date, by step: Int, firstDueTime: Date, calendar: Calendar) -> some Sequence<Date> {
        let firstDay = calendar.startOfDay(for: firstDueTime)
        let time = calendar.dateComponents([.hour, .minute, .second], from: firstDueTime)
        return (0..<Self.searchDays).lazy
            .compactMap { calendar.date(byAdding: .day, value: $0 * step, to: calendar.startOfDay(for: date)) }
            .prefix { $0 >= firstDay }
            .filter { isDue(on: $0, firstDay: firstDay, calendar: calendar) }
            .compactMap { calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: $0) }
    }

    /// Whether the rule falls on `day`, a start of day no earlier than `firstDay`.
    private func isDue(on day: Date, firstDay: Date, calendar: Calendar) -> Bool {
        switch frequency {
        case .daily:
            return (calendar.dateComponents([.day], from: firstDay, to: day).day ?? 0) % interval == 0
        case .weekly:
            let weekday = calendar.component(.weekday, from: day)
            let days = weekdays.map { Set($0.map(\.rawValue)) } ?? [calendar.component(.weekday, from: firstDay)]
            return days.contains(weekday) && weeks(from: firstDay, to: day, calendar: calendar) % interval == 0
        case .monthly:
            // Counted by the calendar month, as the mockup's `monthDiff` does, so the count never
            // depends on how Foundation measures a month elapsed between two different days.
            let first = calendar.dateComponents([.year, .month], from: firstDay)
            let current = calendar.dateComponents([.year, .month], from: day)
            let months = ((current.year ?? 0) - (first.year ?? 0)) * 12 + (current.month ?? 0) - (first.month ?? 0)
            return months % interval == 0 && isOnMonthDay(day, firstDay: firstDay, calendar: calendar)
        case .yearly:
            let years = calendar.component(.year, from: day) - calendar.component(.year, from: firstDay)
            return years % interval == 0
                && calendar.component(.month, from: day) == month ?? calendar.component(.month, from: firstDay)
                && isOnMonthDay(day, firstDay: firstDay, calendar: calendar)
        }
    }

    /// Whether `day` is the rule's day of its month, which comes from `monthDay` or the first due
    /// time, never from the occurrence before. So a preset from the 31st returns to the 31st.
    private func isOnMonthDay(_ day: Date, firstDay: Date, calendar: Calendar) -> Bool {
        let wanted = monthDay ?? calendar.component(.day, from: firstDay)
        let lastDay = calendar.range(of: .day, in: .month, for: day)?.count ?? 31
        let target = switch missingDay {
        case .skip: wanted
        case .lastDayOfMonth: min(wanted, lastDay)
        }
        return calendar.component(.day, from: day) == target
    }

    /// Whole weeks between the weeks holding two days. Weeks start on Monday, RRULE's default
    /// `WKST`, whatever the calendar's own first weekday.
    private func weeks(from start: Date, to end: Date, calendar: Calendar) -> Int {
        func monday(of day: Date) -> Date {
            let daysSinceMonday = (calendar.component(.weekday, from: day) + 5) % 7
            return calendar.date(byAdding: .day, value: -daysSinceMonday, to: day) ?? day
        }
        return (calendar.dateComponents([.day], from: monday(of: start), to: monday(of: end)).day ?? 0) / 7
    }
}
