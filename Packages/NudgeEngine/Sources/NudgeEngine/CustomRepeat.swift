import Foundation

/// The Custom repeat page's plain choices (ticket 25): how often, on which days, and when it
/// ends. The person never sees the rule they make (ADR 0003). Whatever depends on a date (the
/// day of the month, the nth weekday, the yearly date) comes from the start, so the engine builds
/// the rule from these choices and a start.
public struct CustomRepeat: Equatable, Sendable {
    /// A new frequency brings the interval within its limits.
    public var frequency: RepeatRule.Frequency {
        didSet { interval = interval.clamped(to: Self.intervals(for: frequency)) }
    }
    /// Every how many days, weeks, months or years.
    public var interval: Int
    /// A weekly repeat's days, never empty.
    public private(set) var weekdays: Set<RepeatRule.Weekday>
    /// A monthly repeat's day. A choice the start doesn't offer falls back to `.dayOfMonth`.
    public var monthlyDay: MonthlyDay
    public var ending: Ending
    /// How many times it falls due when it ends after a count, kept while another ending is chosen.
    public var count: Int
    /// The last day it can fall due when it ends on a date, any time that day. Kept while another
    /// ending is chosen.
    public var endDate: Date

    /// Chooses a weekday, or unchooses it unless it's the last one chosen.
    public mutating func toggle(_ weekday: RepeatRule.Weekday) {
        if !weekdays.contains(weekday) {
            weekdays.insert(weekday)
        } else if weekdays.count > 1 {
            weekdays.remove(weekday)
        }
    }

    /// The Every stepper's limits: up to 30 days, 12 weeks, 12 months or 10 years.
    public static func intervals(for frequency: RepeatRule.Frequency) -> ClosedRange<Int> {
        switch frequency {
        case .daily: 1...30
        case .weekly, .monthly: 1...12
        case .yearly: 1...10
        }
    }

    /// The After stepper's limits.
    public static let counts = 2...30

    /// The Ends choice.
    public enum Ending: Hashable, Sendable {
        case never
        case afterCount
        case onDate
    }

    /// Where a monthly repeat falls in each month, worked out from the start date.
    public enum MonthlyDay: Hashable, Sendable {
        /// The start's day of the month: "On the 28th".
        case dayOfMonth
        /// The start's weekday, counted from the month's start: "On the fourth Monday".
        case weekdayOfMonth
        /// The start's weekday, the last in the month: "On the last Monday".
        case lastWeekdayOfMonth
        /// "On the last day".
        case lastDay
    }
}

extension Engine {
    /// The Custom page's choices for a repeat: a custom rule's own, or a preset's (Never is `nil`)
    /// as a custom repeat, so Custom starts from what was chosen.
    public func customRepeat(from rule: RepeatRule?, startingAt start: Date) -> CustomRepeat {
        let frequency = rule?.frequency ?? .weekly
        var choices = CustomRepeat(
            frequency: frequency,
            interval: (rule?.interval ?? 1).clamped(to: CustomRepeat.intervals(for: frequency)),
            weekdays: frequency == .weekly ? rule?.weekdays.map { Set($0.map(\.weekday)) } ?? [startWeekday(of: start)] : [startWeekday(of: start)],
            monthlyDay: frequency == .monthly ? rule.map(monthlyDay(of:)) ?? .dayOfMonth : .dayOfMonth,
            ending: .never,
            count: 10,
            endDate: calendar.date(byAdding: .month, value: 3, to: start) ?? start
        )
        switch rule?.end {
        case nil: break
        case .count(let count):
            choices.ending = .afterCount
            choices.count = count.clamped(to: CustomRepeat.counts)
        case let .untilDate(year, month, day):
            choices.ending = .onDate
            choices.endDate = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? choices.endDate
        case .untilTime(let time):
            choices.ending = .onDate
            choices.endDate = time
        }
        return choices
    }

    /// A monthly rule's choice, from the parts the page writes for each.
    private func monthlyDay(of rule: RepeatRule) -> CustomRepeat.MonthlyDay {
        if let ordinal = rule.weekdays?.first?.ordinal { return ordinal < 0 ? .lastWeekdayOfMonth : .weekdayOfMonth }
        return rule.monthDays == [-1] ? .lastDay : .dayOfMonth
    }

    /// The rule the choices make for this start.
    public func repeatRule(for choices: CustomRepeat, startingAt start: Date) -> RepeatRule {
        let day = calendar.component(.day, from: start)
        let weekday = startWeekday(of: start)
        var rule = switch choices.frequency {
        case .daily:
            RepeatRule(.daily, checkedInterval: choices.interval)
        case .weekly:
            RepeatRule(.weekly, checkedInterval: choices.interval, weekdays: Set(choices.weekdays.map { RepeatRule.WeekdayNumber($0) }))
        case .monthly:
            switch monthlyDay(of: choices, startingAt: start) {
            case .dayOfMonth: RepeatRule(.monthly, checkedInterval: choices.interval, monthDays: [day])
            case .weekdayOfMonth: RepeatRule(.monthly, checkedInterval: choices.interval, weekdays: [RepeatRule.WeekdayNumber(weekday, ordinal: weekdayOrdinal(ofDay: day))])
            case .lastWeekdayOfMonth: RepeatRule(.monthly, checkedInterval: choices.interval, weekdays: [RepeatRule.WeekdayNumber(weekday, ordinal: -1)])
            case .lastDay: RepeatRule(.monthly, checkedInterval: choices.interval, monthDays: [-1])
            }
        case .yearly:
            // Its day and month written out, as the mockup's `customRule` writes them.
            RepeatRule(.yearly, checkedInterval: choices.interval, monthDays: [day], months: [calendar.component(.month, from: start)])
        }
        switch choices.ending {
        case .never: break
        case .afterCount: rule.end = .count(choices.count)
        case .onDate:
            let end = choices.endDate
            rule.end = .untilDate(year: calendar.component(.year, from: end), month: calendar.component(.month, from: end),
                                  day: calendar.component(.day, from: end))
        }
        return rule
    }

