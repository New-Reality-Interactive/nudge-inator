import Foundation
import Testing
@testable import NudgeEngine

/// The plain-language summary of a repeat, as the mockup's `scheduleText` words it. Times and
/// dates come from the injected locale (en_GB: "18:00", "Sat 10 Oct"; en_US: "6:00 PM" with
/// Foundation's narrow no-break space, "Sat, Oct 10"), never the Mac's own.
struct RepeatSummaryTests {
    static let british = Locale(identifier: "en_GB")
    static let american = Locale(identifier: "en_US")
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))

    func summary(_ rrule: String, from dueTime: Date, locale: Locale = Self.british) throws -> String {
        summary(of: Reminder(title: "Water the plants", dueTime: dueTime, repeatRule: try RepeatRule(rrule: rrule), strength: .gentle), locale: locale)
    }

    func summary(of reminder: Reminder, locale: Locale = Self.british) -> String {
        Engine(clock: clock, scheduler: FakeScheduler(), timeZone: NewYork.timeZone, locale: locale).repeatSummary(of: reminder)
    }

    @Test func everyThreeDaysSaysTheIntervalAndTime() throws {
        #expect(try summary("FREQ=DAILY;INTERVAL=3", from: NewYork.local(2026, 10, 15, 18)) == "Every 3 days at 18:00")
    }

    /// The ticket's own examples, then weekdays Monday first, and every way a rule ends. A UTC
    /// UNTIL at the end of a New York day reads as that date; one mid-day also gives its time.
    @Test(arguments: [
        ("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=5", NewYork.local(2026, 10, 12), american,
         "Every 2 weeks on Monday and Wednesday at 9:00\u{202F}AM, 5 times"),
        ("FREQ=DAILY;INTERVAL=3;UNTIL=20261010", NewYork.local(2026, 10, 1, 18), british, "Every 3 days at 18:00, until Sat 10 Oct"),
        ("FREQ=DAILY;INTERVAL=3;UNTIL=20261010", NewYork.local(2026, 10, 1, 18), american, "Every 3 days at 6:00\u{202F}PM, until Sat, Oct 10"),
        ("FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR", NewYork.local(2026, 10, 12), british, "Every weekday at 9:00"),
        ("FREQ=WEEKLY;BYDAY=FR,MO", NewYork.local(2026, 10, 12), british, "Every Monday and Friday at 9:00"),
        ("FREQ=WEEKLY;BYDAY=SU,MO,WE", NewYork.local(2026, 10, 12), british, "Every Monday, Wednesday and Sunday at 9:00"),
        // Lists follow the locale's own rules: American English has the serial comma.
        ("FREQ=WEEKLY;BYDAY=SU,MO,WE", NewYork.local(2026, 10, 12), american, "Every Monday, Wednesday, and Sunday at 9:00\u{202F}AM"),
        ("FREQ=WEEKLY", NewYork.local(2026, 10, 15), british, "Every Thursday at 9:00"),
        ("FREQ=WEEKLY;INTERVAL=2", NewYork.local(2026, 10, 15), british, "Every 2 weeks on Thursday at 9:00"),
        ("FREQ=DAILY;COUNT=1", NewYork.local(2026, 10, 15), british, "Every day at 9:00, once"),
        ("FREQ=DAILY;UNTIL=20261011T035959Z", NewYork.local(2026, 10, 1), british, "Every day at 9:00, until Sat 10 Oct"),
        ("FREQ=DAILY;UNTIL=20261010T160000Z", NewYork.local(2026, 10, 1), british, "Every day at 9:00, until Sat 10 Oct at 12:00"),
    ])
    func intervalsWeekdaysAndEndingsReadAsTheMockupWordsThem(rrule: String, firstDueTime: Date, locale: Locale, text: String) throws {
        #expect(try summary(rrule, from: firstDueTime, locale: locale) == text)
    }

    /// Monthly and yearly rules, with the note for a day some months or years lack: a custom rule
    /// skips them and a preset moves to the last day. Then the wider RFC 5545 combinations.
    @Test(arguments: [
        ("FREQ=MONTHLY;BYMONTHDAY=-1", NewYork.local(2026, 10, 31), "Every month on the last day at 9:00"),
        ("FREQ=MONTHLY;BYMONTHDAY=-2", NewYork.local(2026, 10, 30), "Every month on the second-to-last day at 9:00"),
        ("FREQ=MONTHLY;BYDAY=1MO", NewYork.local(2026, 10, 5), "Every month on the first Monday at 9:00"),
        ("FREQ=MONTHLY;BYDAY=-1FR", NewYork.local(2026, 10, 30), "Every month on the last Friday at 9:00"),
        ("FREQ=MONTHLY;BYDAY=5MO", NewYork.local(2026, 11, 30), "Every month on the fifth Monday (skipped in months without one) at 9:00"),
        ("FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=15", NewYork.local(2026, 10, 15), "Every 2 months on the 15th at 9:00"),
        ("FREQ=MONTHLY;BYMONTHDAY=31", NewYork.local(2026, 10, 31), "Every month on the 31st (skipped in months without one) at 9:00"),
        ("FREQ=MONTHLY", NewYork.local(2026, 10, 31), "Every month on the 31st (skipped in months without one) at 9:00"),
        ("FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29", NewYork.local(2028, 2, 29), "Every year on 29 February (skipped in years without one) at 9:00"),
        ("FREQ=YEARLY", NewYork.local(2026, 10, 15), "Every year on 15 October at 9:00"),
        ("FREQ=YEARLY;BYMONTH=3", NewYork.local(2026, 10, 15), "Every year on 15 March at 9:00"),
        ("FREQ=YEARLY;BYDAY=-1MO;BYMONTH=5", NewYork.local(2027, 5, 31), "Every year on the last Monday of May at 9:00"),
        // RFC 5545 combinations beyond what the Custom page builds.
        ("FREQ=MONTHLY;BYDAY=FR;BYMONTHDAY=13", NewYork.local(2026, 11, 13), "Every month on the 13th when it's a Friday at 9:00"),
        ("FREQ=MONTHLY;BYDAY=MO", NewYork.local(2026, 10, 5), "Every month on every Monday at 9:00"),
        ("FREQ=MONTHLY;BYMONTH=1,7;BYMONTHDAY=1", NewYork.local(2027, 1, 1), "Every month on the 1st in January and July at 9:00"),
        ("FREQ=YEARLY;BYMONTH=1,7;BYMONTHDAY=1,-1", NewYork.local(2027, 1, 1), "Every year on the 1st and the last day of January and July at 9:00"),
        ("FREQ=YEARLY;BYMONTHDAY=1", NewYork.local(2026, 11, 1), "Every year on the 1st of every month at 9:00"),
        ("FREQ=YEARLY;BYDAY=1MO", NewYork.local(2027, 1, 4), "Every year on the first Monday of the year at 9:00"),
        ("FREQ=DAILY;BYDAY=MO,FR", NewYork.local(2026, 10, 16), "Every day when it's a Monday or Friday at 9:00"),
        ("FREQ=DAILY;BYMONTHDAY=1,15", NewYork.local(2026, 11, 1), "Every day when it's the 1st or the 15th at 9:00"),
        ("FREQ=DAILY;BYMONTH=12", NewYork.local(2026, 12, 1), "Every day in December at 9:00"),
        // Review fixes: the note looks only at the months a rule falls in, and an ordinal no
        // month can have is noted too.
        ("FREQ=MONTHLY;BYMONTH=1,3;BYMONTHDAY=31", NewYork.local(2027, 1, 31), "Every month on the 31st in January and March at 9:00"),
        ("FREQ=MONTHLY;BYMONTH=1,4;BYMONTHDAY=31", NewYork.local(2027, 1, 31), "Every month on the 31st in January and April (skipped in months without one) at 9:00"),
        ("FREQ=MONTHLY;BYDAY=6MO", NewYork.local(2026, 10, 15), "Every month on the 6th Monday (skipped in months without one) at 9:00"),
        ("FREQ=WEEKLY;BYMONTH=6,7,8", NewYork.local(2027, 6, 3), "Every Thursday in June, July and August at 9:00"),
        // Review fixes (ticket 22): a day no month has stays that day, not the next month's, and
        // three or more days read as one list.
        ("FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30", NewYork.local(2027, 1, 1), "Every year on the 30th of February (skipped in years without one) at 9:00"),
        ("FREQ=DAILY;BYMONTHDAY=1,5,15", NewYork.local(2026, 11, 1), "Every day when it's the 1st, the 5th or the 15th at 9:00"),
        ("FREQ=MONTHLY;BYDAY=-6MO", NewYork.local(2026, 10, 15), "Every month on the 6th-to-last Monday (skipped in months without one) at 9:00"),
        ("FREQ=MONTHLY;BYMONTHDAY=1;BYDAY=MO,FR", NewYork.local(2026, 10, 15), "Every month on the 1st when it's a Monday or Friday at 9:00"),
        ("FREQ=DAILY;BYMONTHDAY=13;BYDAY=FR", NewYork.local(2026, 11, 13), "Every day when it's the 13th and a Friday at 9:00"),
    ])
    func daysOfTheMonthAndYearAndMonthLimitsReadAsTheMockupWordsThem(rrule: String, firstDueTime: Date, text: String) throws {
        #expect(try summary(rrule, from: firstDueTime) == text)
    }

    /// The presets clamp, so their note says where the day goes instead.
    @Test(arguments: [
        (RepeatRule.everyMonth, NewYork.local(2026, 10, 31), "Every month on the 31st (the last day in months without one) at 9:00"),
        (.everyMonth, NewYork.local(2026, 10, 15), "Every month on the 15th at 9:00"),
        (.everyYear, NewYork.local(2028, 2, 29), "Every year on 29 February (28 February in years without one) at 9:00"),
        (.everyDay, NewYork.local(2026, 10, 15), "Every day at 9:00"),
        (.everyWeekday, NewYork.local(2026, 10, 15), "Every weekday at 9:00"),
        (.everyTwoWeeks, NewYork.local(2026, 10, 15), "Every 2 weeks on Thursday at 9:00"),
    ])
    func presetsSayWhereAMissingDayGoes(preset: RepeatRule, firstDueTime: Date, text: String) {
        let reminder = Reminder(title: "Pay the rent", dueTime: firstDueTime, repeatRule: preset, strength: .firm)
        #expect(summary(of: reminder) == text)
    }

    /// A day and month follow the locale's order, in the note too (review fix, ticket 22).
    @Test func aDayAndMonthFollowTheLocale() {
        let reminder = Reminder(title: "Pay the rent", dueTime: NewYork.local(2028, 2, 29), repeatRule: .everyYear, strength: .firm)
        #expect(summary(of: reminder, locale: Self.american) == "Every year on February 29 (February 28 in years without one) at 9:00\u{202F}AM")
    }

    /// Never says when its one due time is, relative to now (Thursday 15 October 2026 at 8:00).
    @Test(arguments: [
        (NewYork.local(2026, 10, 15), "Once, Today at 9:00"),
        (NewYork.local(2026, 10, 16), "Once, Tomorrow at 9:00"),
        (NewYork.local(2026, 10, 14), "Once, Yesterday at 9:00"),
        (NewYork.local(2026, 10, 20), "Once, Tue 20 Oct at 9:00"),
    ])
    func neverSaysItsOneDueTime(dueTime: Date, text: String) {
        let reminder = Reminder(title: "Renew the passport", dueTime: dueTime, strength: .firm)
        #expect(summary(of: reminder) == text)
    }

    /// No summary shows RRULE's own syntax.
    @Test(arguments: rulesForTheSyntaxCheck)
    func noSummaryShowsRRuleSyntax(rrule: String) throws {
        let text = try summary(rrule, from: NewYork.local(2026, 10, 15))
        #expect(!["FREQ", "BY", "INTERVAL", "COUNT", "UNTIL", "=", ";", "MO", "FR"].contains { text.contains($0) })
    }

    static let rulesForTheSyntaxCheck = [
        "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=5", "FREQ=MONTHLY;BYDAY=-1FR", "FREQ=YEARLY;BYMONTH=1,7;BYMONTHDAY=1,-1;UNTIL=20271231",
        "FREQ=DAILY;BYDAY=MO,FR;UNTIL=20261231T170000Z",
    ]
}
