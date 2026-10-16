import Foundation

/// How often a reminder comes due again: a preset, or a custom rule in the RRULE subset of
/// ADR 0003. A reminder with no repeat rule repeats Never.
public struct RepeatRule: Equatable, Sendable {
    /// RRULE's `FREQ`.
    public enum Frequency: Hashable, CaseIterable, Sendable {
        case daily
        case weekly
        case monthly
        case yearly

        /// How RRULE text spells it.
        var code: String {
            switch self {
            case .daily: "DAILY"
            case .weekly: "WEEKLY"
            case .monthly: "MONTHLY"
            case .yearly: "YEARLY"
            }
        }
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

        /// 0 for Monday to 6 for Sunday: the order RRULE's default week and the Custom page use.
        var mondayFirstIndex: Int { (rawValue + 5) % 7 }

        /// How RRULE text spells it.
        var code: String {
            switch self {
            case .sunday: "SU"
            case .monday: "MO"
            case .tuesday: "TU"
            case .wednesday: "WE"
            case .thursday: "TH"
            case .friday: "FR"
            case .saturday: "SA"
            }
        }
    }

    /// One `BYDAY` entry, RFC 5545's `weekdaynum`: a weekday, and for monthly and yearly rules an
    /// optional ordinal within the month or year (`1MO` the first Monday, `-1FR` the last Friday).
    /// They sort Monday first, then by ordinal, as the Custom page lists them.
    public struct WeekdayNumber: Hashable, Comparable, Sendable {
        public var weekday: Weekday
        /// `nil` is every such weekday. Negative counts back from the end.
        public var ordinal: Int?

        public init(_ weekday: Weekday, ordinal: Int? = nil) {
            self.weekday = weekday
            self.ordinal = ordinal
        }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            (lhs.weekday.mondayFirstIndex, lhs.ordinal ?? 0) < (rhs.weekday.mondayFirstIndex, rhs.ordinal ?? 0)
        }
    }

    /// When a rule stops: RRULE's `COUNT` or `UNTIL`, never both (RFC 5545).
    public enum End: Equatable, Sendable {
        /// This many occurrences, the first due time counting as the first (RFC 5545).
        case count(Int)
        /// The last day it can fall on, all of that day in the engine's time zone.
        case untilDate(year: Int, month: Int, day: Int)
        /// The last moment it can fall on, inclusive.
        case untilTime(Date)
    }

    public var frequency: Frequency
    /// RRULE's `INTERVAL`: every how many days, weeks, months or years.
    public var interval: Int
    /// RRULE's `BYDAY`.
    public var weekdays: Set<WeekdayNumber>?
    /// RRULE's `BYMONTHDAY`, 1 to 31, or -1 to -31 counting back from the month's last day.
    public var monthDays: Set<Int>?
    /// RRULE's `BYMONTH`, 1 to 12.
    public var months: Set<Int>?
    /// `nil` repeats for ever.
    public var end: End?
    /// Not part of RRULE: it is what tells a preset from a custom rule with the same parts.
    public var missingDay: MissingDay

    /// `nil` if `interval` is below 1, which RFC 5545 doesn't allow. A part left `nil` comes from
    /// the first due time as RFC 5545 says: a weekly rule with no `weekdays` falls on the first
    /// due time's weekday, a monthly rule with no `weekdays` or `monthDays` on its day of the
    /// month, and a yearly rule with neither on its day and (without `months`) its month.
    public init?(
        frequency: Frequency,
        interval: Int = 1,
        weekdays: Set<WeekdayNumber>? = nil,
        monthDays: Set<Int>? = nil,
        months: Set<Int>? = nil,
        end: End? = nil,
        missingDay: MissingDay = .skip
    ) {
        guard interval >= 1 else { return nil }
        self.init(frequency, checkedInterval: interval, weekdays: weekdays, monthDays: monthDays, months: months, end: end, missingDay: missingDay)
    }

    /// For the presets and the parser, which have already checked that `interval` is at least 1.
    init(
        _ frequency: Frequency,
        checkedInterval interval: Int = 1,
        weekdays: Set<WeekdayNumber>? = nil,
        monthDays: Set<Int>? = nil,
        months: Set<Int>? = nil,
        end: End? = nil,
        missingDay: MissingDay = .skip
    ) {
        self.frequency = frequency
        self.interval = interval
        self.weekdays = weekdays
        self.monthDays = monthDays
        self.months = months
        self.end = end
        self.missingDay = missingDay
    }

    public static let everyDay = RepeatRule(.daily)
    public static let everyWeekday = RepeatRule(.weekly, weekdays: Set([Weekday.monday, .tuesday, .wednesday, .thursday, .friday].map { WeekdayNumber($0) }))
    public static let everyWeek = RepeatRule(.weekly)
    public static let everyTwoWeeks = RepeatRule(.weekly, checkedInterval: 2)
    public static let everyMonth = RepeatRule(.monthly, missingDay: .lastDayOfMonth)
    public static let everyYear = RepeatRule(.yearly, missingDay: .lastDayOfMonth)
}

