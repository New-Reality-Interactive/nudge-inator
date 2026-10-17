import Foundation
import Testing
import NudgeEngine

/// The Custom page's plain choices (ticket 25), turned into rules and back, in New York local
/// times. Each expected rule is written as its RRULE text.
struct CustomRepeatChoicesTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 17, 12))

    var engine: Engine { Engine(clock: clock, scheduler: FakeScheduler(), timeZone: NewYork.timeZone) }

    /// Monday 19 October 2026 at 9:00.
    static let monday = NewYork.local(2026, 10, 19)

    func rrule(of choices: CustomRepeat, startingAt start: Date = Self.monday) -> String {
        engine.repeatRule(for: choices, startingAt: start).rrule
    }

    @Test func customFromEveryTwoWeeksIsWeeklyEveryTwoWeeksOnTheStartsWeekday() {
        let choices = engine.customRepeat(from: .everyTwoWeeks, startingAt: Self.monday)

        #expect(rrule(of: choices) == "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO")
    }

    /// Never and Every Week start weekly on the start's weekday, as the mockup's `customFrom`.
    @Test(arguments: [
        (nil, "FREQ=WEEKLY;BYDAY=MO"),
        (RepeatRule.everyDay, "FREQ=DAILY"),
        (RepeatRule.everyWeekday, "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"),
        (RepeatRule.everyWeek, "FREQ=WEEKLY;BYDAY=MO"),
        (RepeatRule.everyMonth, "FREQ=MONTHLY;BYMONTHDAY=19"),
        (RepeatRule.everyYear, "FREQ=YEARLY;BYMONTH=10;BYMONTHDAY=19"),
    ])
    func customStartsFromThePresetThatWasChosen(preset: RepeatRule?, expected: String) {
        #expect(rrule(of: engine.customRepeat(from: preset, startingAt: Self.monday)) == expected)
    }

    /// October 2026 has 31 days. The nth weekday is offered for the first to the fourth; the last
    /// weekday only in the month's last seven days.
    @Test(arguments: [
        (1, [CustomRepeat.MonthlyDay.dayOfMonth, .weekdayOfMonth, .lastDay]),
        (22, [.dayOfMonth, .weekdayOfMonth, .lastDay]),
        (24, [.dayOfMonth, .weekdayOfMonth, .lastDay]),
        (25, [.dayOfMonth, .weekdayOfMonth, .lastWeekdayOfMonth, .lastDay]),
        (28, [.dayOfMonth, .weekdayOfMonth, .lastWeekdayOfMonth, .lastDay]),
        (29, [.dayOfMonth, .lastWeekdayOfMonth, .lastDay]),
        (31, [.dayOfMonth, .lastWeekdayOfMonth, .lastDay]),
    ])
    func monthlyChoicesFollowTheStartDate(day: Int, expected: [CustomRepeat.MonthlyDay]) {
        #expect(engine.monthlyDays(startingAt: NewYork.local(2026, 10, day)) == expected)
    }

    /// Wednesday 28 October 2026 is the fourth and the last Wednesday.
    @Test(arguments: [
        (CustomRepeat.MonthlyDay.dayOfMonth, "FREQ=MONTHLY;BYMONTHDAY=28"),
        (.weekdayOfMonth, "FREQ=MONTHLY;BYDAY=4WE"),
        (.lastWeekdayOfMonth, "FREQ=MONTHLY;BYDAY=-1WE"),
        (.lastDay, "FREQ=MONTHLY;BYMONTHDAY=-1"),
    ])
    func eachMonthlyChoiceBuildsItsRule(monthlyDay: CustomRepeat.MonthlyDay, expected: String) {
        let start = NewYork.local(2026, 10, 28)
        var choices = engine.customRepeat(from: .everyMonth, startingAt: start)
        choices.monthlyDay = monthlyDay

        #expect(rrule(of: choices, startingAt: start) == expected)
    }

    /// The choice stays, so moving the start back into a month's last week brings it back.
    @Test(arguments: [
        (CustomRepeat.MonthlyDay.lastWeekdayOfMonth, 14, "FREQ=MONTHLY;BYMONTHDAY=14"),
        (.weekdayOfMonth, 29, "FREQ=MONTHLY;BYMONTHDAY=29"),
    ])
    func aMonthlyChoiceTheNewStartDoesntOfferFallsBackToTheDayOfTheMonth(monthlyDay: CustomRepeat.MonthlyDay, newDay: Int, expected: String) {
        var choices = engine.customRepeat(from: .everyMonth, startingAt: NewYork.local(2026, 10, 28))
        choices.monthlyDay = monthlyDay

        #expect(rrule(of: choices, startingAt: NewYork.local(2026, 10, newDay)) == expected)
    }

    /// The mockup's defaults: after 10 times, or three months after the start.
    @Test(arguments: [
        (CustomRepeat.Ending.never, "FREQ=WEEKLY;BYDAY=MO"),
        (.afterCount, "FREQ=WEEKLY;BYDAY=MO;COUNT=10"),
        (.onDate, "FREQ=WEEKLY;BYDAY=MO;UNTIL=20270119"),
    ])
    func theEndsChoiceEndsTheRule(ending: CustomRepeat.Ending, expected: String) {
        var choices = engine.customRepeat(from: .everyWeek, startingAt: Self.monday)
        choices.ending = ending

        #expect(rrule(of: choices) == expected)
    }

    /// Every kind of rule the page builds, read back into its choices, builds the same rule, so
    /// an Edit form that opens a custom repeat has nothing changed.
    @Test(arguments: [
        ("FREQ=DAILY;INTERVAL=3", 19),
        ("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=5", 19),
        ("FREQ=MONTHLY;BYMONTHDAY=28", 28),
        ("FREQ=MONTHLY;BYDAY=4WE", 28),
        ("FREQ=MONTHLY;BYDAY=-1WE", 28),
        ("FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=-1;UNTIL=20270301", 28),
        ("FREQ=YEARLY;INTERVAL=2;BYMONTH=10;BYMONTHDAY=28;COUNT=30", 28),
    ])
    func aCustomRuleReadBackIntoItsChoicesBuildsTheSameRule(rrule: String, startDay: Int) throws {
        let rule = try RepeatRule(rrule: rrule)
        let start = NewYork.local(2026, 10, startDay)

        #expect(engine.repeatRule(for: engine.customRepeat(from: rule, startingAt: start), startingAt: start) == rule)
    }

    /// The page's limits: 30 days, 12 weeks, 12 months and 10 years.
    @Test(arguments: [
        (RepeatRule.Frequency.daily, 1...30),
        (.weekly, 1...12),
        (.monthly, 1...12),
        (.yearly, 1...10),
    ])
    func eachFrequencyHasItsIntervalLimits(frequency: RepeatRule.Frequency, limits: ClosedRange<Int>) {
        #expect(CustomRepeat.intervals(for: frequency) == limits)
    }

    @Test(arguments: [(RepeatRule.Frequency.weekly, 12), (.monthly, 12), (.yearly, 10)])
    func aNewFrequencyBringsTheIntervalWithinItsLimit(frequency: RepeatRule.Frequency, interval: Int) {
        var choices = engine.customRepeat(from: .everyDay, startingAt: Self.monday)
        choices.interval = 30
        choices.frequency = frequency

        #expect(choices.interval == interval)
    }

    @Test func theCountIsTwoToThirtyTimes() {
        #expect(CustomRepeat.counts == 2...30)
    }

    @Test func choosingAWeekdayAddsItAndChoosingItAgainTakesItOff() {
        var choices = engine.customRepeat(from: .everyWeek, startingAt: Self.monday)
        choices.toggle(.wednesday)
        #expect(rrule(of: choices) == "FREQ=WEEKLY;BYDAY=MO,WE")

        choices.toggle(.monday)
        #expect(rrule(of: choices) == "FREQ=WEEKLY;BYDAY=WE")
    }

    @Test func theLastChosenWeekdayCantBeTakenOff() {
        var choices = engine.customRepeat(from: .everyWeek, startingAt: Self.monday)
        choices.toggle(.monday)

        #expect(rrule(of: choices) == "FREQ=WEEKLY;BYDAY=MO")
    }

    /// An end date is the whole day, so the start's own day is fine. Times are New York's.
    @Test(arguments: [
        (CustomRepeat.Ending.onDate, NewYork.local(2026, 10, 18, 23, 59), true),
        (.onDate, NewYork.local(2026, 10, 19, 0, 0), false),
        (.never, NewYork.local(2026, 10, 18), false),
        (.afterCount, NewYork.local(2026, 10, 18), false),
    ])
    func anEndDateBeforeTheStartsDayEndsBeforeItStarts(ending: CustomRepeat.Ending, endDate: Date, endsBeforeStart: Bool) {
        var choices = engine.customRepeat(from: .everyWeek, startingAt: Self.monday)
        choices.ending = ending
        choices.endDate = endDate

        #expect(engine.endsBeforeStart(choices, startingAt: Self.monday) == endsBeforeStart)
    }

    /// In en_US. 28 October 2026 is the fourth and last Wednesday; 1 October is the first Thursday.
    @Test(arguments: [
        (CustomRepeat.MonthlyDay.dayOfMonth, 28, "On the 28th"),
        (.weekdayOfMonth, 28, "On the fourth Wednesday"),
        (.weekdayOfMonth, 1, "On the first Thursday"),
        (.weekdayOfMonth, 14, "On the second Wednesday"),
        (.weekdayOfMonth, 15, "On the third Thursday"),
        (.lastWeekdayOfMonth, 28, "On the last Wednesday"),
        (.lastDay, 28, "On the last day"),
    ])
    func eachMonthlyChoiceIsTitledFromTheStart(monthlyDay: CustomRepeat.MonthlyDay, startDay: Int, title: String) {
        let engine = Engine(clock: clock, scheduler: FakeScheduler(), timeZone: NewYork.timeZone, locale: Locale(identifier: "en_US"))

        #expect(engine.title(of: monthlyDay, startingAt: NewYork.local(2026, 10, startDay)) == title)
    }

    /// The ticket's example, built control by control from Every 2 Weeks.
    @Test func theChoicesBuildTheRuleTheSummaryDescribes() {
        let engine = Engine(clock: clock, scheduler: FakeScheduler(), timeZone: NewYork.timeZone, locale: Locale(identifier: "en_US"))
        var choices = engine.customRepeat(from: .everyTwoWeeks, startingAt: Self.monday)
        choices.toggle(.wednesday)
        choices.ending = .afterCount
        choices.count = 5
        let reminder = Reminder(title: "Water the plants", dueTime: Self.monday,
                                repeatRule: engine.repeatRule(for: choices, startingAt: Self.monday), strength: .gentle)

        #expect(engine.repeatSummary(of: reminder) == "Every 2 weeks on Monday and Wednesday at 9:00\u{202F}AM, 5 times")
    }

    /// The app never writes such a rule, but the parser accepts it. The page keeps what it can
    /// show (decision 5, ticket 25) and drops BYMONTH, which it has no control for.
    @Test func aRuleThePageCantShowReadsBackAsCloseAsItCan() throws {
        let rule = try RepeatRule(rrule: "FREQ=WEEKLY;INTERVAL=3;BYDAY=MO,FR;BYMONTH=6,7;COUNT=4")

        #expect(rrule(of: engine.customRepeat(from: rule, startingAt: Self.monday)) == "FREQ=WEEKLY;INTERVAL=3;BYDAY=MO,FR;COUNT=4")
    }

    /// The steppers can't show a value outside their limits, so a rule from elsewhere is read in
    /// within them.
    @Test(arguments: [
        ("FREQ=DAILY;INTERVAL=40", 30, 10),
        ("FREQ=WEEKLY;BYDAY=MO;COUNT=50", 1, 30),
        ("FREQ=WEEKLY;BYDAY=MO;COUNT=1", 1, 2),
    ])
    func aRestoredRuleIsReadInWithinTheSteppersLimits(rrule: String, interval: Int, count: Int) throws {
        let choices = engine.customRepeat(from: try RepeatRule(rrule: rrule), startingAt: Self.monday)

        #expect(choices.interval == interval)
        #expect(choices.count == count)
    }

    /// In en_US. A day some months lack is skipped (ADR 0003), so the page says so.
    @Test(arguments: [
        (31, CustomRepeat.MonthlyDay.dayOfMonth, "Months without a 31st are skipped. Choose On the last day to get every month." as String?),
        (29, .dayOfMonth, "Months without a 29th are skipped. Choose On the last day to get every month."),
        (28, .dayOfMonth, nil),
        (31, .lastDay, nil),
        (31, .lastWeekdayOfMonth, nil),
    ])
    func aMonthlyDaySomeMonthsLackSaysTheyAreSkipped(startDay: Int, monthlyDay: CustomRepeat.MonthlyDay, note: String?) {
        let engine = Engine(clock: clock, scheduler: FakeScheduler(), timeZone: NewYork.timeZone, locale: Locale(identifier: "en_US"))
        let start = NewYork.local(2026, 10, startDay)
        var choices = engine.customRepeat(from: .everyMonth, startingAt: start)
        choices.monthlyDay = monthlyDay

        #expect(engine.skippedMonthsNote(of: choices, startingAt: start) == note)
    }

    @Test func weekdayNamesFollowTheEnginesLocale() {
        let engine = Engine(clock: clock, scheduler: FakeScheduler(), timeZone: NewYork.timeZone, locale: Locale(identifier: "fr_FR"))

        #expect(engine.name(of: .monday) == "lundi")
    }
}
