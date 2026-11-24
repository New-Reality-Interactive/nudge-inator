import Foundation

extension Engine {
    /// The repeat in plain words, with its time of day and how it ends, such as "Every 2 weeks on
    /// Monday and Wednesday at 9:00 AM, 5 times". The form, the Repeat and Custom pages and the
    /// details screen all show this one sentence. Its words come from the engine's String Catalog
    /// as SwiftUI draws it; its names, lists, times and dates follow the engine's locale and time
    /// zone. The reminder needn't be one the engine holds, so a draft can be summarised.
    public func repeatSummary(of reminder: Reminder) -> LocalizedStringResource {
        summaryWriter.summary(of: reminder)
    }

    /// "Today", "Tomorrow", "Yesterday" or a short date such as "Tue, Oct 20", in the engine's
    /// locale and time zone, as a one-off's summary says it: the Now rows' day.
    public func dayLabel(of date: Date) -> LocalizedStringResource {
        summaryWriter.dayLabel(of: date)
    }

    /// A short date such as "Sat, Oct 17", in the engine's locale and time zone: Now's subhead.
    public func shortDate(of date: Date) -> LocalizedStringResource {
        summaryWriter.shortDate(of: date)
    }

    /// My Day's day label (#375): "Tuesday, September 29", with the year when it isn't this year's.
    public func longDate(of day: CalendarDay) -> LocalizedStringResource {
        summaryWriter.named(startOfDay(day), weekday: .wide, month: .wide, withYear: day.year != today.year)
    }

    /// A day in My Day's sentences (#375): "Tue, Sep 29", with the year when it isn't this year's.
    public func shortDate(of day: CalendarDay) -> LocalizedStringResource {
        summaryWriter.named(startOfDay(day), weekday: .abbreviated, month: .abbreviated, withYear: day.year != today.year)
    }

    /// The time of day, such as "9:00 AM", in the engine's locale and time zone.
    public func timeOfDay(of date: Date) -> LocalizedStringResource {
        summaryWriter.time(of: date)
    }

    private var summaryWriter: RepeatSummaryWriter {
        RepeatSummaryWriter(locale: locale, calendar: calendar, now: clock.now)
    }
}