extension RepeatRule {
    /// How many days a search looks at before it gives up, about 11 years' worth, as in the
    /// mockup's `nextOccurrence`. A jump past a period the interval or the months rule out costs
    /// one step, so a rare rule (every 20 years, or 29 February on a Monday) still reaches dates
    /// decades away. A rule with no due time within it has no next occurrence.
    private static let searchSteps = 366 * 11

    /// The latest due time at or before `date`, or `nil` if `date` is before the first due time.
    /// After the rule's end, that is its last due time.
    func latestDueTime(atOrBefore date: Date, firstDueTime: Date, calendar: Calendar) -> Date? {
        guard date >= firstDueTime else { return nil }
        if case .count(let count) = end {
            return countedDueTimes(count, firstDueTime: firstDueTime, calendar: calendar).prefix { $0 <= date }.last
        }
        let date = min(date, untilBound(firstDueTime: firstDueTime, calendar: calendar) ?? date)
        return dueTimes(from: date, by: -1, firstDueTime: firstDueTime, calendar: calendar).first { $0 <= date }
    }

    /// The first due time after `date`, or `nil` if there is none: the rule has ended, or the
    /// search found nothing.
    func nextDueTime(after date: Date, firstDueTime: Date, calendar: Calendar) -> Date? {
        if case .count(let count) = end {
            return countedDueTimes(count, firstDueTime: firstDueTime, calendar: calendar).first { $0 > date }
        }
        let next = dueTimes(from: max(date, firstDueTime), by: 1, firstDueTime: firstDueTime, calendar: calendar).first { $0 > date }
        guard let next, let until = untilBound(firstDueTime: firstDueTime, calendar: calendar) else { return next }
        return next <= until ? next : nil
    }

    /// A `COUNT` rule's due times in order from the first, which counts as one (RFC 5545). Walked
    /// only as far as the caller reads, never to the end of a huge `COUNT`.
    private func countedDueTimes(_ count: Int, firstDueTime: Date, calendar: Calendar) -> some Sequence<Date> {
        dueTimes(from: firstDueTime, by: 1, firstDueTime: firstDueTime, calendar: calendar).prefix(count)
    }

    /// The latest moment a due time can fall at under `UNTIL`, or `nil` without one. Never before
    /// the first due time, which always counts (RFC 5545).
    private func untilBound(firstDueTime: Date, calendar: Calendar) -> Date? {
        switch end {
        case nil, .count:
            return nil
        case let .untilDate(year, month, day):
            guard let untilDay = calendar.date(from: DateComponents(year: year, month: month, day: day)),
                  let dayAfter = calendar.date(byAdding: .day, value: 1, to: untilDay)
            else { return firstDueTime }
            return max(firstDueTime, dayAfter.justBefore)
        case .untilTime(let time):
            return max(firstDueTime, time)
        }
    }

