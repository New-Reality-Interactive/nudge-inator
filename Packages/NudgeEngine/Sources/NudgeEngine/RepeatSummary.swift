import Foundation

extension Engine {
    /// The repeat in plain words, with its time of day and how it ends, such as "Every 2 weeks on
    /// Monday and Wednesday at 9:00 AM, 5 times". The form, the Repeat and Custom pages and the
    /// details screen all show this one string. Its words come from the engine's String Catalog,
    /// in the app's language; its names, lists, times and dates follow the engine's locale and
    /// time zone. The reminder needn't be one the engine holds, so a draft can be summarised.
    public func repeatSummary(of reminder: Reminder) -> String {
        RepeatSummaryWriter(locale: locale, calendar: calendar, now: clock.now).summary(of: reminder)
    }

    /// "Today", "Tomorrow", "Yesterday" or a short date such as "Tue, Oct 20", in the engine's
    /// locale and time zone, as a one-off's summary says it: the Now rows' day.
    public func dayLabel(of date: Date) -> String {
        RepeatSummaryWriter(locale: locale, calendar: calendar, now: clock.now).dayLabel(of: date)
    }

    /// The time of day, such as "9:00 AM", in the engine's locale and time zone.
    public func timeOfDay(of date: Date) -> String {
        RepeatSummaryWriter(locale: locale, calendar: calendar, now: clock.now).time(of: date)
    }
}

/// Writes a repeat summary. Each piece of wording is one catalog string whose comment says what
/// its placeholders hold, so a translation can reorder them; words that agree with each other
/// (an ordinal and its weekday, "a" and its weekdays) are in the same string. A summary nests
/// these templates, as RFC 5545 rules combine.
struct RepeatSummaryWriter {
    let locale: Locale
    let calendar: Calendar
    let now: Date
    /// Weekday and month names as they stand alone, as in a list, Sunday and January first.
    private let weekdayNames: [String]
    private let monthNames: [String]
    private let ordinals: NumberFormatter

    init(locale: Locale, calendar: Calendar, now: Date) {
        self.locale = locale
        self.calendar = calendar
        self.now = now
        var names = Calendar(identifier: .gregorian)
        names.locale = locale
        weekdayNames = names.standaloneWeekdaySymbols
        monthNames = names.standaloneMonthSymbols
        ordinals = NumberFormatter()
        ordinals.locale = locale
        ordinals.numberStyle = .ordinal
    }

