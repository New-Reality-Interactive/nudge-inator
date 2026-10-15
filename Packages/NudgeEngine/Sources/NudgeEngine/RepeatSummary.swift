import Foundation

extension Engine {
    /// The repeat in plain words, with its time of day and how it ends, such as "Every 2 weeks on
    /// Monday and Wednesday at 9:00 AM, 5 times". The form, the Repeat and Custom pages and the
    /// details screen all show this one string. The sentence is English, as the app is; its times
    /// and dates follow the engine's locale and time zone. The reminder needn't be one the engine
    /// holds, so a draft can be summarised.
    public func repeatSummary(of reminder: Reminder) -> String {
        let first = calendar.dateComponents([.year, .month, .day, .weekday], from: reminder.dueTime)
        guard let rule = reminder.repeatRule else { return "Once, \(dayLabel(of: reminder.dueTime)) at \(time(of: reminder.dueTime))" }
        return "\(rule.phrase(first: first)) at \(time(of: reminder.dueTime))\(ending(of: rule))"
    }

    /// "Today", "Tomorrow", "Yesterday" or the short date, as the mockup's `dayLabel`.
    private func dayLabel(of date: Date) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: clock.now), to: calendar.startOfDay(for: date)).day
        return switch days {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
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

    private func ending(of rule: RepeatRule) -> String {
        switch rule.end {
        case nil: return ""
        case .count(1): return ", once"
        case .count(let count): return ", \(count) times"
        case let .untilDate(year, month, day):
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return "" }
            return ", until \(shortDate(of: date))"
        case .untilTime(let time):
            // An UNTIL at the last second of a local day is that whole day, which is how the
            // editor writes an end date; any other time is part of the ending.
            let endOfDay = calendar.dateComponents([.hour, .minute, .second], from: time) == DateComponents(hour: 23, minute: 59, second: 59)
            return ", until \(shortDate(of: time))" + (endOfDay ? "" : " at \(self.time(of: time))")
        }
    }
}

private extension RepeatRule {
    /// What the rule falls on, before its time: "Every 2 weeks on Monday and Wednesday". The
    /// parts the rule leaves out come from the first due time, as RFC 5545 and the walk take them.
    func phrase(first: DateComponents) -> String {
        let noDayParts = weekdays == nil && monthDays == nil
        switch frequency {
        case .daily:
            return every + condition(weekdays: weekdays, monthDays: monthDays) + inMonths
        case .weekly:
            let days = weekdays.map { $0.map(\.weekday) } ?? first.weekday.flatMap(Weekday.init).map { [$0] } ?? []
            let sorted = Set(days).sorted { $0.mondayFirstIndex < $1.mondayFirstIndex }
            if interval == 1 && months == nil && sorted == [.monday, .tuesday, .wednesday, .thursday, .friday] { return "Every weekday" }
            let names = Self.list(sorted.map(\.name))
            return (interval > 1 ? "\(every) on \(names)" : "Every \(names)") + inMonths
        case .monthly:
            let monthDays = noDayParts ? first.day.map { [$0] } : monthDays
            return "\(every) on \(days(weekdays: weekdays, monthDays: monthDays))" + inMonths + note(monthDays: monthDays, months: months)
        case .yearly:
            let monthDays = noDayParts ? first.day.map { [$0] } : monthDays
            let months = noDayParts ? self.months ?? first.month.map { [$0] } : self.months
            // "on 29 February", as the mockup words its one-day yearly rule.
            if weekdays == nil, let months, months.count == 1, let month = months.first,
               let monthDays, monthDays.count == 1, let day = monthDays.first, day > 0 {
                return "\(every) on \(day) \(Self.monthName(month))" + note(monthDays: monthDays, months: months)
            }
            let of = if let months { Self.list(months.sorted().map(Self.monthName)) } else if monthDays != nil { "every month" } else { "the year" }
            return "\(every) on \(days(weekdays: weekdays, monthDays: monthDays, of: of))" + note(monthDays: monthDays, months: months)
        }
    }

    /// "the 15th", "the first Monday", "the 13th when it's a Friday", "the last Monday of May".
    private func days(weekdays: Set<WeekdayNumber>?, monthDays: Set<Int>?, of period: String? = nil) -> String {
        let of = period.map { " of \($0)" } ?? ""
        if let monthDays {
            return Self.list(Self.sorted(monthDays).map(Self.monthDayName)) + of + condition(weekdays: weekdays, monthDays: nil)
        }
        return Self.list((weekdays ?? []).sorted().map { Self.weekdayName($0, every: true) }) + of
    }

