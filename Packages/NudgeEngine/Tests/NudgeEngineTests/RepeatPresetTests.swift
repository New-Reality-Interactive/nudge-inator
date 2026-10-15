import Foundation
import Testing
@testable import NudgeEngine

/// The presets and the next-due time. Dates are written as local wall-clock times in New York,
/// which has DST, so no test depends on the Mac's own time zone.
struct RepeatPresetTests {
    static let timeZone = TimeZone(identifier: "America/New_York")!
    let clock = FakeClock(now: .distantPast)
    let scheduler = FakeScheduler()

    /// A local time in New York.
    static func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func engine(for reminder: Reminder) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: Self.timeZone)
        engine.update(reminders: [reminder])
        return engine
    }

    @Test func nextOccurrenceStartsAtNudgeOneWhenItsDueTimeArrives() throws {
        // Thursday 15 October 2026 at 9:00, Every Day.
        let reminder = Reminder(title: "Take the pills", dueTime: Self.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm)
        clock.now = Self.local(2026, 10, 16)

        let occurrence = try #require(engine(for: reminder).latestOccurrence(for: reminder.id))

        #expect(occurrence.dueTime == Self.local(2026, 10, 16))
        #expect(occurrence.state == .nudging(nudgeNumber: 1))
    }

    /// Never is no repeat rule at all: once Done, the reminder has nothing more to plan, and a
    /// week later its latest occurrence is still the Done one.
    @Test func neverHasOneOccurrenceAndNothingAfterItCloses() throws {
        let reminder = Reminder(title: "Renew the passport", dueTime: Self.local(2026, 10, 15), strength: .firm)
        clock.now = Self.local(2026, 10, 15)
        var engine = engine(for: reminder)
        engine.markDone(reminder.id)

        clock.now = Self.local(2026, 10, 22)
        engine.update(reminders: [reminder])

        #expect(engine.latestOccurrence(for: reminder.id) == Occurrence(dueTime: Self.local(2026, 10, 15), state: .done))
        #expect(try #require(scheduler.lastPlan).items.isEmpty)
    }

    /// After Done, the plan holds the next occurrence's whole ladder, starting with nudge 1 at its
    /// due time, so it nudges even if the app stays closed until then.
    @Test func afterDoneThePlanHoldsTheNextOccurrencesLadder() throws {
        let reminder = Reminder(title: "Take the pills", dueTime: Self.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm)
        clock.now = Self.local(2026, 10, 15, 9, 5)
        var engine = engine(for: reminder)
        engine.markDone(reminder.id)

        let items = try #require(scheduler.lastPlan).items
        // Firm's whole ladder: 20 nudges, all inside the 24-hour span.
        #expect(items.count == 20)
        #expect(items.first?.nudgeNumber == 1)
        #expect(items.first?.fireTime == Self.local(2026, 10, 16))
        #expect(items.first?.urgency == .normal)
    }

    /// Friday 16 October 2026's occurrence is Done; the next is Monday the 19th, and over the
    /// weekend the Friday one stays the latest.
    @Test func everyWeekdaySkipsSaturdayAndSunday() throws {
        let friday = Self.local(2026, 10, 16)
        let reminder = Reminder(title: "Stand-up notes", dueTime: friday, repeatRule: .everyWeekday, strength: .firm)
        clock.now = friday
        var engine = engine(for: reminder)
        engine.markDone(reminder.id)

        #expect(try #require(scheduler.lastPlan).items.first?.fireTime == Self.local(2026, 10, 19))
        clock.now = Self.local(2026, 10, 18, 23, 59)
        #expect(engine.latestOccurrence(for: reminder.id)?.dueTime == friday)
    }

    /// From Thursday 15 October 2026 at 18:30, on Thursday 5 November at 19:00: Every Week's
    /// latest occurrence is that day's, and Every 2 Weeks' is 29 October's (two weeks after the
    /// 15th; the 5th is three weeks after it). Both keep Thursday at 18:30.
    @Test(arguments: [
        (RepeatRule.everyWeek, Self.local(2026, 11, 5, 18, 30)),
        (.everyTwoWeeks, Self.local(2026, 10, 29, 18, 30)),
    ])
    func everyWeekAndEveryTwoWeeksKeepTheWeekdayAndTimeOfDay(rule: RepeatRule, latestDueTime: Date) {
        let reminder = Reminder(title: "Bins out", dueTime: Self.local(2026, 10, 15, 18, 30), repeatRule: rule, strength: .gentle)
        clock.now = Self.local(2026, 11, 5, 19)

        #expect(engine(for: reminder).latestOccurrence(for: reminder.id)?.dueTime == latestDueTime)
    }

    /// The rule: Every Month's day comes from the first due time, never from the occurrence before.
    /// From 31 October 2026 it falls on the last day of a month without a 31st (30 November,
    /// 28 February 2027) and returns to the 31st in the next month that has one (31 December,
    /// 31 March). Nothing falls due before the month's day: on 29 November the latest is still
    /// 31 October's.
    @Test(arguments: [
        (Self.local(2026, 11, 29, 12), Self.local(2026, 10, 31)),
        (Self.local(2026, 11, 30, 12), Self.local(2026, 11, 30)),
        (Self.local(2026, 12, 31, 12), Self.local(2026, 12, 31)),
        (Self.local(2027, 2, 28, 12), Self.local(2027, 2, 28)),
        (Self.local(2027, 3, 31, 12), Self.local(2027, 3, 31)),
        (Self.local(2027, 4, 30, 12), Self.local(2027, 4, 30)),
    ])
    func everyMonthFromTheThirtyFirstFallsOnTheLastDayOfShorterMonths(now: Date, latestDueTime: Date) {
        let reminder = Reminder(title: "Pay the rent", dueTime: Self.local(2026, 10, 31), repeatRule: .everyMonth, strength: .firm)
        clock.now = now

        #expect(engine(for: reminder).latestOccurrence(for: reminder.id)?.dueTime == latestDueTime)
    }

    /// From 29 February 2028: 28 February in 2029, 2030 and 2031, and 29 February again in 2032.
    /// On 27 February 2029 the latest is still 2028's.
    @Test(arguments: [
        (Self.local(2029, 2, 27, 12), Self.local(2028, 2, 29)),
        (Self.local(2029, 2, 28, 12), Self.local(2029, 2, 28)),
        (Self.local(2031, 3, 1, 12), Self.local(2031, 2, 28)),
        (Self.local(2032, 2, 29, 12), Self.local(2032, 2, 29)),
    ])
    func everyYearFromTheTwentyNinthOfFebruaryFallsOnTheTwentyEighthInNonLeapYears(now: Date, latestDueTime: Date) {
        let reminder = Reminder(title: "Birthday call", dueTime: Self.local(2028, 2, 29), repeatRule: .everyYear, strength: .gentle)
        clock.now = now

        #expect(engine(for: reminder).latestOccurrence(for: reminder.id)?.dueTime == latestDueTime)
    }

    /// New York leaves DST on Sunday 1 November 2026 and enters it on Sunday 14 March 2027. 9:00
    /// on the Saturday before to 9:00 on the Sunday is 25 hours in autumn and 23 in spring.
    @Test(arguments: [
        (Self.local(2026, 10, 31), 25.0),
        (Self.local(2027, 3, 13), 23.0),
    ])
    func timeOfDayAcrossADSTChangeKeepsTheLocalTime(saturday: Date, hoursToSunday: Double) throws {
        let reminder = Reminder(title: "Water the plants", dueTime: saturday, repeatRule: .everyDay, strength: .relentless)
        clock.now = saturday
        var engine = engine(for: reminder)
        engine.markDone(reminder.id)

        #expect(try #require(scheduler.lastPlan).items.first?.fireTime == saturday + hoursToSunday * 60 * 60)
    }

    /// Every Month is a rule like any custom one; only its missing-day policy differs. The same
    /// parts with RFC 5545's skip (what ticket 09's parser produces) pass over 30 November.
    @Test func aMonthlyRuleThatSkipsHasNoOccurrenceInAMonthWithoutItsDay() throws {
        let skipping = try #require(RepeatRule(frequency: .monthly, missingDay: .skip))
        #expect(RepeatRule.everyMonth == RepeatRule(frequency: .monthly, missingDay: .lastDayOfMonth))
        let reminder = Reminder(title: "Pay the rent", dueTime: Self.local(2026, 10, 31), repeatRule: skipping, strength: .firm)

        clock.now = Self.local(2026, 12, 30, 12)
        #expect(engine(for: reminder).latestOccurrence(for: reminder.id)?.dueTime == Self.local(2026, 10, 31))
        clock.now = Self.local(2026, 12, 31, 12)
        #expect(engine(for: reminder).latestOccurrence(for: reminder.id)?.dueTime == Self.local(2026, 12, 31))
    }

    /// The presets' next-due path honours `INTERVAL` for every frequency, daily included, so a
    /// custom "every 3 days" from 15 October falls due on the 18th and the 21st, not the 16th.
    @Test(arguments: [
        (Self.local(2026, 10, 17, 12), Self.local(2026, 10, 15)),
        (Self.local(2026, 10, 18, 12), Self.local(2026, 10, 18)),
        (Self.local(2026, 10, 21, 12), Self.local(2026, 10, 21)),
    ])
    func aDailyRuleWithAnIntervalFallsDueEveryIntervalDays(now: Date, latestDueTime: Date) throws {
        let everyThreeDays = try #require(RepeatRule(frequency: .daily, interval: 3))
        let reminder = Reminder(title: "Water the plants", dueTime: Self.local(2026, 10, 15), repeatRule: everyThreeDays, strength: .gentle)
        clock.now = now

        #expect(engine(for: reminder).latestOccurrence(for: reminder.id)?.dueTime == latestDueTime)
    }

    /// `INTERVAL` must be at least 1 (RFC 5545), so a rule with 0 or less can't be made.
    @Test(arguments: [0, -1])
    func aRuleNeedsAnIntervalOfAtLeastOne(interval: Int) {
        #expect(RepeatRule(frequency: .daily, interval: interval) == nil)
    }

    @Test func doneClosesOnlyItsOwnOccurrence() {
        let reminder = Reminder(title: "Take the pills", dueTime: Self.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm)
        clock.now = Self.local(2026, 10, 15, 9, 5)
        var engine = engine(for: reminder)
        engine.markDone(reminder.id)

        clock.now = Self.local(2026, 10, 16, 9, 5)
        engine.update(reminders: [reminder])

        #expect(engine.openOccurrence(for: reminder.id) == Occurrence(dueTime: Self.local(2026, 10, 16), state: .nudging(nudgeNumber: 1)))
    }

    @Test func doneOnALaterOccurrenceClosesThatOccurrence() throws {
        let reminder = Reminder(title: "Take the pills", dueTime: Self.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm)
        clock.now = Self.local(2026, 10, 16, 9, 5)
        var engine = engine(for: reminder)
        engine.markDone(reminder.id)

        #expect(engine.latestOccurrence(for: reminder.id) == Occurrence(dueTime: Self.local(2026, 10, 16), state: .done))
        #expect(try #require(scheduler.lastPlan).items.first?.fireTime == Self.local(2026, 10, 17))
    }

    /// While an occurrence nudges, the plan already holds the next one's ladder after its own, so
    /// the next occurrence starts on time even if the app stays closed across the boundary.
    @Test func whileNudgingThePlanHoldsThisLadderThenTheNextOne() throws {
        let reminder = Reminder(title: "Take the pills", dueTime: Self.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm)
        clock.now = Self.local(2026, 10, 15, 9, 5)
        _ = engine(for: reminder)

        let items = try #require(scheduler.lastPlan).items
        #expect(items.map(\.nudgeNumber) == Array(1...20) + Array(1...20))
        #expect(items[0].fireTime == Self.local(2026, 10, 15))
        #expect(items[20].fireTime == Self.local(2026, 10, 16))
    }
}
