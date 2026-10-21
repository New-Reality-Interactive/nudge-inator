import Foundation
import Testing
import NudgeEngine

/// The spec's Delivery by urgency rule. On: Normal is an ordinary notification, High is Time
/// Sensitive and Urgent is an alarm. Off: every nudge is an ordinary notification.
struct BreakThroughFocusTests {
    let dueTime = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let scheduler = FakeScheduler()

    func planItems(for strength: Strength, breakThroughFocus: Bool) throws -> [SchedulePlan.Item] {
        let reminder = Reminder(
            title: "Take the bins out",
            dueTime: dueTime,
            strength: strength,
            breakThroughFocus: breakThroughFocus
        )
        var engine = Engine(clock: FakeClock(now: dueTime), scheduler: scheduler)
        engine.update(reminders: [reminder])
        return try #require(scheduler.lastPlan).items
    }

    /// Nudges 1–20 in order, from the How It Nudges table's urgency rows. Relentless starts at
    /// High, so it has no ordinary notifications; Gentle never reaches Urgent, so it never rings.
    /// Typed and out of the macro: Swift 6.4 can't type-check this literal inline in `@Test`.
    static let deliveryKindsByStrength: [(Strength, [DeliveryKind])] = [
        (.gentle, [DeliveryKind](repeating: .notification, count: 4)
            + [DeliveryKind](repeating: .timeSensitiveNotification, count: 16)),
        (.firm, [DeliveryKind](repeating: .notification, count: 2)
            + [DeliveryKind.timeSensitiveNotification]
            + [DeliveryKind](repeating: .alarm, count: 17)),
        (.relentless, [DeliveryKind](repeating: .timeSensitiveNotification, count: 3)
            + [DeliveryKind](repeating: .alarm, count: 17)),
    ]

    @Test(arguments: deliveryKindsByStrength)
    func switchOnDeliversEachNudgeByItsUrgency(strength: Strength, kinds: [DeliveryKind]) throws {
        let items = try planItems(for: strength, breakThroughFocus: true)
        #expect(items.map(\.deliveryKind) == kinds)
    }

    @Test func switchIsOnByDefault() throws {
        let reminder = Reminder(title: "Take the bins out", dueTime: dueTime, strength: .firm)
        #expect(reminder.breakThroughFocus)
    }

    @Test(arguments: [Strength.gentle, .firm, .relentless])
    func switchOffSendsEveryNudgeAsOrdinaryNotification(strength: Strength) throws {
        let items = try planItems(for: strength, breakThroughFocus: false)
        #expect(items.count == 20)
        #expect(items.allSatisfy { $0.deliveryKind == .notification })
    }

    /// Off keeps the ladder: same nudges, times, urgency and text ("Nudge 4 of 20 · Urgent").
    @Test(arguments: [Strength.gentle, .firm, .relentless])
    func flippingSwitchChangesOnlyDeliveryKinds(strength: Strength) throws {
        let on = try planItems(for: strength, breakThroughFocus: true)
        let off = try planItems(for: strength, breakThroughFocus: false)
        #expect(off.count == on.count)
        #expect(off.map(\.nudgeNumber) == on.map(\.nudgeNumber))
        #expect(off.map(\.fireTime) == on.map(\.fireTime))
        #expect(off.map(\.urgency) == on.map(\.urgency))
        #expect(off.map(\.body) == on.map(\.body))
        #expect(off.map(\.title) == on.map(\.title))
    }
}
