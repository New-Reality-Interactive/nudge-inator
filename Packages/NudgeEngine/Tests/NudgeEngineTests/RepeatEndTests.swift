import Foundation
import Testing
import NudgeEngine

/// The form's End Repeat (#287): how any repeat, preset or custom, ends. Read from a rule and
/// written back into one, in New York local times. Each expected rule is written as its RRULE text.
struct RepeatEndTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 17, 12))

    var engine: Engine { Engine(clock: clock, scheduler: FakeScheduler(), timeZone: NewYork.timeZone) }

    /// Monday 19 October 2026 at 9:00.
    static let monday = NewYork.local(2026, 10, 19)

    /// The mockup's defaults: Never, with After at 10 times and End Date three months after the start.
    @Test(arguments: [nil, RepeatRule.everyWeek])
    func aRuleWithNoEndReadsAsNeverWithTheDefaults(rule: RepeatRule?) {
        let end = engine.repeatEnd(of: rule, startingAt: Self.monday)

        #expect(end == RepeatEnd(ending: .never, count: 10, endDate: NewYork.local(2027, 1, 19)))
    }

    @Test(arguments: [
        (RepeatEnd.Ending.never, "FREQ=WEEKLY"),
        (.afterCount, "FREQ=WEEKLY;COUNT=10"),
        (.onDate, "FREQ=WEEKLY;UNTIL=20270119"),
    ])
    func eachEndingEndsAPreset(ending: RepeatEnd.Ending, expected: String) {
        var end = engine.repeatEnd(of: .everyWeek, startingAt: Self.monday)
        end.ending = ending

        #expect(engine.rule(.everyWeek, ending: end).rrule == expected)
    }

    /// The end replaces one the rule had.
    @Test func anEndingReplacesTheRulesOwn() throws {
        let rule = try RepeatRule(rrule: "FREQ=DAILY;INTERVAL=3;COUNT=4")
        var end = engine.repeatEnd(of: rule, startingAt: Self.monday)
        end.ending = .onDate
        end.endDate = NewYork.local(2026, 12, 1)

        #expect(engine.rule(rule, ending: end).rrule == "FREQ=DAILY;INTERVAL=3;UNTIL=20261201")
    }

    /// The stepper can't show a count outside its limits, so a rule from elsewhere is read in
    /// within them.
    @Test(arguments: [
        ("FREQ=WEEKLY;COUNT=5", RepeatEnd.Ending.afterCount, 5, NewYork.local(2027, 1, 19)),
        ("FREQ=WEEKLY;COUNT=50", .afterCount, 30, NewYork.local(2027, 1, 19)),
        ("FREQ=WEEKLY;COUNT=1", .afterCount, 2, NewYork.local(2027, 1, 19)),
        ("FREQ=MONTHLY;BYMONTHDAY=19;UNTIL=20261201", .onDate, 10, NewYork.local(2026, 12, 1, 0)),
    ])
    func aRulesEndIsReadIn(rrule: String, ending: RepeatEnd.Ending, count: Int, endDate: Date) throws {
        let end = engine.repeatEnd(of: try RepeatRule(rrule: rrule), startingAt: Self.monday)

        #expect(end == RepeatEnd(ending: ending, count: count, endDate: endDate))
    }

    @Test func theCountIsTwoToThirtyTimes() {
        #expect(RepeatEnd.counts == 2...30)
    }

    /// An end date is the whole day, so the start's own day is fine. Times are New York's.
    @Test(arguments: [
        (RepeatEnd.Ending.onDate, NewYork.local(2026, 10, 18, 23, 59), true),
        (.onDate, NewYork.local(2026, 10, 19, 0, 0), false),
        (.never, NewYork.local(2026, 10, 18), false),
        (.afterCount, NewYork.local(2026, 10, 18), false),
    ])
    func anEndDateBeforeTheStartsDayEndsBeforeItStarts(ending: RepeatEnd.Ending, endDate: Date, endsBeforeStart: Bool) {
        let end = RepeatEnd(ending: ending, count: 10, endDate: endDate)

        #expect(engine.endsBeforeStart(end, startingAt: Self.monday) == endsBeforeStart)
    }

    /// A preset with an end says so in its summary, as a custom repeat does.
    @Test func aPresetWithAnEndSaysSoInItsSummary() {
        let engine = Engine(clock: clock, scheduler: FakeScheduler(), timeZone: NewYork.timeZone, locale: Locale(identifier: "en_US"))
        let end = RepeatEnd(ending: .afterCount, count: 5, endDate: Self.monday)
        let reminder = Reminder(title: "Water the plants", dueTime: Self.monday,
                                repeatRule: engine.rule(.everyWeek, ending: end), strength: .gentle)

        #expect(engine.repeatSummary(of: reminder) == "Every Monday at 9:00\u{202F}AM, 5 times")
    }
}