    /// Whether the choices end on a day before the start's, the mockup's `untilTooEarly`. The
    /// end date is a whole day, so ending on the start's own day is fine.
    public func endsBeforeStart(_ choices: CustomRepeat, startingAt start: Date) -> Bool {
        choices.ending == .onDate && calendar.startOfDay(for: choices.endDate) < calendar.startOfDay(for: start)
    }

    /// The ways a monthly repeat can fall, given the start, as the mockup's `monthlyOptions`: its
    /// day; its nth weekday for the first to the fourth (a fifth isn't in every month); the last
    /// such weekday when the start is in the month's last seven days; and the last day.
    public func monthlyDays(startingAt start: Date) -> [CustomRepeat.MonthlyDay] {
        let day = calendar.component(.day, from: start)
        let daysInMonth = calendar.range(of: .day, in: .month, for: start)?.count ?? 31
        var choices: [CustomRepeat.MonthlyDay] = [.dayOfMonth]
        if weekdayOrdinal(ofDay: day) <= 4 { choices.append(.weekdayOfMonth) }
        if day + 7 > daysInMonth { choices.append(.lastWeekdayOfMonth) }
        choices.append(.lastDay)
        return choices
    }

    /// The monthly choice the rule uses for this start, the one the page checks: the chosen one,
    /// or the day of the month if the start doesn't offer it.
    public func monthlyDay(of choices: CustomRepeat, startingAt start: Date) -> CustomRepeat.MonthlyDay {
        monthlyDays(startingAt: start).contains(choices.monthlyDay) ? choices.monthlyDay : .dayOfMonth
    }

    /// A monthly choice as the page lists it for this start, such as "On the fourth Monday". Its
    /// words come from the engine's String Catalog; the weekday and the ordinal follow its locale.
    /// Only for a choice `monthlyDays(startingAt:)` offers for this start.
    public func title(of monthlyDay: CustomRepeat.MonthlyDay, startingAt start: Date) -> String {
        let words = RepeatSummaryWriter(locale: locale, calendar: calendar, now: clock.now)
        let day = calendar.component(.day, from: start)
        let weekday = words.name(startWeekday(of: start))
        switch monthlyDay {
        case .dayOfMonth:
            let ordinal = words.ordinalNumber(day)
            return String(localized: "On the \(ordinal)", bundle: .module, locale: locale,
                          comment: "Custom repeat page: a monthly repeat on the start's day of the month. The placeholder is the ordinal number, such as \"28th\".")
        case .weekdayOfMonth:
            return switch weekdayOrdinal(ofDay: day) {
            case 1: String(localized: "On the first \(weekday)", bundle: .module, locale: locale, comment: "Custom repeat page: a monthly repeat on the first of the start's weekday. The placeholder is the weekday.")
            case 2: String(localized: "On the second \(weekday)", bundle: .module, locale: locale, comment: "Custom repeat page: a monthly repeat on the second of the start's weekday. The placeholder is the weekday.")
            case 3: String(localized: "On the third \(weekday)", bundle: .module, locale: locale, comment: "Custom repeat page: a monthly repeat on the third of the start's weekday. The placeholder is the weekday.")
            default: String(localized: "On the fourth \(weekday)", bundle: .module, locale: locale, comment: "Custom repeat page: a monthly repeat on the fourth of the start's weekday. The placeholder is the weekday.")
            }
        case .lastWeekdayOfMonth:
            return String(localized: "On the last \(weekday)", bundle: .module, locale: locale,
                          comment: "Custom repeat page: a monthly repeat on the last of the start's weekday in each month. The placeholder is the weekday.")
        case .lastDay:
            return String(localized: "On the last day", bundle: .module, locale: locale,
                          comment: "Custom repeat page: a monthly repeat on the last day of each month.")
        }
    }

    /// Under a monthly choice of a day some months lack (the 29th to the 31st), which RFC 5545
    /// skips (ADR 0003): "Months without a 31st are skipped. Choose On the last day to get every
    /// month." `nil` for any other choice.
    public func skippedMonthsNote(of choices: CustomRepeat, startingAt start: Date) -> String? {
        let day = calendar.component(.day, from: start)
        guard monthlyDay(of: choices, startingAt: start) == .dayOfMonth, day > 28 else { return nil }
        let ordinal = RepeatSummaryWriter(locale: locale, calendar: calendar, now: clock.now).ordinalNumber(day)
        return String(localized: "Months without a \(ordinal) are skipped. Choose On the last day to get every month.", bundle: .module, locale: locale,
                      comment: "Under the Custom repeat page's monthly days when the start is the 29th to the 31st. The placeholder is the ordinal day, such as \"31st\". \"On the last day\" is the choice's title.")
    }

    /// A weekday's name in the engine's locale, as the Custom page lists it.
    public func name(of weekday: RepeatRule.Weekday) -> String {
        RepeatSummaryWriter(locale: locale, calendar: calendar, now: clock.now).name(weekday)
    }

    /// Which of its weekday in the month a day is: the 22nd is the fourth.
    private func weekdayOrdinal(ofDay day: Int) -> Int {
        (day + 6) / 7
    }

    private func startWeekday(of start: Date) -> RepeatRule.Weekday {
        // A Gregorian weekday is 1 to 7, Sunday first, as `Weekday`'s raw values, so the
        // fallback is never used.
        RepeatRule.Weekday(rawValue: calendar.component(.weekday, from: start)) ?? .monday
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
