import Foundation
import Testing
@testable import NudgeEngine

/// The plain-language summary of a repeat, as the mockup's `scheduleText` words it. Times and
/// dates come from the injected locale (en_GB: "18:00", "Sat 10 Oct"; en_US: "6:00 PM" with
/// Foundation's narrow no-break space, "Sat, Oct 10"), never the Mac's own.
struct RepeatSummaryTests {
    static let timeZone = TimeZone(identifier: "America/New_York")!
    static let british = Locale(identifier: "en_GB")
    static let american = Locale(identifier: "en_US")
    let clock = FakeClock(now: CustomRepeatTests.local(2026, 10, 15, 8))

    func summary(_ rrule: String, from dueTime: Date, locale: Locale = Self.british) throws -> String {
        let reminder = Reminder(title: "Water the plants", dueTime: dueTime, repeatRule: try RepeatRule(rrule: rrule), strength: .gentle)
        return Engine(clock: clock, scheduler: FakeScheduler(), timeZone: Self.timeZone, locale: locale).repeatSummary(of: reminder)
    }

    @Test func everyThreeDaysSaysTheIntervalAndTime() throws {
        #expect(try summary("FREQ=DAILY;INTERVAL=3", from: CustomRepeatTests.local(2026, 10, 15, 18)) == "Every 3 days at 18:00")
    }

    /// The ticket's own examples, then weekdays Monday first, and every way a rule ends. A UTC
    /// UNTIL at the end of a New York day reads as that date; one mid-day also gives its time.
    @Test(arguments: [
        ("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=5", CustomRepeatTests.local(2026, 10, 12), american,
         "Every 2 weeks on Monday and Wednesday at 9:00\u{202F}AM, 5 times"),
        ("FREQ=DAILY;INTERVAL=3;UNTIL=20261010", CustomRepeatTests.local(2026, 10, 1, 18), british, "Every 3 days at 18:00, until Sat 10 Oct"),
        ("FREQ=DAILY;INTERVAL=3;UNTIL=20261010", CustomRepeatTests.local(2026, 10, 1, 18), american, "Every 3 days at 6:00\u{202F}PM, until Sat, Oct 10"),
        ("FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR", CustomRepeatTests.local(2026, 10, 12), british, "Every weekday at 9:00"),
        ("FREQ=WEEKLY;BYDAY=FR,MO", CustomRepeatTests.local(2026, 10, 12), british, "Every Monday and Friday at 9:00"),
        ("FREQ=WEEKLY;BYDAY=SU,MO,WE", CustomRepeatTests.local(2026, 10, 12), british, "Every Monday, Wednesday and Sunday at 9:00"),
        ("FREQ=WEEKLY", CustomRepeatTests.local(2026, 10, 15), british, "Every Thursday at 9:00"),
        ("FREQ=WEEKLY;INTERVAL=2", CustomRepeatTests.local(2026, 10, 15), british, "Every 2 weeks on Thursday at 9:00"),
        ("FREQ=DAILY;COUNT=1", CustomRepeatTests.local(2026, 10, 15), british, "Every day at 9:00, once"),
        ("FREQ=DAILY;UNTIL=20261011T035959Z", CustomRepeatTests.local(2026, 10, 1), british, "Every day at 9:00, until Sat 10 Oct"),
        ("FREQ=DAILY;UNTIL=20261010T160000Z", CustomRepeatTests.local(2026, 10, 1), british, "Every day at 9:00, until Sat 10 Oct at 12:00"),
    ])
    func weeklyRulesAndEndingsReadAsTheMockupWordsThem(rrule: String, firstDueTime: Date, locale: Locale, text: String) throws {
        #expect(try summary(rrule, from: firstDueTime, locale: locale) == text)
    }