/// Writes a repeat summary. Each piece of wording is one catalog string whose comment says what
/// its placeholders hold, so a translation can reorder them; words that agree with each other
/// (an ordinal and its weekday, "a" and its weekdays) are in the same string. A summary nests
/// these templates, as RFC 5545 rules combine. Each is a `LocalizedStringResource` holding the ones
/// inside it, so the whole sentence is looked up as it is drawn. Ordinal numbers and standalone
/// weekday and month names are Strings in the engine's locale: Foundation has no format style for
/// ordinals, and a date format's weekday and month are the in-sentence forms, which some languages
/// inflect differently from a name standing alone.
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

    func summary(of reminder: Reminder) -> LocalizedStringResource {
        let time = time(of: reminder.dueTime)
        guard let rule = reminder.repeatRule else {
            let day = dayLabel(of: reminder.dueTime)
            return LocalizedStringResource("Once, \(day) at \(time)", locale: locale, bundle: .module,
                                           comment: "Repeat summary of a reminder that doesn't repeat. 1: Today, Tomorrow, Yesterday or a short date. 2: its time.")
        }
        let first = calendar.dateComponents([.year, .month, .day, .weekday], from: reminder.dueTime)
        let phrase = phrase(of: rule, first: first)
        switch rule.end {
        case nil:
            return atTime(phrase, time)
        case .count(let count):
            let times = LocalizedStringResource("\(count) times", locale: locale, bundle: .module,
                                                comment: "Repeat summary: how many times a repeat happens before it ends. Singular: \"once\".")
            return LocalizedStringResource("\(phrase) at \(time), \(times)", locale: locale, bundle: .module,
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

    private func atTime(_ phrase: LocalizedStringResource, _ time: LocalizedStringResource) -> LocalizedStringResource {
        LocalizedStringResource("\(phrase) at \(time)", locale: locale, bundle: .module,
                                comment: "Repeat summary. 1: what the rule falls on, such as \"Every 2 weeks on Monday\". 2: the time.")
    }

    private func until(_ phrase: LocalizedStringResource, _ time: LocalizedStringResource, date: Date, endTime: LocalizedStringResource?) -> LocalizedStringResource {
        let date = shortDate(of: date)
        guard let endTime else {
            return LocalizedStringResource("\(phrase) at \(time), until \(date)", locale: locale, bundle: .module,
                                           comment: "Repeat summary of a repeat with an end date. 1: what the rule falls on. 2: the time. 3: the last date, short.")
        }
        return LocalizedStringResource("\(phrase) at \(time), until \(date) at \(endTime)", locale: locale, bundle: .module,
                                       comment: "Repeat summary of a repeat that ends at a time. 1: what the rule falls on. 2: the time. 3: the last date, short. 4: the time it ends.")
    }

    /// "Today", "Tomorrow", "Yesterday" or the short date, as the mockup's `dayLabel`.
    func dayLabel(of date: Date) -> LocalizedStringResource {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day
        return switch days {
        case 0: LocalizedStringResource("Today", locale: locale, bundle: .module, comment: "Repeat summary: a one-off reminder's day, as in \"Once, Today at 9:00\".")
        case 1: LocalizedStringResource("Tomorrow", locale: locale, bundle: .module, comment: "Repeat summary: a one-off reminder's day, as in \"Once, Tomorrow at 9:00\".")
        case -1: LocalizedStringResource("Yesterday", locale: locale, bundle: .module, comment: "Repeat summary: a one-off reminder's day, as in \"Once, Yesterday at 9:00\".")
        default: shortDate(of: date)
        }
    }

    func time(of date: Date) -> LocalizedStringResource {
        alone(date, format: Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone))
    }

    /// "Sat 10 Oct" in en_GB, "Sat, Oct 10" in en_US.
    func shortDate(of date: Date) -> LocalizedStringResource {
        named(date, weekday: .abbreviated, month: .abbreviated, withYear: false)
    }

    /// A date with its weekday, day and month, and its year if asked.
    func named(_ date: Date, weekday: Date.FormatStyle.Symbol.Weekday, month: Date.FormatStyle.Symbol.Month, withYear: Bool) -> LocalizedStringResource {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(weekday).day().month(month)
        return alone(date, format: withYear ? style.year() : style)
    }

    /// A date or a time standing alone, to go into a sentence's placeholder. Every resource that is
    /// only a placeholder shares one catalog entry, so each `alone` spells the same comment.
    func alone(_ date: Date, format: Date.FormatStyle) -> LocalizedStringResource {
        LocalizedStringResource("\(date, format: format)", locale: locale, bundle: .module,
                                comment: "Words standing alone, already in the language's own format: a date, a time, a list, or a weekday or month name. A sentence holds it as a placeholder. Keep it as it is.")
    }

    /// A list standing alone, to go into a sentence's placeholder: "Monday and Friday".
    func alone(_ items: [LocalizedStringResource], type: ListFormatStyle<StringStyle, [String]>.ListType, width: ListFormatStyle<StringStyle, [String]>.Width = .standard) -> LocalizedStringResource {
        LocalizedStringResource("\(items, format: .list(type: type, width: width))", locale: locale, bundle: .module,
                                comment: "Words standing alone, already in the language's own format: a date, a time, a list, or a weekday or month name. A sentence holds it as a placeholder. Keep it as it is.")
    }

    /// What the rule falls on, before its time: "Every 2 weeks on Monday and Wednesday". The
    /// parts the rule leaves out come from the first due time, as RFC 5545 and the walk take them.
    private func phrase(of rule: RepeatRule, first: DateComponents) -> LocalizedStringResource {
        let every = every(rule)
        let noDayParts = rule.weekdays == nil && rule.monthDays == nil
        switch rule.frequency {
        case .daily:
            return limited(limited(every, toWeekdays: rule.weekdays, monthDays: rule.monthDays), toMonths: rule.months)
        case .weekly:
            let days = rule.weekdays.map { $0.map(\.weekday) } ?? first.weekday.flatMap(RepeatRule.Weekday.init).map { [$0] } ?? []
            let sorted = Set(days).sorted { $0.mondayFirstIndex < $1.mondayFirstIndex }
            if rule.interval == 1 && rule.months == nil && sorted == [.monday, .tuesday, .wednesday, .thursday, .friday] {
                return LocalizedStringResource("Every weekday", locale: locale, bundle: .module, comment: "Repeat summary: a repeat on Monday to Friday.")
            }
            let names = andList(sorted.map(nameAlone))
            let phrase = rule.interval > 1
                ? on(every, names)
                : LocalizedStringResource("Every \(names)", locale: locale, bundle: .module,
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
    private func every(_ rule: RepeatRule) -> LocalizedStringResource {
        let interval = rule.interval
        return switch rule.frequency {
        case .daily: LocalizedStringResource("Every \(interval) days", locale: locale, bundle: .module, comment: "Repeat summary: how often a reminder repeats. Singular: \"Every day\".")
        case .weekly: LocalizedStringResource("Every \(interval) weeks", locale: locale, bundle: .module, comment: "Repeat summary: how often a reminder repeats. Singular: \"Every week\".")
        case .monthly: LocalizedStringResource("Every \(interval) months", locale: locale, bundle: .module, comment: "Repeat summary: how often a reminder repeats. Singular: \"Every month\".")
        case .yearly: LocalizedStringResource("Every \(interval) years", locale: locale, bundle: .module, comment: "Repeat summary: how often a reminder repeats. Singular: \"Every year\".")
        }
    }

    private func on(_ every: LocalizedStringResource, _ days: LocalizedStringResource) -> LocalizedStringResource {
        LocalizedStringResource("\(every) on \(days)", locale: locale, bundle: .module,
                                comment: "Repeat summary. 1: how often, such as \"Every 2 weeks\". 2: the days it falls on, such as \"Monday and Wednesday\" or \"the 15th\".")
    }

    /// Where a yearly rule's days are counted: in some months, in every month, or in the year.
    private enum Period {
        case months(Set<Int>)
        case everyMonth
        case year
    }

    /// "the 15th", "the first Monday", "the 13th when it's a Friday", "the last Monday of May".
    private func days(weekdays: Set<RepeatRule.WeekdayNumber>?, monthDays: Set<Int>?, in period: Period? = nil) -> LocalizedStringResource {
        let days = if let monthDays {
            andList(Self.sorted(monthDays).map(monthDayName))
        } else {
            andList((weekdays ?? []).sorted().map { weekdayName($0, every: true) })
        }
        let inPeriod = switch period {
        case nil: days
        case .months(let months):
            LocalizedStringResource("\(days) of \(andList(months.sorted().map(monthNameAlone)))", locale: locale, bundle: .module,
                                    comment: "Repeat summary: a yearly repeat's days in some months. 1: the days, such as \"the last Monday\". 2: the months, such as \"May\".")
        case .everyMonth:
            LocalizedStringResource("\(days) of every month", locale: locale, bundle: .module,
                                    comment: "Repeat summary: a yearly repeat's days in each month. The placeholder is the days, such as \"the 1st\".")
        case .year:
            LocalizedStringResource("\(days) of the year", locale: locale, bundle: .module,
                                    comment: "Repeat summary: a yearly repeat's weekdays counted in the year. The placeholder is the days, such as \"the first Monday\".")
        }
        return monthDays == nil ? inPeriod : limited(inPeriod, toWeekdays: weekdays, monthDays: nil)
    }

    /// A limit on the days: "… when it's a Monday or Friday", "… when it's the 1st or the 15th",
    /// "… when it's the 13th and a Friday".
    private func limited(_ phrase: LocalizedStringResource, toWeekdays weekdays: Set<RepeatRule.WeekdayNumber>?, monthDays: Set<Int>?) -> LocalizedStringResource {
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
                : LocalizedStringResource("\(phrase) when it's a \(names)", locale: locale, bundle: .module,
                                          comment: "Repeat summary: a repeat limited to some weekdays. 1: the repeat, such as \"Every day\". 2: the weekdays, such as \"Monday or Friday\".")
        case let (days?, names?):
            return counted
                ? LocalizedStringResource("\(phrase) when it's \(days) and \(names)", locale: locale, bundle: .module,
                                          comment: "Repeat summary: a repeat limited to days that are also certain weekdays. 1: the repeat. 2: the days, such as \"the 13th\". 3: the weekdays, such as \"the first Monday\".")
                : LocalizedStringResource("\(phrase) when it's \(days) and a \(names)", locale: locale, bundle: .module,
                                          comment: "Repeat summary: a repeat limited to days that are also certain weekdays. 1: the repeat. 2: the days, such as \"the 13th\". 3: the weekdays, such as \"Friday\".")
        }
    }

    private func limited(_ phrase: LocalizedStringResource, to days: LocalizedStringResource) -> LocalizedStringResource {
        LocalizedStringResource("\(phrase) when it's \(days)", locale: locale, bundle: .module,
                                comment: "Repeat summary: a repeat limited to some days. 1: the repeat, such as \"Every day\". 2: the days, such as \"the 1st or the 15th\" or \"the first Monday\".")
    }

    /// "… in January and July", for a rule limited to some months.
    private func limited(_ phrase: LocalizedStringResource, toMonths months: Set<Int>?) -> LocalizedStringResource {
        guard let months else { return phrase }
        let names = andList(months.sorted().map(monthNameAlone))
        return LocalizedStringResource("\(phrase) in \(names)", locale: locale, bundle: .module,
                                       comment: "Repeat summary: a repeat limited to some months. 1: the repeat, such as \"Every day\". 2: the months, such as \"January and July\".")
    }

    /// What happens where a day is missing: a custom rule skips that month or year (RFC 5545),
    /// and a preset moves to the last day (ADR 0003). Months that have the day get no note.
    /// `monthDays` and `months` are the ones the rule falls on, filled from its first due time
    /// where the rule leaves them out.
    private func note(_ phrase: LocalizedStringResource, for rule: RepeatRule, monthDays: Set<Int>?, months: Set<Int>?) -> LocalizedStringResource {
        // The fewest days any of the rule's months has: 28, unless it names only longer months.
        let shortest = months.map { $0.map(Self.fewestDays).min() ?? 28 } ?? 28
        let lacksDay = monthDays?.contains { abs($0) > shortest } == true
        // A month has four or five of each weekday, and a year 52 or 53.
        let ordinalsSomeLack = rule.frequency == .yearly && months == nil ? 53 : 5
        let lacksWeekday = rule.weekdays?.contains { abs($0.ordinal ?? 0) >= ordinalsSomeLack } == true
        guard lacksDay || lacksWeekday else { return phrase }
        switch (rule.missingDay, rule.frequency == .yearly) {
        case (.skip, false):
            return LocalizedStringResource("\(phrase) (skipped in months without one)", locale: locale, bundle: .module,
                                           comment: "Repeat summary: a custom monthly repeat on a day some months lack. The placeholder is the repeat.")
        case (.skip, true):
            return LocalizedStringResource("\(phrase) (skipped in years without one)", locale: locale, bundle: .module,
                                           comment: "Repeat summary: a custom yearly repeat on a day some years lack. The placeholder is the repeat.")
        case (.lastDayOfMonth, true) where months == [2]:
            guard let lastDay = dayAndMonth(28, 2) else { return phrase }
            return LocalizedStringResource("\(phrase) (\(lastDay) in years without one)", locale: locale, bundle: .module,
                                           comment: "Repeat summary: a yearly preset on 29 February, which moves to the 28th in other years. 1: the repeat. 2: the day it moves to, such as \"28 February\".")
        case (.lastDayOfMonth, false):
            return LocalizedStringResource("\(phrase) (the last day in months without one)", locale: locale, bundle: .module,
                                           comment: "Repeat summary: a monthly preset on a day some months lack, which moves to their last day. The placeholder is the repeat.")
        case (.lastDayOfMonth, true):
            return LocalizedStringResource("\(phrase) (the last day in years without one)", locale: locale, bundle: .module,
                                           comment: "Repeat summary: a yearly preset on a day some years lack, which moves to the month's last day. The placeholder is the repeat.")
        }
    }

    /// "the first Monday", "the last Friday", "the 6th Monday"; with no ordinal "every Monday",
    /// or within a condition "Monday".
    private func weekdayName(_ number: RepeatRule.WeekdayNumber, every: Bool) -> LocalizedStringResource {
        let name = name(number.weekday)
        switch number.ordinal {
        case nil:
            return every
                ? LocalizedStringResource("every \(name)", locale: locale, bundle: .module,
                                          comment: "Repeat summary: each of a weekday in a month or year, as in \"Every month on every Monday\".")
                : nameAlone(number.weekday)
        case 1: return LocalizedStringResource("the first \(name)", locale: locale, bundle: .module, comment: "Repeat summary: the first of a weekday in a month or year. The placeholder is the weekday.")
        case 2: return LocalizedStringResource("the second \(name)", locale: locale, bundle: .module, comment: "Repeat summary: the second of a weekday in a month or year. The placeholder is the weekday.")
        case 3: return LocalizedStringResource("the third \(name)", locale: locale, bundle: .module, comment: "Repeat summary: the third of a weekday in a month or year. The placeholder is the weekday.")
        case 4: return LocalizedStringResource("the fourth \(name)", locale: locale, bundle: .module, comment: "Repeat summary: the fourth of a weekday in a month or year. The placeholder is the weekday.")
        case 5: return LocalizedStringResource("the fifth \(name)", locale: locale, bundle: .module, comment: "Repeat summary: the fifth of a weekday in a month or year. The placeholder is the weekday.")
        case -1: return LocalizedStringResource("the last \(name)", locale: locale, bundle: .module, comment: "Repeat summary: the last of a weekday in a month or year. The placeholder is the weekday.")
        case -2: return LocalizedStringResource("the second-to-last \(name)", locale: locale, bundle: .module, comment: "Repeat summary: a weekday counted from the end of a month or year. The placeholder is the weekday.")
        case -3: return LocalizedStringResource("the third-to-last \(name)", locale: locale, bundle: .module, comment: "Repeat summary: a weekday counted from the end of a month or year. The placeholder is the weekday.")
        case -4: return LocalizedStringResource("the fourth-to-last \(name)", locale: locale, bundle: .module, comment: "Repeat summary: a weekday counted from the end of a month or year. The placeholder is the weekday.")
        case -5: return LocalizedStringResource("the fifth-to-last \(name)", locale: locale, bundle: .module, comment: "Repeat summary: a weekday counted from the end of a month or year. The placeholder is the weekday.")
        case let ordinal? where ordinal > 0:
            return LocalizedStringResource("the \(ordinalNumber(ordinal)) \(name)", locale: locale, bundle: .module,
                                           comment: "Repeat summary: one weekday of a year, counted from its start. 1: the ordinal number, such as \"6th\". 2: the weekday.")
        case let ordinal?:
            return LocalizedStringResource("the \(ordinalNumber(-ordinal))-to-last \(name)", locale: locale, bundle: .module,
                                           comment: "Repeat summary: one weekday counted from the end of a month or year. 1: the ordinal number, such as \"6th\". 2: the weekday.")
        }
    }

    /// "the 15th", "the last day", "the second-to-last day".
    private func monthDayName(_ day: Int) -> LocalizedStringResource {
        switch day {
        case -1: LocalizedStringResource("the last day", locale: locale, bundle: .module, comment: "Repeat summary: the last day of the month.")
        case -2: LocalizedStringResource("the second-to-last day", locale: locale, bundle: .module, comment: "Repeat summary: a day counted from the end of the month.")
        case -3: LocalizedStringResource("the third-to-last day", locale: locale, bundle: .module, comment: "Repeat summary: a day counted from the end of the month.")
        case -4: LocalizedStringResource("the fourth-to-last day", locale: locale, bundle: .module, comment: "Repeat summary: a day counted from the end of the month.")
        case -5: LocalizedStringResource("the fifth-to-last day", locale: locale, bundle: .module, comment: "Repeat summary: a day counted from the end of the month.")
        case let day where day > 0:
            LocalizedStringResource("the \(ordinalNumber(day))", locale: locale, bundle: .module,
                                    comment: "Repeat summary: a day of the month, as in \"Every month on the 15th\". The placeholder is the ordinal number, such as \"15th\".")
        default:
            LocalizedStringResource("the \(ordinalNumber(-day))-to-last day", locale: locale, bundle: .module,
                                    comment: "Repeat summary: a day counted from the end of the month. The placeholder is the ordinal number, such as \"6th\".")
        }
    }

    /// "1st", "2nd", "11th", "23rd" in English: Foundation's ordinal numbers for the locale.
    func ordinalNumber(_ number: Int) -> String {
        ordinals.string(from: number as NSNumber) ?? number.formatted(.number.locale(locale))
    }

    /// "29 February" in en_GB, "February 29" in en_US: the locale's order for a day and month.
    /// `nil` for a day the month never has, such as 30 February.
    private func dayAndMonth(_ day: Int, _ month: Int) -> LocalizedStringResource? {
        // A leap year, so 29 February exists, in UTC, the zone it's formatted in. The calendar
        // would roll an impossible day into the next month, so the date must read back the same.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        guard let date = utc.date(from: DateComponents(year: 2000, month: month, day: day)),
              utc.dateComponents([.month, .day], from: date) == DateComponents(month: month, day: day) else { return nil }
        return alone(date, format: Date.FormatStyle(locale: locale, calendar: utc, timeZone: .gmt).day().month(.wide))
    }

    func name(_ weekday: RepeatRule.Weekday) -> String {
        weekdayNames[weekday.rawValue - 1]
    }

    /// A weekday's standalone name as a sentence's placeholder, within a condition: "… when it's a
    /// Monday or Friday".
    private func nameAlone(_ weekday: RepeatRule.Weekday) -> LocalizedStringResource {
        alone(name(weekday))
    }

    private func monthNameAlone(_ month: Int) -> LocalizedStringResource {
        alone(monthName(month))
    }

    /// A name already in the engine's locale, as a sentence's placeholder.
    private func alone(_ words: String) -> LocalizedStringResource {
        LocalizedStringResource("\(words)", locale: locale, bundle: .module,
                                comment: "Words standing alone, already in the language's own format: a date, a time, a list, or a weekday or month name. A sentence holds it as a placeholder. Keep it as it is.")
    }

    private func monthName(_ month: Int) -> String {
        monthNames.indices.contains(month - 1) ? monthNames[month - 1] : ""
    }

    /// "Monday, Wednesday and Sunday" in en_GB, with the serial comma in en_US.
    private func andList(_ items: [LocalizedStringResource]) -> LocalizedStringResource {
        alone(items, type: .and)
    }

    /// "Monday or Friday".
    private func orList(_ items: [LocalizedStringResource]) -> LocalizedStringResource {
        alone(items, type: .or)
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
