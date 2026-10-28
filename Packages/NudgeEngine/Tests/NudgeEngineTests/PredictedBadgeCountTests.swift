import Foundation
import Testing
import NudgeEngine

/// The count each planned nudge carries (icon-badge spec, decisions 4 and 8): how many reminders
/// are Nudging at its fire time, so a notification that arrives with the app closed stamps the
/// icon with a number that is right then.
struct PredictedBadgeCountTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 16, 6))
    let scheduler = FakeScheduler()

    func engine(holding reminders: [Reminder]) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return engine
    }

    func predictedCounts(of reminder: Reminder, before time: Date? = nil) throws -> [Int] {
        try #require(scheduler.lastPlan).items
            .filter { $0.reminderID == reminder.id && $0.fireTime < (time ?? .distantFuture) }
            .map(\.predictedBadgeCount)
    }

    /// Bins is Nudging at 7:30. Rent isn't due until 9:00, so bins' nudges before then carry 1 and
    /// rent's first nudge, at its due time, counts bins as well as itself.
    @Test func aNudgeCountsOtherRemindersNudgingAtItsFireTime() throws {
        clock.now = NewYork.local(2026, 10, 16, 7, 30)
        let bins = Reminder(title: "Take the bins out", dueTime: NewYork.local(2026, 10, 16, 7), strength: .gentle)
        let rent = Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle)

        _ = engine(holding: [bins, rent])

        let nineOClock = NewYork.local(2026, 10, 16, 9)
        #expect(try predictedCounts(of: bins, before: nineOClock).allSatisfy { $0 == 1 })
        #expect(try predictedCounts(of: rent).first == 2)
    }

    /// Delivery doesn't matter (decision 2): a Relentless ladder rings as alarms, which carry no
    /// stamp themselves, but a notification after them counts them.
    @Test func aNudgeCountsRemindersWhoseNudgesRingAsAlarms() throws {
        clock.now = NewYork.local(2026, 10, 16, 8, 45)
        let call = Reminder(title: "Call the landlord", dueTime: NewYork.local(2026, 10, 16, 8, 30), strength: .relentless)
        let rent = Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle)

        _ = engine(holding: [call, rent])

        let plan = try #require(scheduler.lastPlan)
        #expect(plan.items.contains { $0.reminderID == call.id && $0.deliveryKind == .alarm })
        #expect(try predictedCounts(of: rent).first == 2)
    }

    /// Call gives up within hours, closing as Missed with no alert, so a notification after that
    /// doesn't count it (decision 10's stale icon is the app's, until this stamp corrects it).
    @Test func aNudgeDoesNotCountAReminderThatGivesUpBeforeIt() throws {
        clock.now = NewYork.local(2026, 10, 16, 7, 30)
        let call = Reminder(title: "Call the landlord", dueTime: NewYork.local(2026, 10, 16, 7), strength: .relentless)
        let rent = Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 10, 16, 20), strength: .gentle)

        let engine = engine(holding: [call, rent])

        #expect(engine.badgeCount == 1)
        #expect(try predictedCounts(of: rent).first == 1)
    }

    /// Every day at 9:00. With the limit widened, the 15th is still Nudging when the 16th falls
    /// due and is taken over, so the reminder is one Nudging reminder before and after. Bins, due
    /// after the last of Pills' planned nudges, finds Pills Nudging on its 17th occurrence.
    @Test func aTakeOverLeavesTheReminderCountedOnce() throws {
        clock.now = NewYork.local(2026, 10, 16, 8)
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), repeatRule: .everyDay, strength: .relentless)
        let bins = Reminder(title: "Take the bins out", dueTime: NewYork.local(2026, 10, 17, 12), strength: .gentle)
        var engine = Engine(
            clock: clock,
            scheduler: scheduler,
            giveUpLimit: GiveUpLimit(nudgeCount: 10_000, span: 72 * 60 * 60),
            timeZone: NewYork.timeZone
        )
        engine.update(reminders: [pills, bins])

        let takeOver = NewYork.local(2026, 10, 16)
        let items = try #require(scheduler.lastPlan).items.filter { $0.reminderID == pills.id }
        #expect(items.contains { $0.fireTime < takeOver } && items.contains { $0.fireTime >= takeOver })
        #expect(items.allSatisfy { $0.predictedBadgeCount == 1 })
        #expect(try predictedCounts(of: bins).first == 2)
    }

    @Test func aPausedReminderIsNotCounted() throws {
        clock.now = NewYork.local(2026, 10, 16, 7, 30)
        let call = Reminder(title: "Call the landlord", dueTime: NewYork.local(2026, 10, 16, 7), strength: .firm)
        let rent = Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle)
        var engine = engine(holding: [call, rent])
        #expect(try predictedCounts(of: rent).first == 2)

        engine.pause(call.id)

        #expect(try predictedCounts(of: rent).first == 1)
    }

    /// Done and Edit each hand the scheduler a plan with fresh stamps: `content.badge` is fixed,
    /// so a stamp left from before would be wrong (decision 4).
    @Test func doneRestampsThePlan() throws {
        clock.now = NewYork.local(2026, 10, 16, 7, 30)
        let call = Reminder(title: "Call the landlord", dueTime: NewYork.local(2026, 10, 16, 7), strength: .firm)
        let rent = Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle)
        var engine = engine(holding: [call, rent])
        #expect(try predictedCounts(of: rent).first == 2)

        engine.markDone(call.id)

        #expect(try predictedCounts(of: rent).first == 1)
    }

    /// Rent isn't Nudging, so its due time isn't locked. Moving it from 9:00 to 8:00 raises the
    /// stamp of Call's nudges between the two.
    @Test func editRestampsThePlan() throws {
        clock.now = NewYork.local(2026, 10, 16, 7, 30)
        let call = Reminder(title: "Call the landlord", dueTime: NewYork.local(2026, 10, 16, 7), strength: .gentle)
        var rent = Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle)
        var engine = engine(holding: [call, rent])
        let eightOClock = NewYork.local(2026, 10, 16, 8)
        let nineOClock = NewYork.local(2026, 10, 16, 9)
        func countsBetweenEightAndNine() throws -> [Int] {
            try #require(scheduler.lastPlan).items
                .filter { $0.reminderID == call.id && eightOClock <= $0.fireTime && $0.fireTime < nineOClock }
                .map(\.predictedBadgeCount)
        }
        let before = try countsBetweenEightAndNine()
        #expect(!before.isEmpty && before.allSatisfy { $0 == 1 })

        rent.dueTime = eightOClock
        try engine.edit(rent)

        let after = try countsBetweenEightAndNine()
        #expect(after.count == before.count && after.allSatisfy { $0 == 2 })
    }

    /// Every planned nudge reads every reminder, so the stamping must stay cheap for a long list: this
    /// is 100 daily reminders, in debug, with room to spare.
    @Test func stampingAHundredDailyRemindersIsQuick() {
        clock.now = NewYork.local(2026, 10, 16, 7, 30)
        let reminders = (0..<100).map { index in
            Reminder(
                title: "Reminder \(index)",
                dueTime: NewYork.local(2026, 10, 16, 6 + index % 14, index % 60),
                repeatRule: .everyDay,
                strength: index.isMultiple(of: 2) ? .gentle : .firm
            )
        }

        let elapsed = ContinuousClock().measure { _ = engine(holding: reminders) }

        #expect(elapsed < .seconds(1))
    }

    /// One reminder due far ahead puts the plan's last fire time far ahead, and every other reminder
    /// is then read up to it.
    @Test func aReminderDueNextYearDoesntSlowTheStamping() {
        clock.now = NewYork.local(2026, 10, 16, 7, 30)
        var reminders = (0..<100).map { index in
            Reminder(
                title: "Reminder \(index)",
                dueTime: NewYork.local(2026, 10, 16, 6 + index % 14, index % 60),
                repeatRule: .everyDay,
                strength: index.isMultiple(of: 2) ? .gentle : .firm
            )
        }
        reminders.append(Reminder(title: "Renew the passport", dueTime: NewYork.local(2027, 10, 16), strength: .gentle))

        let elapsed = ContinuousClock().measure { _ = engine(holding: reminders) }

        #expect(elapsed < .seconds(1))
    }
}
