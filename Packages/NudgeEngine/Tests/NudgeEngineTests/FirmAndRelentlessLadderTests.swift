import Foundation
import Testing
import NudgeEngine

/// Expected values are literals from the mockup's How It Nudges table
/// (`docs/mockups/2026-10-04-first-version/index.html`).
struct FirmAndRelentlessLadderTests {
    let dueTime = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let scheduler = FakeScheduler()

    func planItems(for strength: Strength) throws -> [SchedulePlan.Item] {
        let reminder = Reminder(title: "Take the bins out", dueTime: dueTime, strength: strength)
        var engine = Engine(clock: FakeClock(now: dueTime), scheduler: scheduler)
        engine.update(reminders: [reminder])
        return try #require(scheduler.lastPlan).items
    }

    func wait(afterNudge nudgeNumber: Int, in items: [SchedulePlan.Item]) throws -> TimeInterval {
        let this = try #require(items.first { $0.nudgeNumber == nudgeNumber })
        let next = try #require(items.first { $0.nudgeNumber == nudgeNumber + 1 })
        return next.fireTime.timeIntervalSince(this.fireTime)
    }

    /// 30 min, 15 min, 7.5 min (exactly 450 s, so rounding to the second changes nothing), then
    /// the 5 min floor.
    @Test(arguments: [
        (1, 1800),
        (2, 900),
        (3, 450),
        (4, 300),
        (19, 300),
    ])
    func firmWaitHalvesToFiveMinuteFloor(afterNudge nudgeNumber: Int, seconds: Int) throws {
        let items = try planItems(for: .firm)
        #expect(try wait(afterNudge: nudgeNumber, in: items) == TimeInterval(seconds))
    }

    /// 10 min, 5 min, 2.5 min (exactly 150 s), then the 2 min floor.
    @Test(arguments: [
        (1, 600),
        (2, 300),
        (3, 150),
        (4, 120),
        (19, 120),
    ])
    func relentlessWaitHalvesToTwoMinuteFloor(afterNudge nudgeNumber: Int, seconds: Int) throws {
        let items = try planItems(for: .relentless)
        #expect(try wait(afterNudge: nudgeNumber, in: items) == TimeInterval(seconds))
    }

    /// The table's Firm rows: nudges 1 and 2 Normal, nudge 3 High, nudges 4–20 Urgent.
    @Test(arguments: [
        (1, Urgency.normal, "Nudge 1 of 20 · Normal"),
        (2, .normal, "Nudge 2 of 20 · Normal"),
        (3, .high, "Nudge 3 of 20 · High"),
        (4, .urgent, "Nudge 4 of 20 · Urgent"),
        (5, .urgent, "Nudge 5 of 20 · Urgent"),
        (20, .urgent, "Nudge 20 of 20 · Urgent"),
    ])
    func firmNudgeCarriesUrgencyFromItsLadder(nudgeNumber: Int, urgency: Urgency, body: String) throws {
        let item = try #require(try planItems(for: .firm).first { $0.nudgeNumber == nudgeNumber })
        #expect(item.urgency == urgency)
        #expect(item.body == body)
    }

    /// The table's Relentless rows: nudges 1–3 High (it starts above Normal), nudges 4–20 Urgent.
    @Test(arguments: [
        (1, Urgency.high, "Nudge 1 of 20 · High"),
        (2, .high, "Nudge 2 of 20 · High"),
        (3, .high, "Nudge 3 of 20 · High"),
        (4, .urgent, "Nudge 4 of 20 · Urgent"),
        (5, .urgent, "Nudge 5 of 20 · Urgent"),
        (20, .urgent, "Nudge 20 of 20 · Urgent"),
    ])
    func relentlessNudgeCarriesUrgencyFromItsLadder(nudgeNumber: Int, urgency: Urgency, body: String) throws {
        let item = try #require(try planItems(for: .relentless).first { $0.nudgeNumber == nudgeNumber })
        #expect(item.urgency == urgency)
        #expect(item.body == body)
    }

    /// With Break through Focus on (the only mapping until ticket 05), Firm and Relentless ring
    /// as alarms from nudge 4.
    @Test(arguments: [
        (Strength.firm, 1, DeliveryKind.notification),
        (.firm, 3, .timeSensitiveNotification),
        (.firm, 4, .alarm),
        (.firm, 20, .alarm),
        (.relentless, 1, .timeSensitiveNotification),
        (.relentless, 3, .timeSensitiveNotification),
        (.relentless, 4, .alarm),
        (.relentless, 20, .alarm),
    ])
    func nudgeRingsAsAlarmFromNudgeFour(strength: Strength, nudgeNumber: Int, kind: DeliveryKind) throws {
        let item = try #require(try planItems(for: strength).first { $0.nudgeNumber == nudgeNumber })
        #expect(item.deliveryKind == kind)
    }
}
