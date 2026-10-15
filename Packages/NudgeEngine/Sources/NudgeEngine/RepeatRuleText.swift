import Foundation

extension RepeatRule {
    /// Why RRULE text isn't a rule this engine can follow. Parts are named as RFC 5545 spells them.
    public enum ParseError: Error, Equatable, Sendable {
        /// A part that isn't `NAME=VALUE`.
        case malformed(String)
        case missingFrequency
        /// RFC 5545 allows each part once.
        case duplicatePart(String)
        /// Not an RRULE part at all.
        case unknownPart(String)
        /// `DTSTART`, `EXDATE` or `RDATE`: iCalendar properties of their own, not rule parts. The
        /// reminder's due time plays `DTSTART`.
        case notARulePart(String)
        /// An RRULE part outside the subset (ADR 0003): `BYSETPOS`, `BYWEEKNO`, `BYYEARDAY`,
        /// `BYHOUR`, `BYMINUTE` or `BYSECOND`.
        case unsupportedPart(String)
        /// `HOURLY`, `MINUTELY` or `SECONDLY`. Nudging is the sub-daily mechanism, and the
        /// give-up limit is 24 hours.
        case subDailyFrequency(String)
        case invalidValue(part: String, value: String)
        /// Weeks start on Monday, RRULE's default, so `WKST=MO` is the only one accepted.
        case unsupportedWeekStart(String)
        /// A local `UNTIL` date-time with no `Z`. Next to a `DTSTART` with a time zone, RFC 5545
        /// requires UTC.
        case floatingUntil(String)
        /// RFC 5545 allows one or the other.
        case countWithUntil
        /// RFC 5545 allows an ordinal in `BYDAY` (`1MO`) only in monthly and yearly rules.
        case ordinalNotAllowed(Frequency)
        /// RFC 5545 doesn't allow `BYMONTHDAY` in a weekly rule.
        case monthDayInWeeklyRule
    }

    /// Reads a custom repeat from RRULE text (RFC 5545, the subset in ADR 0003), such as
    /// `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE`. Names and codes are case-insensitive, as RFC 5545
    /// says. The rule skips a month without its day (`missingDay` is `.skip`): only presets clamp.
    public init(rrule text: String) throws(ParseError) {
        var parts: [String: String] = [:]
        for part in text.split(separator: ";", omittingEmptySubsequences: false) where !text.isEmpty {
            let pair = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2, !pair[0].isEmpty else { throw .malformed(String(part)) }
            let name = pair[0].uppercased()
            guard parts[name] == nil else { throw .duplicatePart(name) }
            parts[name] = String(pair[1])
        }
        for name in parts.keys where !Self.supportedParts.contains(name) {
            if Self.unsupportedParts.contains(name) { throw .unsupportedPart(name) }
            if Self.otherProperties.contains(name) { throw .notARulePart(name) }
            throw .unknownPart(name)
        }

        guard let frequencyText = parts["FREQ"] else { throw .missingFrequency }
        let code = frequencyText.uppercased()
        guard let frequency = Frequency.allCases.first(where: { $0.code == code }) else {
            if ["HOURLY", "MINUTELY", "SECONDLY"].contains(code) { throw .subDailyFrequency(code) }
            throw .invalidValue(part: "FREQ", value: frequencyText)
        }

        let interval = try parts["INTERVAL"].map { value throws(ParseError) in
            try Self.number(value, part: "INTERVAL", in: 1...Int.max)
        } ?? 1

        if let start = parts["WKST"] {
            guard let weekday = Self.weekday(code: start) else { throw .invalidValue(part: "WKST", value: start) }
            guard weekday == .monday else { throw .unsupportedWeekStart(start.uppercased()) }
        }

        let weekdays = try parts["BYDAY"].map { value throws(ParseError) in
            try Self.list(value, part: "BYDAY") { item throws(ParseError) in
                try Self.weekdayNumber(item, part: value)
            }
        }
        if weekdays?.contains(where: { $0.ordinal != nil }) == true, frequency == .daily || frequency == .weekly {
            throw .ordinalNotAllowed(frequency)
        }
        let monthDays = try parts["BYMONTHDAY"].map { value throws(ParseError) in
            try Self.list(value, part: "BYMONTHDAY") { item throws(ParseError) in
                let day = try Self.number(item, part: "BYMONTHDAY", whole: value, in: -31...31)
                guard day != 0 else { throw .invalidValue(part: "BYMONTHDAY", value: value) }
                return day
            }
        }
        if monthDays != nil, frequency == .weekly { throw .monthDayInWeeklyRule }
        let months = try parts["BYMONTH"].map { value throws(ParseError) in
            try Self.list(value, part: "BYMONTH") { item throws(ParseError) in
                try Self.number(item, part: "BYMONTH", whole: value, in: 1...12)
            }
        }

        if parts["COUNT"] != nil, parts["UNTIL"] != nil { throw .countWithUntil }
        var end: End?
        if let count = parts["COUNT"] { end = .count(try Self.number(count, part: "COUNT", in: 1...Int.max)) }
        if let until = parts["UNTIL"] { end = try Self.until(until) }

        self.init(frequency, checkedInterval: interval, weekdays: weekdays, monthDays: monthDays, months: months, end: end)
    }

