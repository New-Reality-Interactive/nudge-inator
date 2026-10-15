import Foundation
import Testing
@testable import NudgeEngine

/// Custom repeats as RRULE text (RFC 5545, the subset in ADR 0003): what parses, what it parses
/// to, and what is rejected and why.
struct RepeatRuleParsingTests {
    @Test func aDailyRuleWithAnIntervalParses() throws {
        #expect(try RepeatRule(rrule: "FREQ=DAILY;INTERVAL=3") == RepeatRule(frequency: .daily, interval: 3))
    }

    @Test func weekdaysParseWithAndWithoutAnOrdinal() throws {
        #expect(try RepeatRule(rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE")
            == RepeatRule(frequency: .weekly, interval: 2, weekdays: [.init(.monday), .init(.wednesday)]))
        #expect(try RepeatRule(rrule: "FREQ=MONTHLY;BYDAY=1MO,-1FR,+2TU")
            == RepeatRule(frequency: .monthly, weekdays: [.init(.monday, ordinal: 1), .init(.friday, ordinal: -1), .init(.tuesday, ordinal: 2)]))
    }

    @Test func monthsAndDaysOfTheMonthParseAsLists() throws {
        #expect(try RepeatRule(rrule: "FREQ=YEARLY;BYMONTH=1,7;BYMONTHDAY=1,-1")
            == RepeatRule(frequency: .yearly, monthDays: [1, -1], months: [1, 7]))
    }

    /// UNTIL can be a date, the whole day in the engine's time zone, or a UTC date-time, the form
    /// RFC 5545 requires next to a DTSTART with a time zone. 03:59:59 UTC on 11 October 2026 is
    /// 23:59:59 on the 10th in New York.
    @Test(arguments: [
        ("FREQ=DAILY;COUNT=3", RepeatRule.End.count(3)),
        ("FREQ=DAILY;UNTIL=20261010", .untilDate(year: 2026, month: 10, day: 10)),
        ("FREQ=DAILY;UNTIL=20261011T035959Z", .untilTime(Date(timeIntervalSince1970: 1_791_691_199))),
    ])
    func countAndUntilParseAsTheRulesEnd(text: String, end: RepeatRule.End) throws {
        #expect(try RepeatRule(rrule: text) == RepeatRule(frequency: .daily, end: end))
    }

    /// Valid rules read back from their own text as an equal rule, and the text is canonical:
    /// these are written in the order the engine writes them (the mockup's `customRule` order).
    @Test(arguments: [
        "FREQ=DAILY;INTERVAL=3",
        "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=5",
        "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR",
        "FREQ=MONTHLY;BYDAY=1MO",
        "FREQ=MONTHLY;BYDAY=-1FR",
        "FREQ=MONTHLY;BYMONTHDAY=-1",
        "FREQ=MONTHLY;BYDAY=FR;BYMONTHDAY=13",
        "FREQ=MONTHLY;BYMONTHDAY=31",
        "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29",
        "FREQ=YEARLY;BYDAY=-1MO;BYMONTH=5",
        "FREQ=YEARLY;BYMONTH=1,7;BYMONTHDAY=-1,1",
        "FREQ=DAILY;INTERVAL=3;UNTIL=20261010",
        "FREQ=DAILY;UNTIL=20261011T035959Z",
    ])
    func aValidRuleReadsBackFromItsOwnText(text: String) throws {
        let rule = try RepeatRule(rrule: text)
        #expect(rule.rrule == text)
        #expect(try RepeatRule(rrule: rule.rrule) == rule)
    }

    /// RFC 5545 names and codes are case-insensitive, and `WKST=MO` is the default spelled out.
    @Test func lowercaseTextAndAMondayWeekStartAreAccepted() throws {
        #expect(try RepeatRule(rrule: "freq=weekly;byday=mo,we;wkst=mo;until=20261011t035959z")
            == RepeatRule(rrule: "FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261011T035959Z"))
    }

    /// Every rule outside the subset, malformed or contradictory, with the reason it gives.
    static let rejected: [(String, RepeatRule.ParseError)] = [
        // Nudging is the sub-daily mechanism, and the give-up limit is 24 hours.
        ("FREQ=HOURLY", .subDailyFrequency("HOURLY")),
        ("FREQ=MINUTELY", .subDailyFrequency("MINUTELY")),
        ("FREQ=SECONDLY", .subDailyFrequency("SECONDLY")),
        ("FREQ=FORTNIGHTLY", .invalidValue(part: "FREQ", value: "FORTNIGHTLY")),
        ("INTERVAL=2", .missingFrequency),
        // Parts of RRULE outside the subset.
        ("FREQ=MONTHLY;BYDAY=MO;BYSETPOS=-1", .unsupportedPart("BYSETPOS")),
        ("FREQ=YEARLY;BYWEEKNO=20", .unsupportedPart("BYWEEKNO")),
        ("FREQ=YEARLY;BYYEARDAY=100", .unsupportedPart("BYYEARDAY")),
        ("FREQ=DAILY;BYHOUR=9,17", .unsupportedPart("BYHOUR")),
        ("FREQ=DAILY;BYMINUTE=30", .unsupportedPart("BYMINUTE")),
        ("FREQ=DAILY;BYSECOND=0", .unsupportedPart("BYSECOND")),
        ("FREQ=WEEKLY;WKST=SU", .unsupportedWeekStart("SU")),
        // Separate iCalendar properties, not rule parts. The due time plays DTSTART.
        ("FREQ=DAILY;EXDATE=20261010", .notARulePart("EXDATE")),
        ("FREQ=DAILY;RDATE=20261010", .notARulePart("RDATE")),
        ("FREQ=DAILY;DTSTART=20261010T090000", .notARulePart("DTSTART")),
        // The mockup's own several-times-a-day field, which the engine doesn't take.
        ("FREQ=DAILY;BYTIME=09:00", .unknownPart("BYTIME")),
        // Malformed.
        ("FREQ=DAILY;;COUNT=3", .malformed("")),
        ("FREQ=DAILY;COUNT", .malformed("COUNT")),
        ("FREQ=DAILY;FREQ=WEEKLY", .duplicatePart("FREQ")),
        ("FREQ=DAILY;INTERVAL=0", .invalidValue(part: "INTERVAL", value: "0")),
        ("FREQ=DAILY;INTERVAL=two", .invalidValue(part: "INTERVAL", value: "two")),
        ("FREQ=DAILY;COUNT=0", .invalidValue(part: "COUNT", value: "0")),
        ("FREQ=YEARLY;BYMONTH=13", .invalidValue(part: "BYMONTH", value: "13")),
        ("FREQ=YEARLY;BYMONTH=1,,2", .invalidValue(part: "BYMONTH", value: "1,,2")),
        ("FREQ=MONTHLY;BYMONTHDAY=0", .invalidValue(part: "BYMONTHDAY", value: "0")),
        ("FREQ=MONTHLY;BYMONTHDAY=32", .invalidValue(part: "BYMONTHDAY", value: "32")),
        ("FREQ=MONTHLY;BYMONTHDAY=-32", .invalidValue(part: "BYMONTHDAY", value: "-32")),
        ("FREQ=WEEKLY;BYDAY=XX", .invalidValue(part: "BYDAY", value: "XX")),
        ("FREQ=MONTHLY;BYDAY=0MO", .invalidValue(part: "BYDAY", value: "0MO")),
        ("FREQ=YEARLY;BYDAY=54MO", .invalidValue(part: "BYDAY", value: "54MO")),
        ("FREQ=WEEKLY;BYDAY=", .invalidValue(part: "BYDAY", value: "")),
        ("FREQ=WEEKLY;WKST=XX", .invalidValue(part: "WKST", value: "XX")),
        ("FREQ=DAILY;UNTIL=20260230", .invalidValue(part: "UNTIL", value: "20260230")),
        ("FREQ=DAILY;UNTIL=2026101", .invalidValue(part: "UNTIL", value: "2026101")),
        // A DTSTART with a time zone needs a UTC UNTIL (RFC 5545), not a floating local time.
        ("FREQ=DAILY;UNTIL=20261010T235959", .floatingUntil("20261010T235959")),
        // Contradictory.
        ("FREQ=DAILY;COUNT=3;UNTIL=20261010", .countWithUntil),
        ("FREQ=WEEKLY;BYDAY=1MO", .ordinalNotAllowed(.weekly)),
        ("FREQ=DAILY;BYDAY=-1FR", .ordinalNotAllowed(.daily)),
        ("FREQ=WEEKLY;BYMONTHDAY=1", .monthDayInWeeklyRule),
    ]

    @Test(arguments: rejected)
    func aRuleOutsideTheSubsetIsRejectedWithItsReason(text: String, reason: RepeatRule.ParseError) {
        #expect(throws: reason) { try RepeatRule(rrule: text) }
    }

    @Test func everyRejectedRuleHasADistinctReason() {
        let reasons = Self.rejected.map { String(describing: $0.1) }
        #expect(Set(reasons).count == reasons.count)
    }
}