    func summary(of reminder: Reminder) -> String {
        let time = time(of: reminder.dueTime)
        guard let rule = reminder.repeatRule else {
            let day = dayLabel(of: reminder.dueTime)
            return String(localized: "Once, \(day) at \(time)", bundle: .module, locale: locale,
                          comment: "Repeat summary of a reminder that doesn't repeat. 1: Today, Tomorrow, Yesterday or a short date. 2: its time.")
        }
        let first = calendar.dateComponents([.year, .month, .day, .weekday], from: reminder.dueTime)
        let phrase = phrase(of: rule, first: first)
        switch rule.end {
        case nil:
            return atTime(phrase, time)
        case .count(let count):
            let times = String(localized: "\(count) times", bundle: .module, locale: locale,
                               comment: "Repeat summary: how many times a repeat happens before it ends. Singular: \"once\".")
            return String(localized: "\(phrase) at \(time), \(times)", bundle: .module, locale: locale,
                          comment: "Repeat summary of a repeat that ends after some times. 1: what the rule falls on. 2: the time. 3: how many times, such as \"5 times\" or \"once\".")
        case let .untilDate(year, month, day):
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return atTime(phrase, time) }
            return until(phrase, time, date: date, endTime: nil)
        case .untilTime(let end):
            // An UNTIL at the last second of a local day is that whole day, which is how the
            // editor writes an end date; any other time is part of the ending.
            let endOfDay = calendar.dateComponents([.hour, .minute, .second], from: end) == DateComponents(hour: 23, minute: 59, second: 59)
            return until(phrase, time, date: end, endTime: endOfDay ? nil : self.time(of: end))
        }
    }

    private func atTime(_ phrase: String, _ time: String) -> String {
        String(localized: "\(phrase) at \(time)", bundle: .module, locale: locale,
               comment: "Repeat summary. 1: what the rule falls on, such as \"Every 2 weeks on Monday\". 2: the time.")
    }

    private func until(_ phrase: String, _ time: String, date: Date, endTime: String?) -> String {
        let date = shortDate(of: date)
        guard let endTime else {
            return String(localized: "\(phrase) at \(time), until \(date)", bundle: .module, locale: locale,
                          comment: "Repeat summary of a repeat with an end date. 1: what the rule falls on. 2: the time. 3: the last date, short.")
        }
        return String(localized: "\(phrase) at \(time), until \(date) at \(endTime)", bundle: .module, locale: locale,
                      comment: "Repeat summary of a repeat that ends at a time. 1: what the rule falls on. 2: the time. 3: the last date, short. 4: the time it ends.")
    }

    /// "Today", "Tomorrow", "Yesterday" or the short date, as the mockup's `dayLabel`.
    func dayLabel(of date: Date) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day
        return switch days {
        case 0: String(localized: "Today", bundle: .module, locale: locale, comment: "Repeat summary: a one-off reminder's day, as in \"Once, Today at 9:00\".")
        case 1: String(localized: "Tomorrow", bundle: .module, locale: locale, comment: "Repeat summary: a one-off reminder's day, as in \"Once, Tomorrow at 9:00\".")
        case -1: String(localized: "Yesterday", bundle: .module, locale: locale, comment: "Repeat summary: a one-off reminder's day, as in \"Once, Yesterday at 9:00\".")
        default: shortDate(of: date)
        }
    }

    func time(of date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone))
    }

    /// "Sat 10 Oct" in en_GB, "Sat, Oct 10" in en_US.
    private func shortDate(of date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated).day().month(.abbreviated))
    }

    /// What the rule falls on, before its time: "Every 2 weeks on Monday and Wednesday". The
    /// parts the rule leaves out come from the first due time, as RFC 5545 and the walk take them.
    private func phrase(of rule: RepeatRule, first: DateComponents) -> String {
        let every = every(rule)
        let noDayParts = rule.weekdays == nil && rule.monthDays == nil
        switch rule.frequency {
        case .daily:
            return limited(limited(every, toWeekdays: rule.weekdays, monthDays: rule.monthDays), toMonths: rule.months)
        case .weekly:
            let days = rule.weekdays.map { $0.map(\.weekday) } ?? first.weekday.flatMap(RepeatRule.Weekday.init).map { [$0] } ?? []
            let sorted = Set(days).sorted { $0.mondayFirstIndex < $1.mondayFirstIndex }
            if rule.interval == 1 && rule.months == nil && sorted == [.monday, .tuesday, .wednesday, .thursday, .friday] {
                return String(localized: "Every weekday", bundle: .module, locale: locale, comment: "Repeat summary: a repeat on Monday to Friday.")
            }
            let names = andList(sorted.map(name))
            let phrase = rule.interval > 1
                ? on(every, names)
                : String(localized: "Every \(names)", bundle: .module, locale: locale,
                         comment: "Repeat summary of a weekly repeat. The placeholder is the weekdays, such as \"Monday and Friday\".")
            return limited(phrase, toMonths: rule.months)
        case .monthly:
            let monthDays = noDayParts ? first.day.map { [$0] } : rule.monthDays
            let phrase = on(every, days(weekdays: rule.weekdays, monthDays: monthDays))
            return note(limited(phrase, toMonths: rule.months), for: rule, monthDays: monthDays, months: rule.months)
        case .yearly:
            let monthDays = noDayParts ? first.day.map { [$0] } : rule.monthDays
            let months = noDayParts ? rule.months ?? first.month.map { [$0] } : rule.months
            // "on 29 February", as the mockup words its one-day yearly rule, for a day the month has.
            if rule.weekdays == nil, let months, months.count == 1, let month = months.first,
               let monthDays, monthDays.count == 1, let day = monthDays.first, let date = dayAndMonth(day, month) {
                return note(on(every, date), for: rule, monthDays: monthDays, months: months)
            }
            let period: Period = if let months { .months(months) } else if monthDays != nil { .everyMonth } else { .year }
            return note(on(every, days(weekdays: rule.weekdays, monthDays: monthDays, in: period)), for: rule, monthDays: monthDays, months: months)
        }
    }

    /// "Every day", or "Every 3 days" when the interval is more than 1: the catalog's plural
    /// variants pick the wording.
    private func every(_ rule: RepeatRule) -> String {
        let interval = rule.interval
        return switch rule.frequency {
        case .daily: String(localized: "Every \(interval) days", bundle: .module, locale: locale, comment: "Repeat summary: how often a reminder repeats. Singular: \"Every day\".")
        case .weekly: String(localized: "Every \(interval) weeks", bundle: .module, locale: locale, comment: "Repeat summary: how often a reminder repeats. Singular: \"Every week\".")
        case .monthly: String(localized: "Every \(interval) months", bundle: .module, locale: locale, comment: "Repeat summary: how often a reminder repeats. Singular: \"Every month\".")
        case .yearly: String(localized: "Every \(interval) years", bundle: .module, locale: locale, comment: "Repeat summary: how often a reminder repeats. Singular: \"Every year\".")
        }
    }

    private func on(_ every: String, _ days: String) -> String {
        String(localized: "\(every) on \(days)", bundle: .module, locale: locale,
               comment: "Repeat summary. 1: how often, such as \"Every 2 weeks\". 2: the days it falls on, such as \"Monday and Wednesday\" or \"the 15th\".")
    }

    /// Where a yearly rule's days are counted: in some months, in every month, or in the year.
    private enum Period {
        case months(Set<Int>)
        case everyMonth
        case year
    }

    /// "the 15th", "the first Monday", "the 13th when it's a Friday", "the last Monday of May".
    private func days(weekdays: Set<RepeatRule.WeekdayNumber>?, monthDays: Set<Int>?, in period: Period? = nil) -> String {
        let days = if let monthDays {
            andList(Self.sorted(monthDays).map(monthDayName))
        } else {
            andList((weekdays ?? []).sorted().map { weekdayName($0, every: true) })
        }
        let inPeriod = switch period {
        case nil: days
        case .months(let months):
            String(localized: "\(days) of \(andList(months.sorted().map(monthName)))", bundle: .module, locale: locale,
                   comment: "Repeat summary: a yearly repeat's days in some months. 1: the days, such as \"the last Monday\". 2: the months, such as \"May\".")
        case .everyMonth:
            String(localized: "\(days) of every month", bundle: .module, locale: locale,
                   comment: "Repeat summary: a yearly repeat's days in each month. The placeholder is the days, such as \"the 1st\".")
        case .year:
            String(localized: "\(days) of the year", bundle: .module, locale: locale,
                   comment: "Repeat summary: a yearly repeat's weekdays counted in the year. The placeholder is the days, such as \"the first Monday\".")
        }
        return monthDays == nil ? inPeriod : limited(inPeriod, toWeekdays: weekdays, monthDays: nil)
    }

    /// A limit on the days: "… when it's a Monday or Friday", "… when it's the 1st or the 15th",
    /// "… when it's the 13th and a Friday".
    private func limited(_ phrase: String, toWeekdays weekdays: Set<RepeatRule.WeekdayNumber>?, monthDays: Set<Int>?) -> String {
        let days = monthDays.map { orList(Self.sorted($0).map(monthDayName)) }
        let sortedWeekdays = weekdays?.sorted() ?? []
        let names = weekdays.map { _ in orList(sortedWeekdays.map { weekdayName($0, every: false) }) }
        // "the first Monday" already has its article; a plain weekday takes "a".
        let counted = sortedWeekdays.first?.ordinal != nil
        switch (days, names) {
        case (nil, nil):
            return phrase
        case let (days?, nil):
            return limited(phrase, to: days)
        case let (nil, names?):
            return counted
                ? limited(phrase, to: names)
                : String(localized: "\(phrase) when it's a \(names)", bundle: .module, locale: locale,
                         comment: "Repeat summary: a repeat limited to some weekdays. 1: the repeat, such as \"Every day\". 2: the weekdays, such as \"Monday or Friday\".")
        case let (days?, names?):
            return counted
                ? String(localized: "\(phrase) when it's \(days) and \(names)", bundle: .module, locale: locale,
                         comment: "Repeat summary: a repeat limited to days that are also certain weekdays. 1: the repeat. 2: the days, such as \"the 13th\". 3: the weekdays, such as \"the first Monday\".")
                : String(localized: "\(phrase) when it's \(days) and a \(names)", bundle: .module, locale: locale,
                         comment: "Repeat summary: a repeat limited to days that are also certain weekdays. 1: the repeat. 2: the days, such as \"the 13th\". 3: the weekdays, such as \"Friday\".")
        }
    }

    private func limited(_ phrase: String, to days: String) -> String {
        String(localized: "\(phrase) when it's \(days)", bundle: .module, locale: locale,
               comment: "Repeat summary: a repeat limited to some days. 1: the repeat, such as \"Every day\". 2: the days, such as \"the 1st or the 15th\" or \"the first Monday\".")
    }

    /// "… in January and July", for a rule limited to some months.
    private func limited(_ phrase: String, toMonths months: Set<Int>?) -> String {
        guard let months else { return phrase }
        let names = andList(months.sorted().map(monthName))
        return String(localized: "\(phrase) in \(names)", bundle: .module, locale: locale,
                      comment: "Repeat summary: a repeat limited to some months. 1: the repeat, such as \"Every day\". 2: the months, such as \"January and July\".")
    }

    /// What happens where a day is missing: a custom rule skips that month or year (RFC 5545),
    /// and a preset moves to the last day (ADR 0003). Months that have the day get no note.
    /// `monthDays` and `months` are the ones the rule falls on, filled from its first due time
    /// where the rule leaves them out.
    private func note(_ phrase: String, for rule: RepeatRule, monthDays: Set<Int>?, months: Set<Int>?) -> String {
        // The fewest days any of the rule's months has: 28, unless it names only longer months.
        let shortest = months.map { $0.map(Self.fewestDays).min() ?? 28 } ?? 28
        let lacksDay = monthDays?.contains { abs($0) > shortest } == true
        // A month has four or five of each weekday, and a year 52 or 53.
        let ordinalsSomeLack = rule.frequency == .yearly && months == nil ? 53 : 5
        let lacksWeekday = rule.weekdays?.contains { abs($0.ordinal ?? 0) >= ordinalsSomeLack } == true
        guard lacksDay || lacksWeekday else { return phrase }
        switch (rule.missingDay, rule.frequency == .yearly) {
        case (.skip, false):
            return String(localized: "\(phrase) (skipped in months without one)", bundle: .module, locale: locale,
                          comment: "Repeat summary: a custom monthly repeat on a day some months lack. The placeholder is the repeat.")
        case (.skip, true):
            return String(localized: "\(phrase) (skipped in years without one)", bundle: .module, locale: locale,
                          comment: "Repeat summary: a custom yearly repeat on a day some years lack. The placeholder is the repeat.")
        case (.lastDayOfMonth, true) where months == [2]:
            let lastDay = dayAndMonth(28, 2) ?? ""
            return String(localized: "\(phrase) (\(lastDay) in years without one)", bundle: .module, locale: locale,
                          comment: "Repeat summary: a yearly preset on 29 February, which moves to the 28th in other years. 1: the repeat. 2: the day it moves to, such as \"28 February\".")
        case (.lastDayOfMonth, false):
            return String(localized: "\(phrase) (the last day in months without one)", bundle: .module, locale: locale,
                          comment: "Repeat summary: a monthly preset on a day some months lack, which moves to their last day. The placeholder is the repeat.")
        case (.lastDayOfMonth, true):
            return String(localized: "\(phrase) (the last day in years without one)", bundle: .module, locale: locale,
                          comment: "Repeat summary: a yearly preset on a day some years lack, which moves to the month's last day. The placeholder is the repeat.")
        }
    }

    /// "the first Monday", "the last Friday", "the 6th Monday"; with no ordinal "every Monday",
    /// or within a condition "Monday".
    private func weekdayName(_ number: RepeatRule.WeekdayNumber, every: Bool) -> String {
        let name = name(number.weekday)
        switch number.ordinal {
        case nil:
            return every
                ? String(localized: "every \(name)", bundle: .module, locale: locale,
                         comment: "Repeat summary: each of a weekday in a month or year, as in \"Every month on every Monday\".")
                : name
        case 1: return String(localized: "the first \(name)", bundle: .module, locale: locale, comment: "Repeat summary: the first of a weekday in a month or year. The placeholder is the weekday.")
        case 2: return String(localized: "the second \(name)", bundle: .module, locale: locale, comment: "Repeat summary: the second of a weekday in a month or year. The placeholder is the weekday.")
        case 3: return String(localized: "the third \(name)", bundle: .module, locale: locale, comment: "Repeat summary: the third of a weekday in a month or year. The placeholder is the weekday.")
        case 4: return String(localized: "the fourth \(name)", bundle: .module, locale: locale, comment: "Repeat summary: the fourth of a weekday in a month or year. The placeholder is the weekday.")
        case 5: return String(localized: "the fifth \(name)", bundle: .module, locale: locale, comment: "Repeat summary: the fifth of a weekday in a month or year. The placeholder is the weekday.")
        case -1: return String(localized: "the last \(name)", bundle: .module, locale: locale, comment: "Repeat summary: the last of a weekday in a month or year. The placeholder is the weekday.")
        case -2: return String(localized: "the second-to-last \(name)", bundle: .module, locale: locale, comment: "Repeat summary: a weekday counted from the end of a month or year. The placeholder is the weekday.")
        case -3: return String(localized: "the third-to-last \(name)", bundle: .module, locale: locale, comment: "Repeat summary: a weekday counted from the end of a month or year. The placeholder is the weekday.")
        case -4: return String(localized: "the fourth-to-last \(name)", bundle: .module, locale: locale, comment: "Repeat summary: a weekday counted from the end of a month or year. The placeholder is the weekday.")
        case -5: return String(localized: "the fifth-to-last \(name)", bundle: .module, locale: locale, comment: "Repeat summary: a weekday counted from the end of a month or year. The placeholder is the weekday.")
        case let ordinal? where ordinal > 0:
            return String(localized: "the \(ordinalNumber(ordinal)) \(name)", bundle: .module, locale: locale,
                          comment: "Repeat summary: one weekday of a year, counted from its start. 1: the ordinal number, such as \"6th\". 2: the weekday.")
        case let ordinal?:
            return String(localized: "the \(ordinalNumber(-ordinal))-to-last \(name)", bundle: .module, locale: locale,
                          comment: "Repeat summary: one weekday counted from the end of a month or year. 1: the ordinal number, such as \"6th\". 2: the weekday.")
        }
    }

    /// "the 15th", "the last day", "the second-to-last day".
    private func monthDayName(_ day: Int) -> String {
        switch day {
        case -1: String(localized: "the last day", bundle: .module, locale: locale, comment: "Repeat summary: the last day of the month.")
        case -2: String(localized: "the second-to-last day", bundle: .module, locale: locale, comment: "Repeat summary: a day counted from the end of the month.")
        case -3: String(localized: "the third-to-last day", bundle: .module, locale: locale, comment: "Repeat summary: a day counted from the end of the month.")
        case -4: String(localized: "the fourth-to-last day", bundle: .module, locale: locale, comment: "Repeat summary: a day counted from the end of the month.")
        case -5: String(localized: "the fifth-to-last day", bundle: .module, locale: locale, comment: "Repeat summary: a day counted from the end of the month.")
        case let day where day > 0:
            String(localized: "the \(ordinalNumber(day))", bundle: .module, locale: locale,
                   comment: "Repeat summary: a day of the month, as in \"Every month on the 15th\". The placeholder is the ordinal number, such as \"15th\".")
        default:
            String(localized: "the \(ordinalNumber(-day))-to-last day", bundle: .module, locale: locale,
                   comment: "Repeat summary: a day counted from the end of the month. The placeholder is the ordinal number, such as \"6th\".")
        }
    }

    /// "1st", "2nd", "11th", "23rd" in English: Foundation's ordinal numbers for the locale.
    func ordinalNumber(_ number: Int) -> String {
        ordinals.string(from: number as NSNumber) ?? number.formatted(.number.locale(locale))
    }

    /// "29 February" in en_GB, "February 29" in en_US: the locale's order for a day and month.
    /// `nil` for a day the month never has, such as 30 February.
    private func dayAndMonth(_ day: Int, _ month: Int) -> String? {
        // A leap year, so 29 February exists, in UTC, the zone it's formatted in. The calendar
        // would roll an impossible day into the next month, so the date must read back the same.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        guard let date = utc.date(from: DateComponents(year: 2000, month: month, day: day)),
              utc.dateComponents([.month, .day], from: date) == DateComponents(month: month, day: day) else { return nil }
        return date.formatted(Date.FormatStyle(locale: locale, calendar: utc, timeZone: .gmt).day().month(.wide))
    }

    func name(_ weekday: RepeatRule.Weekday) -> String {
        weekdayNames[weekday.rawValue - 1]
    }

    private func monthName(_ month: Int) -> String {
        monthNames.indices.contains(month - 1) ? monthNames[month - 1] : ""
    }

    /// "Monday, Wednesday and Sunday" in en_GB, with the serial comma in en_US.
    private func andList(_ items: [String]) -> String {
        items.formatted(.list(type: .and).locale(locale))
    }

    /// "Monday or Friday".
    private func orList(_ items: [String]) -> String {
        items.formatted(.list(type: .or).locale(locale))
    }

    /// The days of the month, then the days counted back from its end.
    private static func sorted(_ monthDays: Set<Int>) -> [Int] {
        monthDays.filter { $0 > 0 }.sorted() + monthDays.filter { $0 < 0 }.sorted(by: >)
    }

    /// The fewest days a month has in any year: February has 28.
    private static func fewestDays(_ month: Int) -> Int {
        switch month {
        case 2: 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }
}
