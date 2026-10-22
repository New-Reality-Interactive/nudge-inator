import Foundation
import Testing
@testable import NudgeEngine

/// A Consistent pace nudges once at the due time and once every wait after (enhancement-pace
/// ticket 07). Expected values are worked out by hand: a wait of w seconds puts nudge n at
/// (n − 1) × w, up to 20 nudges or 24 h.
struct ConsistentPaceTests {
    let dueTime = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let scheduler = FakeScheduler()

    func planItems(strength: Strength, wait: TimeInterval) throws -> [SchedulePlan.Item] {
        let reminder = Reminder(title: "Take the bins out", dueTime: dueTime, strength: strength, pace: .consistent(wait: wait))
        var engine = Engine(clock: FakeClock(now: dueTime), scheduler: scheduler)
        engine.update(reminders: [reminder])
        return try #require(scheduler.lastPlan).items
    }

    /// 2, 5, 10, 15 and 30 min, then 1, 2, 4, 8, 12 and 16 h, in seconds.
    @Test func thereAreElevenWaitsInOneList() {
        #expect(Pace.consistentWaits == [120, 300, 600, 900, 1800, 3600, 7200, 14400, 28800, 43200, 57600])
    }

    /// 15 min: nudge 1 at the due time, then one wait apart: 0, 900, 1800, 2700, 3600, and
    /// nudge 20 at 19 × 900 = 17,100 s.
    @Test(arguments: [Strength.gentle, .firm, .relentless])
    func theFirstNudgeIsAtTheDueTimeAndEachLaterOneExactlyOneWaitAfter(strength: Strength) throws {
        let items = try planItems(strength: strength, wait: 900)
        #expect(items.count == 20)
        #expect(items.prefix(5).map { $0.fireTime.timeIntervalSince(dueTime) } == [0, 900, 1800, 2700, 3600])
        #expect(items.last?.fireTime.timeIntervalSince(dueTime) == 17_100)
    }

    /// The strength still decides how each nudge arrives (spec stories 13 and 14): Gentle turns
    /// High at nudge 5 and never rings; Firm is Normal, Normal, High, then Urgent alarms from
    /// nudge 4; Relentless is Urgent alarms throughout.
    @Test(arguments: [
        (Strength.gentle, 4, Urgency.normal, DeliveryKind.notification),
        (.gentle, 5, .high, .timeSensitiveNotification),
        (.gentle, 20, .high, .timeSensitiveNotification),
        (.firm, 2, .normal, .notification),
        (.firm, 3, .high, .timeSensitiveNotification),
        (.firm, 4, .urgent, .alarm),
        (.firm, 20, .urgent, .alarm),
        (.relentless, 1, .urgent, .alarm),
        (.relentless, 20, .urgent, .alarm),
    ])
    func eachStrengthKeepsItsUrgencyStepsAtAnyWait(strength: Strength, nudgeNumber: Int, urgency: Urgency, kind: DeliveryKind) throws {
        let item = try #require(try planItems(strength: strength, wait: 600).first { $0.nudgeNumber == nudgeNumber })
        #expect(item.urgency == urgency)
        #expect(item.deliveryKind == kind)
    }

    /// The give-up limit is 20 nudges or 24 h after the due time, and the last nudge leaves one
    /// full wait before Missed unless the 24 h run out first. Worked by hand, with the seconds
    /// after the due time that the occurrence gives up:
    /// - 2 min: nudge 20 at 19 × 120 = 2280, one wait more is 2400 (40 min).
    /// - 1 h: nudge 20 at 19 h, gives up at 20 h.
    /// - 4 h: nudges at 0 … 20 h are six, the seventh would be at 24 h, which is not before it;
    ///   the wait after the sixth would end at 24 h exactly.
    /// - 12 h: two nudges (0 and 12 h), the third would be at 24 h; gives up at 24 h.
    /// - 16 h: two nudges (0 and 16 h); a full wait after the second is 32 h, so 24 h cuts it.
    @Test(arguments: [
        (120.0, 20, 2400.0),
        (3600, 20, 72_000),
        (14_400, 6, 86_400),
        (43_200, 2, 86_400),
        (57_600, 2, 86_400),
    ])
    func countOrSpanLimitsTheNudgesAndTheLastOneLeavesAFullWaitUnlessTheDayRunsOut(
        wait: TimeInterval, nudgeCount: Int, givesUpAfter: TimeInterval
    ) throws {
        let reminder = Reminder(title: "Take the bins out", dueTime: dueTime, strength: .firm, pace: .consistent(wait: wait))
        let clock = FakeClock(now: dueTime)
        var engine = Engine(clock: clock, scheduler: scheduler)
        engine.update(reminders: [reminder])
        #expect(try #require(scheduler.lastPlan).items.count == nudgeCount)

        clock.now = dueTime + givesUpAfter - 1
        engine.update(reminders: [reminder])
        #expect(engine.latestOccurrence(for: reminder.id)?.state == .nudging(nudgeNumber: nudgeCount))

        clock.now = dueTime + givesUpAfter
        engine.update(reminders: [reminder])
        #expect(engine.latestOccurrence(for: reminder.id)?.state == .missed(reason: .giveUpLimit))
    }
}

