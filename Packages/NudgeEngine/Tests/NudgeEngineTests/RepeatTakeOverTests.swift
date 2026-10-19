import Foundation
import Testing
@testable import NudgeEngine

/// Take-over: when a repeat's next occurrence falls due while the previous is still Nudging, the
/// previous closes as Missed ("the next one took over") and the new one starts at nudge 1.
///
/// With the shipped limits every strength gives up within 8 h 4 min 4 s and the shortest repeat
/// gap is a day, so the overlap can't happen. These tests widen the give-up limit through the
/// internal init (10,000 nudges or 72 hours) so an every-day or every-2-days reminder is still
/// Nudging when its next occurrence falls due. The `Ladder` constants are untouched.
struct RepeatTakeOverTests {
    static let widened = GiveUpLimit(nudgeCount: 10_000, span: 72 * 60 * 60)
    let clock = FakeClock(now: .distantPast)
    let scheduler = FakeScheduler()
    /// Every day at 9:00 from Thursday 15 October 2026.
    let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), repeatRule: .everyDay, strength: .relentless)

    func engine(for reminder: Reminder, giveUpLimit: GiveUpLimit = widened) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, giveUpLimit: giveUpLimit, timeZone: NewYork.timeZone)
        engine.update(reminders: [reminder])
        return engine
    }

    @Test func atTheTakeOverInstantTheReminderHasOneOpenOccurrenceAndThePreviousIsMissed() throws {
        clock.now = NewYork.local(2026, 10, 16)
        let engine = engine(for: pills)

        #expect(engine.openOccurrence(for: pills.id) == Occurrence(dueTime: NewYork.local(2026, 10, 16), state: .nudging(nudgeNumber: 1)))
        let previous = try #require(engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15)))
        #expect(previous.state == .missed(reason: .nextTookOver))
    }

    /// An hour after take-over the old occurrence would still be within its widened limit, but
    /// it stays Missed: it never nudges again beside the new one.
    @Test func theTakenOverOccurrenceStaysMissedWhileItsLimitWouldStillRun() {
        clock.now = NewYork.local(2026, 10, 16, 10)

        #expect(engine(for: pills).occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15))?.state == .missed(reason: .nextTookOver))
    }

    /// Each nudge names the occurrence it is for, so a Done before the first unlock can stop that
    /// occurrence's nudges without touching the next one's (ticket 32).
    @Test func eachNudgeCarriesItsOccurrencesDueTime() throws {
        let open = NewYork.local(2026, 10, 15)
        let next = NewYork.local(2026, 10, 16)

        clock.now = NewYork.local(2026, 10, 16, 8)
        _ = engine(for: pills)
        let items = try #require(scheduler.lastPlan).items

        #expect(items.filter { $0.fireTime < next }.allSatisfy { $0.dueTime == open })
        #expect(items.filter { $0.fireTime >= next }.allSatisfy { $0.dueTime == next })
        #expect(Set(items.map(\.dueTime)) == [open, next])
    }

    /// An hour before the next one falls due, the old occurrence is still Nudging. Its ladder stops
    /// at the next due time, so from then on the plan holds only the new occurrence, from nudge 1
    /// at the strength's lowest urgency.
    @Test(arguments: [
        (Strength.gentle, Urgency.normal),
        (.firm, .normal),
        (.relentless, .high),
    ])
    func theOldLadderStopsWhereTheNewOccurrenceStartsAtNudgeOne(strength: Strength, lowestUrgency: Urgency) throws {
        var reminder = pills
        reminder.strength = strength
        let nextDueTime = NewYork.local(2026, 10, 16)

        clock.now = NewYork.local(2026, 10, 16, 8)
        _ = engine(for: reminder)
        let items = try #require(scheduler.lastPlan).items.sorted { $0.fireTime < $1.fireTime }

        let fromNextDueTime = items.filter { $0.fireTime >= nextDueTime }
        let first = try #require(fromNextDueTime.first)
        #expect(first.fireTime == nextDueTime)
        #expect(first.nudgeNumber == 1)
        #expect(first.urgency == lowestUrgency)
        #expect(fromNextDueTime.map(\.nudgeNumber) == Array(1...fromNextDueTime.count))
        #expect(items.contains { $0.fireTime < nextDueTime })
    }

    /// At the take-over instant the plan holds the new occurrence's ladder, stopped where the one
    /// after it falls due, and that one's ladder from nudge 1. Nothing from the old occurrence.
    @Test func atTheTakeOverInstantThePlanHoldsOnlyTheNewOccurrenceAndTheOneAfter() throws {
        let newDueTime = NewYork.local(2026, 10, 16)
        let afterDueTime = NewYork.local(2026, 10, 17)

        clock.now = newDueTime
        _ = engine(for: pills)
        let items = try #require(scheduler.lastPlan).items.sorted { $0.fireTime < $1.fireTime }

        #expect(items.allSatisfy { $0.fireTime >= newDueTime })
        let newLadder = items.filter { $0.fireTime < afterDueTime }
        let afterLadder = items.filter { $0.fireTime >= afterDueTime }
        #expect(newLadder.first?.fireTime == newDueTime)
        #expect(newLadder.map(\.nudgeNumber) == Array(1...newLadder.count))
        #expect(afterLadder.first?.fireTime == afterDueTime)
        #expect(afterLadder.map(\.nudgeNumber) == Array(1...afterLadder.count))
    }

    /// 9:30 isn't a due time of a 9:00 every-day reminder, and 17 October hasn't come yet.
    @Test(arguments: [NewYork.local(2026, 10, 15, 9, 30), NewYork.local(2026, 10, 17)])
    func aTimeThatIsNotAPastDueTimeHasNoOccurrence(dueTime: Date) {
        clock.now = NewYork.local(2026, 10, 16, 12)

        #expect(engine(for: pills).occurrence(of: pills.id, dueAt: dueTime) == nil)
    }

    /// With a 24-hour span and no count limit, an every-day occurrence gives up at the very
    /// instant the next falls due. The next one takes over, as in the mockup's `simulate`.
    @Test func whenTheGiveUpTimeIsTheNextDueTimeTheNextTakesOver() {
        clock.now = NewYork.local(2026, 10, 16)
        let engine = engine(for: pills, giveUpLimit: GiveUpLimit(nudgeCount: 10_000, span: 24 * 60 * 60))

        #expect(engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15))?.state == .missed(reason: .nextTookOver))
    }

    /// Due times keep 9:00 across DST, but the span is elapsed time. With a 24-hour span and no
    /// count limit, the 23-hour day of the March change lets the next take over an hour before
    /// the old one would give up, and the 25-hour day of the November change lets the old one
    /// give up an hour before the next falls due.
    @Test(arguments: [
        (NewYork.local(2027, 3, 13), NewYork.local(2027, 3, 14), MissedReason.nextTookOver),
        (NewYork.local(2026, 10, 31), NewYork.local(2026, 11, 1), .giveUpLimit),
    ])
    func acrossADSTChangeTheReasonFollowsWhichComesFirst(firstDueTime: Date, nextDueTime: Date, reason: MissedReason) {
        var reminder = pills
        reminder.dueTime = firstDueTime
        clock.now = nextDueTime
        let engine = engine(for: reminder, giveUpLimit: GiveUpLimit(nudgeCount: 10_000, span: 24 * 60 * 60))

        #expect(engine.occurrence(of: reminder.id, dueAt: firstDueTime)?.state == .missed(reason: reason))
        #expect(engine.openOccurrence(for: reminder.id) == Occurrence(dueTime: nextDueTime, state: .nudging(nudgeNumber: 1)))
    }

    @Test func aPreviousOccurrenceThatIsDoneStaysDone() {
        clock.now = NewYork.local(2026, 10, 15, 12)
        var engine = engine(for: pills)
        engine.markDone(pills.id)

        clock.now = NewYork.local(2026, 10, 16)

        #expect(engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15))?.state == .done)
    }

    /// With the shipped limits, Relentless gives up at +51 min 30 s, long before the next day.
    /// With a widened 12-hour span it gives up at 21:00, still before the next day's 9:00.
    @Test(arguments: [GiveUpLimit.shipped, GiveUpLimit(nudgeCount: 10_000, span: 12 * 60 * 60)])
    func aPreviousOccurrenceMissedByTheGiveUpLimitKeepsThatReason(giveUpLimit: GiveUpLimit) {
        clock.now = NewYork.local(2026, 10, 16)
        let engine = engine(for: pills, giveUpLimit: giveUpLimit)

        #expect(engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15))?.state == .missed(reason: .giveUpLimit))
    }

    /// One next-due path for presets and custom rules: an every-2-days rule takes over on the
    /// second day, and the day between leaves the old occurrence Nudging.
    @Test(arguments: [
        (RepeatRule.everyDay, NewYork.local(2026, 10, 16)),
        (try! RepeatRule(rrule: "FREQ=DAILY;INTERVAL=2"), NewYork.local(2026, 10, 17)),
    ])
    func takeOverFollowsTheRepeatRulesNextDueTime(repeatRule: RepeatRule, nextDueTime: Date) {
        var reminder = pills
        reminder.repeatRule = repeatRule
        let firstDueTime = NewYork.local(2026, 10, 15)

        clock.now = nextDueTime - 1
        #expect(engine(for: reminder).openOccurrence(for: reminder.id)?.dueTime == firstDueTime)

        clock.now = nextDueTime
        let engine = engine(for: reminder)
        #expect(engine.openOccurrence(for: reminder.id) == Occurrence(dueTime: nextDueTime, state: .nudging(nudgeNumber: 1)))
        #expect(engine.occurrence(of: reminder.id, dueAt: firstDueTime)?.state == .missed(reason: .nextTookOver))
    }

    /// The last occurrence of a rule that ends has no next one to take it over: a day after it
    /// falls due it is still Nudging and its ladder isn't cut, and it closes by the give-up limit.
    @Test(arguments: ["FREQ=DAILY;COUNT=2", "FREQ=DAILY;UNTIL=20261016"])
    func theLastOccurrenceOfAnEndingRuleIsNeverTakenOver(rrule: String) throws {
        var reminder = pills
        reminder.repeatRule = try RepeatRule(rrule: rrule)
        let lastDueTime = NewYork.local(2026, 10, 16)

        clock.now = NewYork.local(2026, 10, 17)
        var engine = engine(for: reminder)
        #expect(engine.openOccurrence(for: reminder.id)?.dueTime == lastDueTime)
        let items = try #require(scheduler.lastPlan).items
        #expect(items.contains { $0.fireTime > NewYork.local(2026, 10, 17) })

        clock.now = lastDueTime + Self.widened.span
        engine.update(reminders: [reminder])
        #expect(engine.latestOccurrence(for: reminder.id) == Occurrence(dueTime: lastDueTime, state: .missed(reason: .giveUpLimit)))
    }

    /// Done names the reminder, not the occurrence (ticket 07), so after take-over it closes the
    /// open one, the new one. The taken-over occurrence keeps its reason.
    @Test func doneAfterTakeOverClosesTheNewOccurrence() {
        clock.now = NewYork.local(2026, 10, 16, 9, 5)
        var engine = engine(for: pills)

        engine.markDone(pills.id)

        #expect(engine.latestOccurrence(for: pills.id) == Occurrence(dueTime: NewYork.local(2026, 10, 16), state: .done))
        #expect(engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15))?.state == .missed(reason: .nextTookOver))
    }
}