    /// Monthly and yearly rules, with the note for a day some months or years lack: a custom rule
    /// skips them and a preset moves to the last day. Then the wider RFC 5545 combinations.
    @Test(arguments: [
        ("FREQ=MONTHLY;BYMONTHDAY=-1", CustomRepeatTests.local(2026, 10, 31), "Every month on the last day at 9:00"),
        ("FREQ=MONTHLY;BYMONTHDAY=-2", CustomRepeatTests.local(2026, 10, 30), "Every month on the second-to-last day at 9:00"),
        ("FREQ=MONTHLY;BYDAY=1MO", CustomRepeatTests.local(2026, 10, 5), "Every month on the first Monday at 9:00"),
        ("FREQ=MONTHLY;BYDAY=-1FR", CustomRepeatTests.local(2026, 10, 30), "Every month on the last Friday at 9:00"),
        ("FREQ=MONTHLY;BYDAY=5MO", CustomRepeatTests.local(2026, 11, 30), "Every month on the fifth Monday (skipped in months without one) at 9:00"),
        ("FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=15", CustomRepeatTests.local(2026, 10, 15), "Every 2 months on the 15th at 9:00"),
        ("FREQ=MONTHLY;BYMONTHDAY=31", CustomRepeatTests.local(2026, 10, 31), "Every month on the 31st (skipped in months without one) at 9:00"),
        ("FREQ=MONTHLY", CustomRepeatTests.local(2026, 10, 31), "Every month on the 31st (skipped in months without one) at 9:00"),
        ("FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29", CustomRepeatTests.local(2028, 2, 29), "Every year on 29 February (skipped in years without one) at 9:00"),
        ("FREQ=YEARLY", CustomRepeatTests.local(2026, 10, 15), "Every year on 15 October at 9:00"),
        ("FREQ=YEARLY;BYMONTH=3", CustomRepeatTests.local(2026, 10, 15), "Every year on 15 March at 9:00"),
        ("FREQ=YEARLY;BYDAY=-1MO;BYMONTH=5", CustomRepeatTests.local(2027, 5, 31), "Every year on the last Monday of May at 9:00"),
        // RFC 5545 combinations beyond what the Custom page builds.
        ("FREQ=MONTHLY;BYDAY=FR;BYMONTHDAY=13", CustomRepeatTests.local(2026, 11, 13), "Every month on the 13th when it's a Friday at 9:00"),
        ("FREQ=MONTHLY;BYDAY=MO", CustomRepeatTests.local(2026, 10, 5), "Every month on every Monday at 9:00"),
        ("FREQ=MONTHLY;BYMONTH=1,7;BYMONTHDAY=1", CustomRepeatTests.local(2027, 1, 1), "Every month on the 1st in January and July at 9:00"),
        ("FREQ=YEARLY;BYMONTH=1,7;BYMONTHDAY=1,-1", CustomRepeatTests.local(2027, 1, 1), "Every year on the 1st and the last day of January and July at 9:00"),
        ("FREQ=YEARLY;BYMONTHDAY=1", CustomRepeatTests.local(2026, 11, 1), "Every year on the 1st of every month at 9:00"),
        ("FREQ=YEARLY;BYDAY=1MO", CustomRepeatTests.local(2027, 1, 4), "Every year on the first Monday of the year at 9:00"),
        ("FREQ=DAILY;BYDAY=MO,FR", CustomRepeatTests.local(2026, 10, 16), "Every day when it's a Monday or Friday at 9:00"),
        ("FREQ=DAILY;BYMONTHDAY=1,15", CustomRepeatTests.local(2026, 11, 1), "Every day when it's the 1st or the 15th at 9:00"),
        ("FREQ=DAILY;BYMONTH=12", CustomRepeatTests.local(2026, 12, 1), "Every day in December at 9:00"),
        ("FREQ=WEEKLY;BYMONTH=6,7,8", CustomRepeatTests.local(2027, 6, 3), "Every Thursday in June, July and August at 9:00"),
    ])
    func monthlyAndYearlyRulesReadAsTheMockupWordsThem(rrule: String, firstDueTime: Date, text: String) throws {
        #expect(try summary(rrule, from: firstDueTime) == text)
    }

    /// The presets clamp, so their note says where the day goes instead.
    @Test(arguments: [
        (RepeatRule.everyMonth, CustomRepeatTests.local(2026, 10, 31), "Every month on the 31st (the last day in months without one) at 9:00"),
        (.everyMonth, CustomRepeatTests.local(2026, 10, 15), "Every month on the 15th at 9:00"),
        (.everyYear, CustomRepeatTests.local(2028, 2, 29), "Every year on 29 February (28 February in years without one) at 9:00"),
        (.everyDay, CustomRepeatTests.local(2026, 10, 15), "Every day at 9:00"),
        (.everyWeekday, CustomRepeatTests.local(2026, 10, 15), "Every weekday at 9:00"),
        (.everyTwoWeeks, CustomRepeatTests.local(2026, 10, 15), "Every 2 weeks on Thursday at 9:00"),
    ])
    func presetsSayWhereAMissingDayGoes(preset: RepeatRule, firstDueTime: Date, text: String) {
        let reminder = Reminder(title: "Pay the rent", dueTime: firstDueTime, repeatRule: preset, strength: .firm)
        #expect(Engine(clock: clock, scheduler: FakeScheduler(), timeZone: Self.timeZone, locale: Self.british).repeatSummary(of: reminder) == text)
    }

    /// Never says when its one due time is, relative to now (Thursday 15 October 2026 at 8:00).
    @Test(arguments: [
        (CustomRepeatTests.local(2026, 10, 15), "Once, Today at 9:00"),
        (CustomRepeatTests.local(2026, 10, 16), "Once, Tomorrow at 9:00"),
        (CustomRepeatTests.local(2026, 10, 14), "Once, Yesterday at 9:00"),
        (CustomRepeatTests.local(2026, 10, 20), "Once, Tue 20 Oct at 9:00"),
    ])
    func neverSaysItsOneDueTime(dueTime: Date, text: String) {
        let reminder = Reminder(title: "Renew the passport", dueTime: dueTime, strength: .firm)
        #expect(Engine(clock: clock, scheduler: FakeScheduler(), timeZone: Self.timeZone, locale: Self.british).repeatSummary(of: reminder) == text)
    }

    /// No summary shows RRULE's own syntax.
    @Test(arguments: rulesForTheSyntaxCheck)
    func noSummaryShowsRRuleSyntax(rrule: String) throws {
        let text = try summary(rrule, from: CustomRepeatTests.local(2026, 10, 15))
        for syntax in ["FREQ", "BY", "INTERVAL", "COUNT", "UNTIL", "=", ";", "MO", "FR"] {
            #expect(!text.contains(syntax))
        }
    }

    static let rulesForTheSyntaxCheck = [
        "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=5", "FREQ=MONTHLY;BYDAY=-1FR", "FREQ=YEARLY;BYMONTH=1,7;BYMONTHDAY=1,-1;UNTIL=20271231",
        "FREQ=DAILY;BYDAY=MO,FR;UNTIL=20261231T170000Z",
    ]
}