    /// A limit on the days: " when it's a Monday or Friday", " when it's the 1st or the 15th".
    private func condition(weekdays: Set<WeekdayNumber>?, monthDays: Set<Int>?) -> String {
        var options: [String] = []
        if let monthDays { options.append(Self.sorted(monthDays).map(Self.monthDayName).joined(separator: " or ")) }
        if let weekdays {
            let names = weekdays.sorted().map { Self.weekdayName($0, every: false) }
            options.append(names.first.map { first in
                (first.hasPrefix("the") ? "" : "a ") + names.joined(separator: " or ")
            } ?? "")
        }
        return options.isEmpty ? "" : " when it's " + options.joined(separator: " and ")
    }

    /// " in January and July", for a rule limited to some months.
    private var inMonths: String {
        months.map { " in " + Self.list($0.sorted().map(Self.monthName)) } ?? ""
    }

    /// What happens where a day is missing: a custom rule skips that month or year (RFC 5545),
    /// and a preset moves to the last day (ADR 0003). Months that have the day get no note.
    private func note(monthDays: Set<Int>?, months: Set<Int>?) -> String {
        // The fewest days any of the rule's months has: 28, unless it names only longer months.
        let shortest = months.map { $0.map(Self.fewestDays).min() ?? 28 } ?? 28
        let lacksDay = monthDays?.contains { abs($0) > shortest } == true
        // A month has four or five of each weekday, and a year 52 or 53.
        let ordinalsSomeLack = frequency == .yearly && months == nil ? 53 : 5
        let lacksWeekday = weekdays?.contains { abs($0.ordinal ?? 0) >= ordinalsSomeLack } == true
        guard lacksDay || lacksWeekday else { return "" }
        let period = frequency == .yearly ? "years" : "months"
        switch missingDay {
        case .skip:
            return " (skipped in \(period) without one)"
        case .lastDayOfMonth:
            if frequency == .yearly, months == [2] { return " (28 February in years without one)" }
            return " (the last day in \(period) without one)"
        }
    }

    /// "Every day", or "Every 3 days" when the interval is more than 1.
    var every: String {
        let unit = switch frequency {
        case .daily: "day"
        case .weekly: "week"
        case .monthly: "month"
        case .yearly: "year"
        }
        return interval > 1 ? "Every \(interval) \(unit)s" : "Every \(unit)"
    }

    /// The days of the month, then the days counted back from its end.
    static func sorted(_ monthDays: Set<Int>) -> [Int] {
        monthDays.filter { $0 > 0 }.sorted() + monthDays.filter { $0 < 0 }.sorted(by: >)
    }

    /// "the first Monday", "the last Friday"; with no ordinal "every Monday", or within a
    /// condition "Monday".
    static func weekdayName(_ number: WeekdayNumber, every: Bool) -> String {
        guard let ordinal = number.ordinal else { return every ? "every \(number.weekday.name)" : number.weekday.name }
        return "the \(ordinalWord(ordinal)) \(number.weekday.name)"
    }

    /// "the 15th", "the last day", "the second-to-last day".
    static func monthDayName(_ day: Int) -> String {
        day > 0 ? "the \(ordinalNumber(day))" : "the \(ordinalWord(day)) day"
    }

    /// "first" to "fifth", then "6th"; "last", then "second-to-last" and on.
    static func ordinalWord(_ ordinal: Int) -> String {
        let words = [1: "first", 2: "second", 3: "third", 4: "fourth", 5: "fifth"]
        if ordinal == -1 { return "last" }
        let word = words[abs(ordinal)] ?? ordinalNumber(abs(ordinal))
        return ordinal > 0 ? word : "\(word)-to-last"
    }

    /// "1st", "2nd", "11th", "23rd", as the mockup's `ord`.
    static func ordinalNumber(_ number: Int) -> String {
        let suffix = (11...13).contains(number % 100) ? "th" : [1: "st", 2: "nd", 3: "rd"][number % 10] ?? "th"
        return "\(number)\(suffix)"
    }

    static func monthName(_ month: Int) -> String {
        let names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        return names.indices.contains(month - 1) ? names[month - 1] : ""
    }

    /// The fewest days a month has in any year: February has 28.
    static func fewestDays(_ month: Int) -> Int {
        switch month {
        case 2: 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    /// "Monday", "Monday and Friday", "Monday, Wednesday and Sunday".
    static func list(_ items: [String]) -> String {
        guard let last = items.last, items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + last
    }
}

private extension RepeatRule.Weekday {
    var name: String {
        switch self {
        case .sunday: "Sunday"
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        }
    }
}