/// Stop, Done, a repeat's take-over and Pause and Resume mean the same for a Consistent reminder
/// as for an Escalating one (spec stories 18–21). Prior art: `StopAndDoneTests`,
/// `RepeatTakeOverTests` and `PauseAndResumeTests`.
struct ConsistentPaceLifecycleTests {
    let clock = FakeClock(now: .distantPast)
    let scheduler = FakeScheduler()
    /// Every day at 9:00 from Thursday 15 October 2026, nudging every 12 h.
    let pills = Reminder(
        title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), repeatRule: .everyDay,
        strength: .firm, pace: .consistent(wait: 12 * 60 * 60)
    )

    func engine(for reminder: Reminder, giveUpLimit: GiveUpLimit = .shipped) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, giveUpLimit: giveUpLimit, timeZone: NewYork.timeZone)
        engine.update(reminders: [reminder])
        return engine
    }

    /// Stop never reaches the engine (see `StopAndDoneTests`): the ring is silenced and the chain
    /// carries on. Nudge 4 (alarm) has rung and been stopped with no Done; nudge 5 is still
    /// planned one wait later.
    @Test func stopLeavesTheNextNudgeOneWaitLater() throws {
        let call = Reminder(
            title: "Call the bank", dueTime: NewYork.local(2026, 10, 15), strength: .firm, pace: .consistent(wait: 15 * 60)
        )
        clock.now = NewYork.local(2026, 10, 15, 9, 45)
        let engine = engine(for: call)

        #expect(engine.latestOccurrence(for: call.id)?.state == .nudging(nudgeNumber: 4))
        let pending = try #require(scheduler.lastPlan).items.filter { $0.fireTime > clock.now }
        #expect(pending.first?.nudgeNumber == 5)
        #expect(pending.first?.fireTime == NewYork.local(2026, 10, 15, 10))
    }

    @Test func doneClosesTheOccurrenceAndEmptiesItsPlan() throws {
        clock.now = NewYork.local(2026, 10, 15, 21)
        var engine = engine(for: pills)

        engine.markDone(pills.id)

        #expect(engine.latestOccurrence(for: pills.id)?.state == .done)
        #expect(engine.openOccurrence(for: pills.id) == nil)
    }

    /// Nudges at 9:00 and 21:00 on the 15th, then the next occurrence falls due at 9:00 on the
    /// 16th. With the shipped limit the old one would give up at that very instant, so the limit
    /// is widened to 72 h to leave it still Nudging just before: nudge 2 at 21:00. At 9:00 the
    /// old one closes as Missed and the new one starts at nudge 1.
    @Test func aRepeatTakesOverAConsistentOccurrenceStillNudging() throws {
        let widened = GiveUpLimit(nudgeCount: 10_000, span: 72 * 60 * 60)
        clock.now = NewYork.local(2026, 10, 16) - 1
        #expect(engine(for: pills, giveUpLimit: widened).openOccurrence(for: pills.id)
            == Occurrence(dueTime: NewYork.local(2026, 10, 15), state: .nudging(nudgeNumber: 2)))

        clock.now = NewYork.local(2026, 10, 16)
        let engine = engine(for: pills, giveUpLimit: widened)

        #expect(engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15))?.state == .missed(reason: .nextTookOver))
        #expect(engine.openOccurrence(for: pills.id) == Occurrence(dueTime: NewYork.local(2026, 10, 16), state: .nudging(nudgeNumber: 1)))
        let items = try #require(scheduler.lastPlan).items
        #expect(items.allSatisfy { $0.fireTime >= NewYork.local(2026, 10, 16) })
        #expect(items.filter { $0.dueTime == NewYork.local(2026, 10, 16) }.prefix(2).map(\.fireTime) == [
            NewYork.local(2026, 10, 16), NewYork.local(2026, 10, 16, 21),
        ])
    }

    /// Paused at 21:00, nudge 2: the occurrence is Skipped and the plan is empty. Resumed at 9:30
    /// on the 17th, it plans nudge 1 at 9:00 on the 18th and nudge 2 one wait later.
    @Test func pauseSkipsTheOccurrenceAndResumePlansTheNextFutureOne() throws {
        clock.now = NewYork.local(2026, 10, 15, 21)
        var engine = engine(for: pills)

        engine.pause(pills.id)

        #expect(engine.latestOccurrence(for: pills.id)?.state == .skipped(reason: .paused))
        #expect(try #require(scheduler.lastPlan).items.isEmpty)

        clock.now = NewYork.local(2026, 10, 17, 9, 30)
        try engine.resume(pills.id)

        let plan = try #require(scheduler.lastPlan)
        let firstTwo = plan.items.sorted { $0.fireTime < $1.fireTime }.prefix(2)
        #expect(firstTwo.map(\.nudgeNumber) == [1, 2])
        #expect(firstTwo.map(\.fireTime) == [NewYork.local(2026, 10, 18), NewYork.local(2026, 10, 18, 21)])
    }
}
