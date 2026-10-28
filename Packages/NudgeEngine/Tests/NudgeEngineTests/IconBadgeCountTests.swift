import Foundation
import Testing
import NudgeEngine

/// The plan's current count, which the app puts on the icon badge (icon-badge spec, decisions 1,
/// 2 and 8): how many reminders are Nudging, the same count as the Now badge. Stop on an alarm
/// isn't an engine event, so it can't lower the count (decision 3, ADR 0001).
struct IconBadgeCountTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 16, 6))
    let scheduler = FakeScheduler()

    func engine(permissions: PermissionStates = PermissionStates(), holding reminders: [Reminder]) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: permissions)
        engine.update(reminders: reminders)
        return engine
    }

    /// Two reminders due at 7:00 and one at 9:00, planned at 7:30. Delivery doesn't matter:
    /// notification, alarm, and the Fallbacks when alarms or Time Sensitive are denied.
    @Test(arguments: [
        (Strength.gentle, PermissionStates(), DeliveryKind.notification),
        (.relentless, PermissionStates(), .alarm),
        (.relentless, PermissionStates(alarms: .denied), .timeSensitiveNotification),
        (.relentless, PermissionStates(alarms: .denied, timeSensitive: .off), .notification),
    ])
    func planCountsNudgingRemindersWhateverTheirDelivery(strength: Strength, permissions: PermissionStates, kind: DeliveryKind) throws {
        clock.now = NewYork.local(2026, 10, 16, 7, 30)
        let bins = Reminder(title: "Take the bins out", dueTime: NewYork.local(2026, 10, 16, 7), strength: strength)
        let alex = Reminder(title: "Reply to Alex", dueTime: NewYork.local(2026, 10, 16, 7), strength: strength)
        let rent = Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 10, 16, 9), strength: strength)

        let engine = engine(permissions: permissions, holding: [bins, alex, rent])

        let plan = try #require(scheduler.lastPlan)
        #expect(plan.items.first { $0.reminderID == bins.id }?.deliveryKind == kind)
        #expect(plan.currentBadgeCount == 2)
        #expect(engine.badgeCount == 2)
    }

    /// Pause closes the occurrence as Skipped, so the plan Pause hands over counts one fewer, and
    /// Done's does too.
    @Test func pauseAndDoneEachLowerThePlansCount() throws {
        clock.now = NewYork.local(2026, 10, 16, 7, 30)
        let bins = Reminder(title: "Take the bins out", dueTime: NewYork.local(2026, 10, 16, 7), strength: .firm)
        let alex = Reminder(title: "Reply to Alex", dueTime: NewYork.local(2026, 10, 16, 7, 10), strength: .relentless)
        var engine = engine(holding: [bins, alex])

        engine.pause(bins.id)
        #expect(try #require(scheduler.lastPlan).currentBadgeCount == 1)

        engine.markDone(alex.id)
        #expect(try #require(scheduler.lastPlan).currentBadgeCount == 0)
    }
}