    /// Due times from the day of `date`, forwards (`step` 1) or backwards (-1), never before the
    /// first due time. The step budget starts again after each due time, so each is its own
    /// bounded search. Every repeat, preset or custom, goes through here.
    private func dueTimes(from date: Date, by step: Int, firstDueTime: Date, calendar: Calendar) -> some Sequence<Date> {
        let walk = DayWalk(rule: self, firstDueTime: firstDueTime, calendar: calendar)
        let time = calendar.dateComponents([.hour, .minute, .second], from: firstDueTime)
        let start: Date? = calendar.startOfDay(for: date)
        let days = sequence(state: (day: start, stepsLeft: Self.searchSteps)) { state -> Date? in
            while let day = state.day, day >= walk.firstDay, state.stepsLeft > 0 {
                state.day = walk.nextCandidate(after: day, by: step)
                state.stepsLeft -= 1
                if walk.isDue(on: day) {
                    state.stepsLeft = Self.searchSteps
                    return day
                }
            }
            return nil
        }
        return days.lazy.compactMap {
            calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: $0)
        }
    }
}

/// One walk over the days for a rule and its first due time, with RFC 5545's defaults from the
/// first due time worked out once. Every part is a filter on the day: walking day by day, RFC
/// 5545's "expand" and "limit" both come to "the day matches".
private struct DayWalk {
    let rule: RepeatRule
    let calendar: Calendar
    let firstDay: Date
    private let first: DateComponents
    private let weekdays: Set<RepeatRule.WeekdayNumber>?
    private let monthDays: Set<Int>?
    private let months: Set<Int>?

    init(rule: RepeatRule, firstDueTime: Date, calendar: Calendar) {
        self.rule = rule
        self.calendar = calendar
        firstDay = calendar.startOfDay(for: firstDueTime)
        first = calendar.dateComponents([.year, .month, .day, .weekday], from: firstDay)
        // RFC 5545 takes what the rule doesn't say from DTSTART, and only when no day part is given.
        var weekdays = rule.weekdays
        var monthDays = rule.monthDays
        var months = rule.months
        if weekdays == nil && monthDays == nil {
            switch rule.frequency {
            case .daily: break
            case .weekly: weekdays = first.weekday.flatMap(RepeatRule.Weekday.init).map { [RepeatRule.WeekdayNumber($0)] }
            case .monthly: monthDays = first.day.map { [$0] }
            case .yearly:
                monthDays = first.day.map { [$0] }
                if months == nil { months = first.month.map { [$0] } }
            }
        }
        self.weekdays = weekdays
        self.monthDays = monthDays
        self.months = months
    }

    /// Whether the rule falls on `day`, a start of day no earlier than the first due day.
    func isDue(on day: Date) -> Bool {
        // RFC 5545: "The DTSTART property value always counts as the first occurrence."
        if day == firstDay { return true }
        let date = calendar.dateComponents([.year, .month, .day, .weekday], from: day)
        guard periods(to: day, date) % rule.interval == 0 else { return false }
        if let months, !months.contains(date.month ?? 0) { return false }
        let lastDay = calendar.range(of: .day, in: .month, for: day)?.count ?? 31
        if let monthDays, !monthDays.contains(where: { isMonthDay($0, date.day ?? 0, lastDay: lastDay) }) { return false }
        if let weekdays, !weekdays.contains(where: { matches($0, day, date, lastDay: lastDay) }) { return false }
        return true
    }

    /// The next day worth looking at after `day` (before it, for `step` -1). It jumps past a whole
    /// week, month or year that the interval rules out, and past a month the rule can't fall in,
    /// so a rare rule (every 10 years, 30 times) is a few thousand steps, not a hundred thousand.
    func nextCandidate(after day: Date, by step: Int) -> Date? {
        let next = jump(from: day, by: step)
        // The first due day always counts, even off the rule, so a jump back never skips it.
        if step < 0, let next, next < firstDay, day > firstDay { return firstDay }
        return next
    }

    private func jump(from day: Date, by step: Int) -> Date? {
        let date = calendar.dateComponents([.year, .month], from: day)
        let remainder = periods(to: day, date) % rule.interval
        if remainder != 0 {
            // Straight to the nearest period the interval allows, however large the interval.
            let periods = step > 0 ? rule.interval - remainder : remainder
            switch rule.frequency {
            case .daily: return calendar.date(byAdding: .day, value: step * periods, to: day)
            case .weekly: return beyondWeek(of: day, by: step, weeks: periods)
            case .monthly: return beyond(.month, of: day, by: step, periods: periods)
            case .yearly: return beyond(.year, of: day, by: step, periods: periods)
            }
        }
        if let months, !months.contains(date.month ?? 0) { return beyond(.month, of: day, by: step, periods: 1) }
        return calendar.date(byAdding: .day, value: step, to: day)
    }

