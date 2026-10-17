import Foundation

extension Engine {
    /// The repeat in plain words, with its time of day and how it ends, such as "Every 2 weeks on
    /// Monday and Wednesday at 9:00 AM, 5 times". The form, the Repeat and Custom pages and the
    /// details screen all show this one string. Its words come from the engine's String Catalog,
    /// in the app's language; its names, lists, times and dates follow the engine's locale and
    /// time zone. The reminder needn't be one the engine holds, so a draft can be summarised.
    public func repeatSummary(of reminder: Reminder) -> String {
        SummaryWords(locale: locale, calendar: calendar, now: clock.now).summary(of: reminder)
    }
}

/// Builds a repeat summary. Each piece of wording is one catalog string whose comment says what
/// its placeholders hold, so a translation can reorder them. A summary nests these templates, as
/// RFC 5545 rules combine.
private struct SummaryWords {
    let locale: Locale
    let calendar: Calendar
    let now: Date

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
            return String(localized: "\(phrase) at \(time)", bundle: .module, locale: locale,
                          comment: "Repeat summary. 1: what the rule falls on, such as \"Every 2 weeks on Monday\". 2: the time.")
        case .count(let count):
            let times = String(localized: "\(count) times", bundle: .module, locale: locale,
                               comment: "Repeat summary: how many times a repeat happens before it ends. Singular: \"once\".")
            return String(localized: "\(phrase) at \(time), \(times)", bundle: .module, locale: locale,
                          comment: "Repeat summary of a repeat that ends after some times. 1: what the rule falls on. 2: the time. 3: how many times, such as \"5 times\" or \"once\".")
        case let .untilDate(year, month, day):
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                return String(localized: "\(phrase) at \(time)", bundle: .module, locale: locale,
                              comment: "Repeat summary. 1: what the rule falls on, such as \"Every 2 weeks on Monday\". 2: the time.")
            }
            return until(phrase: phrase, time: time, date: date, endTime: nil)
        case .untilTime(let end):
            // An UNTIL at the last second of a local day is that whole day, which is how the
            // editor writes an end date; any other time is part of the ending.
            let endOfDay = calendar.dateComponents([.hour, .minute, .second], from: end) == DateComponents(hour: 23, minute: 59, second: 59)
            return until(phrase: phrase, time: time, date: end, endTime: endOfDay ? nil : self.time(of: end))
        }
    }

    private func until(phrase: String, time: String, date: Date, endTime: String?) -> String {
        let date = shortDate(of: date)
        guard let endTime else {
            return String(localized: "\(phrase) at \(time), until \(date)", bundle: .module, locale: locale,
                          comment: "Repeat summary of a repeat with an end date. 1: what the rule falls on. 2: the time. 3: the last date, short.")
        }
        return String(localized: "\(phrase) at \(time), until \(date) at \(endTime)", bundle: .module, locale: locale,
                      comment: "Repeat summary of a repeat that ends at a time. 1: what the rule falls on. 2: the time. 3: the last date, short. 4: the time it ends.")
    }

    /// "Today", "Tomorrow", "Yesterday" or the short date, as the mockup's `dayLabel`.
    private func dayLabel(of date: Date) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day
        return switch days {
        case 0: String(localized: "Today", bundle: .module, locale: locale, comment: "Repeat summary: a one-off reminder's day, as in \"Once, Today at 9:00\".")
        case 1: String(localized: "Tomorrow", bundle: .module, locale: locale, comment: "Repeat summary: a one-off reminder's day, as in \"Once, Tomorrow at 9:00\".")
        case -1: String(localized: "Yesterday", bundle: .module, locale: locale, comment: "Repeat summary: a one-off reminder's day, as in \"Once, Yesterday at 9:00\".")
        default: shortDate(of: date)
        }
    }

    private func time(of date: Date) -> String {
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
            return inMonths(rule.months, when(every, weekdays: rule.weekdays, monthDays: rule.monthDays))
        case .weekly:
            let days = rule.weekdays.map { $0.map(\.weekday) } ?? first.weekday.flatMap(RepeatRule.Weekday.init).map { [$0] } ?? []
            let sorted = Set(days).sorted { $0.mondayFirstIndex < $1.mondayFirstIndex }
            if rule.interval == 1 && rule.months == nil && sorted == [.monday, .tuesday, .wednesday, .thursday, .friday] {
                return String(localized: "Every weekday", bundle: .module, locale: locale, comment: "Repeat summary: a repeat on Monday to Friday.")
            }
            let names = and(sorted.map(name))
            let phrase = rule.interval > 1
                ? String(localized: "\(every) on \(names)", bundle: .module, locale: locale,
                         comment: "Repeat summary. 1: how often, such as \"Every 2 weeks\". 2: the days it falls on, such as \"Monday and Wednesday\" or \"the 15th\".")
                : String(localized: "Every \(names)", bundle: .module, locale: locale,
                         comment: "Repeat summary of a weekly repeat. The placeholder is the weekdays, such as \"Monday and Friday\".")
            return inMonths(rule.months, phrase)
        case .monthly:
            let monthDays = noDayParts ? first.day.map { [$0] } : rule.monthDays
            let phrase = on(every, days(weekdays: rule.weekdays, monthDays: monthDays))
            return note(inMonths(rule.months, phrase), rule: rule, monthDays: monthDays, months: rule.months)
        case .yearly:
            let monthDays = noDayParts ? first.day.map { [$0] } : rule.monthDays
            let months = noDayParts ? rule.months ?? first.month.map { [$0] } : rule.months
            // "on 29 February", as the mockup words its one-day yearly rule.
            if rule.weekdays == nil, let months, months.count == 1, let month = months.first,
               let monthDays, monthDays.count == 1, let day = monthDays.first, day > 0 {
                return note(on(every, dayOfMonth(day, month)), rule: rule, monthDays: monthDays, months: months)
            }
            let period = if let months {
                and(months.sorted().map(monthName))
            } else if monthDays != nil {
                String(localized: "every month", bundle: .module, locale: locale,
                       comment: "Repeat summary: the months a yearly repeat's days are in, as in \"the 1st of every month\".")
            } else {
                String(localized: "the year", bundle: .module, locale: locale,
                       comment: "Repeat summary: the period a yearly repeat's weekday counts in, as in \"the first Monday of the year\".")
            }
            return note(on(every, days(weekdays: rule.weekdays, monthDays: monthDays, of: period)), rule: rule, monthDays: monthDays, months: months)
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

    /// "the 15th", "the first Monday", "the 13th when it's a Friday", "the last Monday of May".
    private func days(weekdays: Set<RepeatRule.WeekdayNumber>?, monthDays: Set<Int>?, of period: String? = nil) -> String {
        let days = if let monthDays {
            and(Self.sorted(monthDays).map(monthDayName))
        } else {
            and((weekdays ?? []).sorted().map { weekdayName($0, every: true) })
        }
        let ofPeriod = period.map {
            String(localized: "\(days) of \($0)", bundle: .module, locale: locale,
                   comment: "Repeat summary. 1: days, such as \"the last Monday\". 2: the months or period they're in, such as \"May\" or \"the year\".")
        } ?? days
        return monthDays == nil ? ofPeriod : when(ofPeriod, weekdays: weekdays, monthDays: nil)
    }

    /// A limit on the days: "… when it's a Monday or Friday", "… when it's the 1st or the 15th".
    private func when(_ phrase: String, weekdays: Set<RepeatRule.WeekdayNumber>?, monthDays: Set<Int>?) -> String {
        var options: [String] = []
        if let monthDays { options.append(or(Self.sorted(monthDays).map(monthDayName))) }
        if let weekdays {
            let sorted = weekdays.sorted()
            let names = or(sorted.map { weekdayName($0, every: false) })
            options.append(sorted.first?.ordinal == nil
                ? String(localized: "a \(names)", bundle: .module, locale: locale,
                         comment: "Repeat summary: the weekdays in a condition, as in \"when it's a Monday or Friday\". The placeholder is the weekdays.")
                : names)
        }
        guard !options.isEmpty else { return phrase }
        let condition = and(options)
        return String(localized: "\(phrase) when it's \(condition)", bundle: .module, locale: locale,
                      comment: "Repeat summary: a limit on the days. 1: the repeat, such as \"Every day\". 2: the days it's limited to, such as \"a Monday or Friday\".")
    }

    /// "… in January and July", for a rule limited to some months.
    private func inMonths(_ months: Set<Int>?, _ phrase: String) -> String {
        guard let months else { return phrase }
        let names = and(months.sorted().map(monthName))
        return String(localized: "\(phrase) in \(names)", bundle: .module, locale: locale,
                      comment: "Repeat summary: a repeat limited to some months. 1: the repeat, such as \"Every day\". 2: the months, such as \"January and July\".")
    }

    /// What happens where a day is missing: a custom rule skips that month or year (RFC 5545),
    /// and a preset moves to the last day (ADR 0003). Months that have the day get no note.
    private func note(_ phrase: String, rule: RepeatRule, monthDays: Set<Int>?, months: Set<Int>?) -> String {
        // The fewest days any of the rule's months has: 28, unless it names only longer months.
        let shortest = months.map { $0.map(Self.fewestDays).min() ?? 28 } ?? 28
        let lacksDay = monthDays?.contains { abs($0) > shortest } == true
        // A month has four or five of each weekday, and a year 52 or 53.
        let ordinalsSomeLack = rule.frequency == .yearly && months == nil ? 53 : 5
        let lacksWeekday = rule.weekdays?.contains { abs($0.ordinal ?? 0) >= ordinalsSomeLack } == true
        guard lacksDay || lacksWeekday else { return phrase }
        let yearly = rule.frequency == .yearly
        switch (rule.missingDay, yearly) {
        case (.skip, false):
            return String(localized: "\(phrase) (skipped in months without one)", bundle: .module, locale: locale,
                          comment: "Repeat summary: a custom monthly repeat on a day some months lack. The placeholder is the repeat.")
        case (.skip, true):
            return String(localized: "\(phrase) (skipped in years without one)", bundle: .module, locale: locale,
                          comment: "Repeat summary: a custom yearly repeat on a day some years lack. The placeholder is the repeat.")
        case (.lastDayOfMonth, true) where months == [2]:
            return String(localized: "\(phrase) (28 February in years without one)", bundle: .module, locale: locale,
                          comment: "Repeat summary: a yearly preset on 29 February, which moves to the 28th in other years. The placeholder is the repeat.")
        case (.lastDayOfMonth, false):
            return String(localized: "\(phrase) (the last day in months without one)", bundle: .module, locale: locale,
                          comment: "Repeat summary: a monthly preset on a day some months lack, which moves to their last day. The placeholder is the repeat.")
        case (.lastDayOfMonth, true):
            return String(localized: "\(phrase) (the last day in years without one)", bundle: .module, locale: locale,
                          comment: "Repeat summary: a yearly preset on a day some years lack, which moves to the month's last day. The placeholder is the repeat.")
        }
    }

    /// "the first Monday", "the last Friday"; with no ordinal "every Monday", or within a
    /// condition "Monday".
    private func weekdayName(_ number: RepeatRule.WeekdayNumber, every: Bool) -> String {
        let name = name(number.weekday)
        guard let ordinal = number.ordinal else {
            return every
                ? String(localized: "every \(name)", bundle: .module, locale: locale,
                         comment: "Repeat summary: each of a weekday in a month or year, as in \"Every month on every Monday\".")
                : name
        }
        let word = ordinalWord(ordinal)
        return String(localized: "the \(word) \(name)", bundle: .module, locale: locale,
                      comment: "Repeat summary: one weekday of a month or year. 1: which one, such as \"first\", \"last\" or \"6th\". 2: the weekday.")
    }

    /// "the 15th", "the last day", "the second-to-last day".
    private func monthDayName(_ day: Int) -> String {
        if day > 0 {
            let number = ordinalNumber(day)
            return String(localized: "the \(number)", bundle: .module, locale: locale,
                          comment: "Repeat summary: a day of the month, as in \"Every month on the 15th\". The placeholder is the ordinal number, such as \"15th\".")
        }
        let word = ordinalWord(day)
        return String(localized: "the \(word) day", bundle: .module, locale: locale,
                      comment: "Repeat summary: a day counted from the end of the month. The placeholder is which one, such as \"last\" or \"second-to-last\".")
    }

    /// "first" to "fifth", then "6th"; "last", then "second-to-last" and on.
    private func ordinalWord(_ ordinal: Int) -> String {
        switch ordinal {
        case 1: String(localized: "first", bundle: .module, locale: locale, comment: "Repeat summary: the first of a weekday, as in \"the first Monday\".")
        case 2: String(localized: "second", bundle: .module, locale: locale, comment: "Repeat summary: the second of a weekday, as in \"the second Monday\".")
        case 3: String(localized: "third", bundle: .module, locale: locale, comment: "Repeat summary: the third of a weekday, as in \"the third Monday\".")
        case 4: String(localized: "fourth", bundle: .module, locale: locale, comment: "Repeat summary: the fourth of a weekday, as in \"the fourth Monday\".")
        case 5: String(localized: "fifth", bundle: .module, locale: locale, comment: "Repeat summary: the fifth of a weekday, as in \"the fifth Monday\".")
        case -1: String(localized: "last", bundle: .module, locale: locale, comment: "Repeat summary: the last of a weekday or day, as in \"the last Monday\" or \"the last day\".")
        case -2: String(localized: "second-to-last", bundle: .module, locale: locale, comment: "Repeat summary: counted from the end, as in \"the second-to-last day\".")
        case -3: String(localized: "third-to-last", bundle: .module, locale: locale, comment: "Repeat summary: counted from the end, as in \"the third-to-last day\".")
        case -4: String(localized: "fourth-to-last", bundle: .module, locale: locale, comment: "Repeat summary: counted from the end, as in \"the fourth-to-last day\".")
        case -5: String(localized: "fifth-to-last", bundle: .module, locale: locale, comment: "Repeat summary: counted from the end, as in \"the fifth-to-last day\".")
        case let ordinal where ordinal > 0: ordinalNumber(ordinal)
        default:
            String(localized: "\(ordinalNumber(-ordinal))-to-last", bundle: .module, locale: locale,
                   comment: "Repeat summary: counted from the end, as in \"the 6th-to-last day\". The placeholder is the ordinal number, such as \"6th\".")
        }
    }

    /// "1st", "2nd", "11th", "23rd" in English: Foundation's ordinal numbers for the locale.
    private func ordinalNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .ordinal
        return formatter.string(from: number as NSNumber) ?? number.formatted(.number.locale(locale))
    }

    /// "29 February" in en_GB, "February 29" in en_US: the locale's order for a day and month.
    private func dayOfMonth(_ day: Int, _ month: Int) -> String {
        // A leap year, so 29 February exists. Formatted in UTC, the zone the date is made in.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        guard let date = utc.date(from: DateComponents(year: 2000, month: month, day: day)) else { return "" }
        return date.formatted(Date.FormatStyle(locale: locale, calendar: utc, timeZone: .gmt).day().month(.wide))
    }

    private func name(_ weekday: RepeatRule.Weekday) -> String {
        localizedCalendar.weekdaySymbols[weekday.rawValue - 1]
    }

    private func monthName(_ month: Int) -> String {
        let names = localizedCalendar.monthSymbols
        return names.indices.contains(month - 1) ? names[month - 1] : ""
    }

    private var localizedCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return calendar
    }

    /// "Monday, Wednesday and Sunday" in en_GB, with the serial comma in en_US.
    private func and(_ items: [String]) -> String {
        items.formatted(.list(type: .and).locale(locale))
    }

    /// "Monday or Friday".
    private func or(_ items: [String]) -> String {
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
