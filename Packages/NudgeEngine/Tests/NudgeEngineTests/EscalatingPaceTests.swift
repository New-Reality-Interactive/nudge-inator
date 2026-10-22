import Foundation
import Testing
import NudgeEngine

/// A reminder's pace and strength together decide its nudge times (enhancement-pace ticket 04).
/// Only Escalating exists so far, so each strength nudges as it always has. Expected values are
/// worked out by hand from the waits: Gentle 60, 45, 33.75 and 25.3 min (1519 s), then the 20 min
/// floor; Firm 30, 15, 7.5 min, then 5; Relentless 10, 5, 2.5 min, then 2.
struct EscalatingPaceTests {
    let dueTime = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let scheduler = FakeScheduler()

    func planItems(for strength: Strength) throws -> [SchedulePlan.Item] {
        let reminder = Reminder(title: "Take the bins out", dueTime: dueTime, strength: strength, pace: .escalating)
        var engine = Engine(clock: FakeClock(now: dueTime), scheduler: scheduler)
        engine.update(reminders: [reminder])
        return try #require(scheduler.lastPlan).items
    }

    /// Seconds after the due time of nudges 1–5 and of nudge 20.
    @Test(arguments: [
        (Strength.gentle, [0.0, 3600, 6300, 8325, 9844], 27844.0),
        (.firm, [0, 1800, 2700, 3150, 3450], 7950),
        (.relentless, [0, 600, 900, 1050, 1170], 2970),
    ])
    func eachStrengthPlansItsOwnNudgeTimes(strength: Strength, firstFive: [TimeInterval], twentieth: TimeInterval) throws {
        let items = try planItems(for: strength)
        #expect(items.count == 20)
        #expect(items.prefix(5).map { $0.fireTime.timeIntervalSince(dueTime) } == firstFive)
        #expect(items.last?.fireTime.timeIntervalSince(dueTime) == twentieth)
    }

    /// The read-out takes the pace: Escalating's rows are the ones a strength always had, and
    /// naming the pace changes nothing. Firm's, from the table: 30, 15 and 7.5 min, then 5.
    @Test func howItNudgesTakesThePace() {
        let engine = Engine(clock: FakeClock(now: dueTime), scheduler: scheduler, permissions: PermissionStates(alarms: .allowed))
        let howItNudges = engine.howItNudges(.firm, pace: .escalating, breakThroughFocus: true)
        #expect(howItNudges == engine.howItNudges(.firm, breakThroughFocus: true))
        #expect(howItNudges.rows.map(\.wait) == [1800, 900, 450, 300])
        #expect(howItNudges.givesUpAfter == 8250)
    }

    /// A reminder that doesn't say its pace is Escalating.
    @Test func aReminderStartsEscalating() {
        #expect(Reminder(title: "Stretch", dueTime: dueTime, strength: .firm).pace == .escalating)
    }
}