    /// The rule as RRULE text, which `init(rrule:)` reads back as an equal rule. Parts come in the
    /// mockup's order, weekdays Monday first, numbers ascending, and `INTERVAL=1` is left out.
    /// `missingDay` is not part of RRULE, so a preset's text reads back as the skipping rule: the
    /// store keeps `missingDay` alongside the text.
    public var rrule: String {
        var parts = ["FREQ=" + frequency.code]
        if interval != 1 { parts.append("INTERVAL=\(interval)") }
        if let weekdays {
            let codes = weekdays.sorted().map { (number: WeekdayNumber) in (number.ordinal.map(String.init) ?? "") + number.weekday.code }
            parts.append("BYDAY=" + codes.joined(separator: ","))
        }
        if let months { parts.append("BYMONTH=" + months.sorted().map(String.init).joined(separator: ",")) }
        if let monthDays { parts.append("BYMONTHDAY=" + monthDays.sorted().map(String.init).joined(separator: ",")) }
        switch end {
        case .count(let count): parts.append("COUNT=\(count)")
        case let .untilDate(year, month, day): parts.append("UNTIL=" + Self.digits(year, 4) + Self.digits(month, 2) + Self.digits(day, 2))
        case .untilTime(let time):
            let utc = Self.utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: time)
            parts.append("UNTIL=" + Self.digits(utc.year, 4) + Self.digits(utc.month, 2) + Self.digits(utc.day, 2)
                + "T" + Self.digits(utc.hour, 2) + Self.digits(utc.minute, 2) + Self.digits(utc.second, 2) + "Z")
        case nil: break
        }
        return parts.joined(separator: ";")
    }

    /// `number` zero-padded to `width` digits.
    private static func digits(_ number: Int?, _ width: Int) -> String {
        let text = String(number ?? 0)
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }

    private static let supportedParts: Set = ["FREQ", "INTERVAL", "BYDAY", "BYMONTHDAY", "BYMONTH", "COUNT", "UNTIL", "WKST"]
    private static let unsupportedParts: Set = ["BYSETPOS", "BYWEEKNO", "BYYEARDAY", "BYHOUR", "BYMINUTE", "BYSECOND"]
    private static let otherProperties: Set = ["DTSTART", "EXDATE", "RDATE"]

    private static func weekday(code: some StringProtocol) -> Weekday? {
        Weekday.allCases.first { $0.code == code.uppercased() }
    }

    /// A whole number in `range`, with an optional sign as RFC 5545 allows. `whole` is the part's
    /// full value, which the error reports when this is one item of a list.
    private static func number(_ text: some StringProtocol, part: String, whole: String? = nil, in range: ClosedRange<Int>) throws(ParseError) -> Int {
        guard let number = Int(text), range.contains(number) else { throw .invalidValue(part: part, value: whole ?? String(text)) }
        return number
    }

    /// A comma-separated list with no empty items.
    private static func list<Element: Hashable>(
        _ value: String,
        part: String,
        _ item: (Substring) throws(ParseError) -> Element
    ) throws(ParseError) -> Set<Element> {
        var elements: Set<Element> = []
        for text in value.split(separator: ",", omittingEmptySubsequences: false) {
            guard !text.isEmpty else { throw .invalidValue(part: part, value: value) }
            elements.insert(try item(text))
        }
        return elements
    }

    /// `MO`, `1MO`, `+1MO` or `-1MO`. RFC 5545's ordinal is 1 to 53 either way.
    private static func weekdayNumber(_ text: Substring, part value: String) throws(ParseError) -> WeekdayNumber {
        guard let weekday = weekday(code: text.suffix(2)) else { throw .invalidValue(part: "BYDAY", value: value) }
        let ordinal = text.dropLast(2)
        if ordinal.isEmpty { return WeekdayNumber(weekday) }
        let number = try number(ordinal, part: "BYDAY", whole: value, in: -53...53)
        guard number != 0 else { throw .invalidValue(part: "BYDAY", value: value) }
        return WeekdayNumber(weekday, ordinal: number)
    }

    /// `YYYYMMDD`, or `YYYYMMDDTHHMMSSZ` in UTC.
    private static func until(_ text: String) throws(ParseError) -> End {
        let value = text.uppercased()
        let invalid = ParseError.invalidValue(part: "UNTIL", value: text)
        func digits(_ range: Range<Int>) throws(ParseError) -> Int {
            let start = value.index(value.startIndex, offsetBy: range.lowerBound)
            let end = value.index(value.startIndex, offsetBy: range.upperBound)
            let field = value[start..<end]
            guard field.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(field) else { throw invalid }
            return number
        }
        switch value.count {
        case 8:
            let (year, month, day) = (try digits(0..<4), try digits(4..<6), try digits(6..<8))
            // Round-trip through the calendar, which rolls 30 February over to March.
            let components = DateComponents(year: year, month: month, day: day)
            guard let date = utcCalendar.date(from: components),
                  utcCalendar.dateComponents([.year, .month, .day], from: date) == components
            else { throw invalid }
            return .untilDate(year: year, month: month, day: day)
        case 15 where value.dropFirst(8).first == "T":
            throw .floatingUntil(text)
        case 16 where value.dropFirst(8).first == "T" && value.last == "Z":
            let components = DateComponents(
                year: try digits(0..<4), month: try digits(4..<6), day: try digits(6..<8),
                hour: try digits(9..<11), minute: try digits(11..<13), second: try digits(13..<15)
            )
            guard let time = utcCalendar.date(from: components),
                  utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: time) == components
            else { throw invalid }
            return .untilTime(time)
        default:
            throw invalid
        }
    }

    /// RRULE's dates are Gregorian, and a date-time UNTIL is in UTC.
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
}