    /// The first day of the month or year `periods` on, or the last day of the one `periods` back.
    private func beyond(_ component: Calendar.Component, of day: Date, by step: Int, periods: Int) -> Date? {
        guard let period = calendar.dateInterval(of: component, for: day) else { return nil }
        if step > 0 { return calendar.date(byAdding: component, value: periods - 1, to: period.end) }
        return calendar.date(byAdding: component, value: -(periods - 1), to: period.start)
            .flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }
    }

    /// The Monday `weeks` weeks on, or the Sunday ending the week `weeks` back: weeks start on
    /// Monday, RRULE's default `WKST`.
    private func beyondWeek(of day: Date, by step: Int, weeks: Int) -> Date? {
        let daysSinceMonday = daysSinceMonday(of: day)
        let days = step > 0 ? 7 - daysSinceMonday + 7 * (weeks - 1) : -(daysSinceMonday + 1) - 7 * (weeks - 1)
        return calendar.date(byAdding: .day, value: days, to: day)
    }

    private func daysSinceMonday(of day: Date) -> Int {
        RepeatRule.Weekday(rawValue: calendar.component(.weekday, from: day))?.mondayFirstIndex ?? 0
    }

    /// How many days, weeks, months or years `day` is after the first, as the interval counts.
    private func periods(to day: Date, _ date: DateComponents) -> Int {
        switch rule.frequency {
        case .daily: calendar.dateComponents([.day], from: firstDay, to: day).day ?? 0
        case .weekly: weeks(from: firstDay, to: day)
        // Counted by the calendar month, as the mockup's `monthDiff` does, so the count never
        // depends on how Foundation measures a month elapsed between two different days.
        case .monthly: ((date.year ?? 0) - (first.year ?? 0)) * 12 + (date.month ?? 0) - (first.month ?? 0)
        case .yearly: (date.year ?? 0) - (first.year ?? 0)
        }
    }

    /// Whether day `day` of a month with `lastDay` days is the rule's month day `wanted`. A day the
    /// month lacks is skipped (RFC 5545) or, for the presets, moved to the last day. A negative
    /// day counts back from the last, and never moves.
    private func isMonthDay(_ wanted: Int, _ day: Int, lastDay: Int) -> Bool {
        if wanted < 0 { return day == lastDay + 1 + wanted }
        return switch rule.missingDay {
        case .skip: day == wanted
        case .lastDayOfMonth: day == min(wanted, lastDay)
        }
    }

    /// Whether `day` is the weekday, and with an ordinal the nth (or nth from last) such weekday of
    /// its month, or of its year when a yearly rule names no months (RFC 5545's BYDAY notes).
    private func matches(_ number: RepeatRule.WeekdayNumber, _ day: Date, _ date: DateComponents, lastDay: Int) -> Bool {
        guard date.weekday == number.weekday.rawValue else { return false }
        guard let ordinal = number.ordinal else { return true }
        let (dayInPeriod, periodLength): (Int, Int)
        if rule.frequency == .yearly && rule.months == nil {
            dayInPeriod = calendar.ordinality(of: .day, in: .year, for: day) ?? 0
            periodLength = calendar.range(of: .day, in: .year, for: day)?.count ?? 365
        } else {
            dayInPeriod = date.day ?? 0
            periodLength = lastDay
        }
        return ordinal > 0
            ? (dayInPeriod - 1) / 7 + 1 == ordinal
            : (periodLength - dayInPeriod) / 7 + 1 == -ordinal
    }

    /// Whole weeks between the weeks holding two days, whatever the calendar's own first weekday.
    private func weeks(from start: Date, to end: Date) -> Int {
        func monday(of day: Date) -> Date {
            calendar.date(byAdding: .day, value: -daysSinceMonday(of: day), to: day) ?? day
        }
        return (calendar.dateComponents([.day], from: monday(of: start), to: monday(of: end)).day ?? 0) / 7
    }
}
