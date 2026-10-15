import Foundation
import Testing
@testable import NudgeEngine

/// Custom repeats' due times, in New York local times.
struct CustomRepeatTests {
    let clock = FakeClock(now: .distantPast)
    let scheduler = FakeScheduler()

    func engine(for reminders: Reminder...) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return engine
    }

    func reminder(_ rrule: String, from dueTime: Date) throws -> Reminder {
        Reminder(title: "Water the plants", dueTime: dueTime, repeatRule: try RepeatRule(rrule: rrule), strength: .gentle)
    }

    /// From Thursday 15 October 2026 at 9:00, after that day's due time.
    @Test func everyThreeDaysGivesTheNextThreeDueTimes() throws {
        let reminder = try reminder("FREQ=DAILY;INTERVAL=3", from: NewYork.local(2026, 10, 15))
        clock.now = NewYork.local(2026, 10, 15, 12)

        #expect(engine().upcomingDueTimes(of: reminder, count: 3)
            == [NewYork.local(2026, 10, 18), NewYork.local(2026, 10, 21), NewYork.local(2026, 10, 24)])
    }

    /// Thursday 15 October 2026 at noon, each from a first due time the rule falls on. Every 2
    /// weeks skips the week of the 19th. 1 November is a Sunday, so its first Monday is the 2nd;
    /// 31 October is a Saturday, so October's last Friday is the 30th.
    @Test(arguments: [
        ("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE", NewYork.local(2026, 10, 12), [NewYork.local(2026, 10, 26), NewYork.local(2026, 10, 28), NewYork.local(2026, 11, 9)]),
        ("FREQ=MONTHLY;BYDAY=1MO", NewYork.local(2026, 10, 5), [NewYork.local(2026, 11, 2), NewYork.local(2026, 12, 7), NewYork.local(2027, 1, 4)]),
        ("FREQ=MONTHLY;BYDAY=-1FR", NewYork.local(2026, 10, 30), [NewYork.local(2026, 10, 30), NewYork.local(2026, 11, 27), NewYork.local(2026, 12, 25)]),
        ("FREQ=MONTHLY;BYMONTHDAY=-1", NewYork.local(2026, 10, 31), [NewYork.local(2026, 10, 31), NewYork.local(2026, 11, 30), NewYork.local(2026, 12, 31)]),
    ])
    func aCustomRuleGivesItsNextThreeDueTimes(rrule: String, firstDueTime: Date, next: [Date]) throws {
        let reminder = try reminder(rrule, from: firstDueTime)
        clock.now = NewYork.local(2026, 10, 15, 12)

        #expect(engine().upcomingDueTimes(of: reminder, count: 3) == next)
    }

    /// Unlike the Every Month preset, which falls on 30 November instead (ticket 08), a custom
    /// rule on the 31st follows RFC 5545 and skips the months without one.
    @Test func aCustomRuleOnTheThirtyFirstSkipsShortMonthsWhereEveryMonthDoesNot() throws {
        let custom = try reminder("FREQ=MONTHLY;BYMONTHDAY=31", from: NewYork.local(2026, 10, 31))
        let preset = Reminder(title: "Pay the rent", dueTime: NewYork.local(2026, 10, 31), repeatRule: .everyMonth, strength: .firm)
        clock.now = NewYork.local(2026, 10, 15)

        #expect(engine().upcomingDueTimes(of: custom, count: 3) == [NewYork.local(2026, 10, 31), NewYork.local(2026, 12, 31), NewYork.local(2027, 1, 31)])
        #expect(engine().upcomingDueTimes(of: preset, count: 3) == [NewYork.local(2026, 10, 31), NewYork.local(2026, 11, 30), NewYork.local(2026, 12, 31)])
    }

    /// A custom 29 February skips to the next leap year, where Every Year falls on the 28th.
    @Test func aCustomRuleOnTheTwentyNinthOfFebruarySkipsNonLeapYears() throws {
        let reminder = try reminder("FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29", from: NewYork.local(2028, 2, 29))
        clock.now = NewYork.local(2028, 2, 1)

        #expect(engine().upcomingDueTimes(of: reminder, count: 3) == [NewYork.local(2028, 2, 29), NewYork.local(2032, 2, 29), NewYork.local(2036, 2, 29)])
    }

    /// RFC 5545: "The DTSTART property value always counts as the first occurrence", even when
    /// the rule doesn't fall on it (a case the RFC leaves undefined otherwise). So Every Weekday
    /// from Saturday 17 October 2026 nudges that Saturday, then on Monday.
    @Test func theFirstDueTimeIsAnOccurrenceEvenOffTheRule() {
        let reminder = Reminder(title: "Stand-up notes", dueTime: NewYork.local(2026, 10, 17), repeatRule: .everyWeekday, strength: .firm)
        clock.now = NewYork.local(2026, 10, 16)

        #expect(engine().upcomingDueTimes(of: reminder, count: 3) == [NewYork.local(2026, 10, 17), NewYork.local(2026, 10, 19), NewYork.local(2026, 10, 20)])
    }

    /// Three occurrences, then nothing: after the last one is Done there is no next, as with Never,
    /// and days later the Done one is still the latest.
    @Test func countThreeGivesExactlyThreeOccurrencesAndThenNoNext() throws {
        let reminder = try reminder("FREQ=DAILY;COUNT=3", from: NewYork.local(2026, 10, 15))
        clock.now = NewYork.local(2026, 10, 15, 8)
        #expect(engine().upcomingDueTimes(of: reminder, count: 5) == [NewYork.local(2026, 10, 15), NewYork.local(2026, 10, 16), NewYork.local(2026, 10, 17)])

        clock.now = NewYork.local(2026, 10, 17, 9, 5)
        var engine = engine(for: reminder)
        engine.markDone(reminder.id)
        #expect(try #require(scheduler.lastPlan).items.isEmpty)

        clock.now = NewYork.local(2026, 10, 20)
        engine.update(reminders: [reminder])
        #expect(engine.latestOccurrence(for: reminder.id) == Occurrence(dueTime: NewYork.local(2026, 10, 17), state: .done))
    }

    /// UNTIL is inclusive: a date takes in all of that day in New York, and a UTC date-time takes
    /// in that instant. 13:00 UTC on 17 October 2026 is 9:00 in New York, the due time itself.
    @Test(arguments: [
        ("FREQ=DAILY;UNTIL=20261017", [NewYork.local(2026, 10, 15), NewYork.local(2026, 10, 16), NewYork.local(2026, 10, 17)]),
        ("FREQ=DAILY;UNTIL=20261017T130000Z", [NewYork.local(2026, 10, 15), NewYork.local(2026, 10, 16), NewYork.local(2026, 10, 17)]),
        ("FREQ=DAILY;UNTIL=20261017T125959Z", [NewYork.local(2026, 10, 15), NewYork.local(2026, 10, 16)]),
    ])
    func untilIsInclusiveAndNothingFollowsIt(rrule: String, dueTimes: [Date]) throws {
        let reminder = try reminder(rrule, from: NewYork.local(2026, 10, 15))
        clock.now = NewYork.local(2026, 10, 15, 8)

        #expect(engine().upcomingDueTimes(of: reminder, count: 5) == dueTimes)
        clock.now = NewYork.local(2026, 10, 25)
        #expect(engine(for: reminder).latestOccurrence(for: reminder.id)?.dueTime == dueTimes.last)
    }

    /// Each preset written as RRULE text: the preset and the rule read from its text give the same
    /// next due times, in ticket 08's scenarios. Away from month ends, where only the presets
    /// clamp, skipping and clamping agree.
    @Test(arguments: [
        (RepeatRule.everyDay, "FREQ=DAILY", NewYork.local(2026, 10, 15), NewYork.local(2026, 10, 16),
         [NewYork.local(2026, 10, 16), NewYork.local(2026, 10, 17), NewYork.local(2026, 10, 18)]),
        (.everyWeekday, "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR", NewYork.local(2026, 10, 16), NewYork.local(2026, 10, 16, 9, 5),
         [NewYork.local(2026, 10, 19), NewYork.local(2026, 10, 20), NewYork.local(2026, 10, 21)]),
        (.everyWeek, "FREQ=WEEKLY", NewYork.local(2026, 10, 15, 18, 30), NewYork.local(2026, 11, 5, 19),
         [NewYork.local(2026, 11, 12, 18, 30), NewYork.local(2026, 11, 19, 18, 30), NewYork.local(2026, 11, 26, 18, 30)]),
        (.everyTwoWeeks, "FREQ=WEEKLY;INTERVAL=2", NewYork.local(2026, 10, 15, 18, 30), NewYork.local(2026, 11, 5, 19),
         [NewYork.local(2026, 11, 12, 18, 30), NewYork.local(2026, 11, 26, 18, 30), NewYork.local(2026, 12, 10, 18, 30)]),
        (.everyMonth, "FREQ=MONTHLY", NewYork.local(2026, 10, 15), NewYork.local(2026, 10, 20),
         [NewYork.local(2026, 11, 15), NewYork.local(2026, 12, 15), NewYork.local(2027, 1, 15)]),
        (.everyYear, "FREQ=YEARLY", NewYork.local(2026, 10, 15), NewYork.local(2026, 10, 20),
         [NewYork.local(2027, 10, 15), NewYork.local(2028, 10, 15), NewYork.local(2029, 10, 15)]),
    ])
    func eachPresetAsARuleGivesThePresetsDueTimes(preset: RepeatRule, rrule: String, firstDueTime: Date, now: Date, next: [Date]) throws {
        #expect(preset.rrule == rrule)
        clock.now = now
        let asPreset = Reminder(title: "Bins out", dueTime: firstDueTime, repeatRule: preset, strength: .firm)

        #expect(engine().upcomingDueTimes(of: asPreset, count: 3) == next)
        #expect(engine().upcomingDueTimes(of: try reminder(rrule, from: firstDueTime), count: 3) == next)
    }

    /// New York leaves DST on Sunday 1 November 2026: 9:00 Saturday to 9:00 Sunday is 25 hours,
    /// and the custom rule keeps 9:00 local on both sides.
    @Test func aCustomRuleKeepsItsLocalTimeOfDayAcrossADSTChange() throws {
        let reminder = try reminder("FREQ=WEEKLY;BYDAY=SA,SU", from: NewYork.local(2026, 10, 31))
        clock.now = NewYork.local(2026, 10, 30)

        let dueTimes = engine().upcomingDueTimes(of: reminder, count: 3)
        #expect(dueTimes == [NewYork.local(2026, 10, 31), NewYork.local(2026, 11, 1), NewYork.local(2026, 11, 7)])
        #expect(dueTimes[1].timeIntervalSince(dueTimes[0]) == 25 * 60 * 60)
    }

    /// 30 February never comes, so after the first due time (which always counts) the bounded
    /// search reports no next occurrence, with or without a COUNT still to reach.
    @Test(arguments: ["FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30", "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30;COUNT=5"])
    func aRuleWithNoValidDateHasNoNextOccurrence(rrule: String) throws {
        let reminder = try reminder(rrule, from: NewYork.local(2026, 10, 15))
        clock.now = NewYork.local(2026, 10, 15, 8)

        #expect(engine().upcomingDueTimes(of: reminder, count: 3) == [NewYork.local(2026, 10, 15)])
        clock.now = NewYork.local(2026, 10, 15, 12)
        _ = engine(for: reminder)
        #expect(try #require(scheduler.lastPlan).items.allSatisfy { $0.fireTime < NewYork.local(2026, 10, 16) })
    }

    /// A first due time in a month the rule never falls in is still the latest occurrence until
    /// the rule's first March.
    @Test func theFirstDueTimeOffTheRulesMonthsStaysTheLatestUntilTheNext() throws {
        let reminder = try reminder("FREQ=YEARLY;BYMONTH=3", from: NewYork.local(2026, 10, 15))
        clock.now = NewYork.local(2027, 1, 10)

        #expect(engine(for: reminder).latestOccurrence(for: reminder.id)?.dueTime == NewYork.local(2026, 10, 15))
        #expect(engine().upcomingDueTimes(of: reminder, count: 1) == [NewYork.local(2027, 3, 15)])
    }

    /// The rarest rule the Custom page can build, every 10 years 30 times, spans three centuries
    /// but each step is its own bounded search, so all 30 come out and then nothing.
    @Test func aLongCountOfRareDatesGivesEveryOccurrence() throws {
        let reminder = try reminder("FREQ=YEARLY;INTERVAL=10;COUNT=30", from: NewYork.local(2026, 10, 15))
        clock.now = NewYork.local(2026, 10, 15, 8)

        let dueTimes = engine().upcomingDueTimes(of: reminder, count: 31)
        #expect(dueTimes.count == 30)
        #expect(dueTimes.last == NewYork.local(2316, 10, 15))
    }

    /// Review fix: the COUNT is walked only as far as the date asked about, so a huge COUNT from
    /// text (the parser takes any) answers at once instead of walking every occurrence each call.
    @Test(.timeLimit(.minutes(1)))
    func aHugeCountStillAnswersPromptly() throws {
        let reminder = try reminder("FREQ=DAILY;COUNT=100000000", from: NewYork.local(2026, 10, 15))
        clock.now = NewYork.local(2026, 10, 15, 8)
        #expect(engine().upcomingDueTimes(of: reminder, count: 3) == [NewYork.local(2026, 10, 15), NewYork.local(2026, 10, 16), NewYork.local(2026, 10, 17)])

        clock.now = NewYork.local(2027, 10, 15, 12)
        #expect(engine(for: reminder).latestOccurrence(for: reminder.id)?.dueTime == NewYork.local(2027, 10, 15))
    }

    /// Review fix: rare rules whose next date is decades away still find it. The search is
    /// bounded by the days it looks at, not the span of the calendar, and it jumps straight past
    /// the periods the interval rules out. 29 February 2016 and 2044 are Mondays.
    @Test(arguments: [
        ("FREQ=YEARLY;INTERVAL=3", NewYork.local(2028, 2, 29), NewYork.local(2040, 2, 29)),
        ("FREQ=YEARLY;INTERVAL=20", NewYork.local(2026, 10, 15), NewYork.local(2046, 10, 15)),
        ("FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=29;BYDAY=MO", NewYork.local(2016, 2, 29), NewYork.local(2044, 2, 29)),
    ])
    func aRareRuleFindsANextDateDecadesAway(rrule: String, firstDueTime: Date, next: Date) throws {
        let reminder = try reminder(rrule, from: firstDueTime)
        clock.now = firstDueTime.addingTimeInterval(60 * 60)

        #expect(engine().upcomingDueTimes(of: reminder, count: 1) == [next])
    }
}
