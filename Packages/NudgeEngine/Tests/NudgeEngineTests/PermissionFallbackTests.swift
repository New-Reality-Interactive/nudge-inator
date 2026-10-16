import Foundation
import Testing
import NudgeEngine

/// The weaker fallbacks when the person denies a permission (spec stories 52 and 54, and the
/// mockup's "Weaker fallbacks"). Alarms denied: Urgent nudges are Time Sensitive notifications.
/// Time Sensitive off: High nudges are ordinary. Notifications denied: only alarms can still plan.
struct PermissionFallbackTests {
    let dueTime = NewYork.local(2026, 10, 16)
    let clock = FakeClock(now: NewYork.local(2026, 10, 16))
    let scheduler = FakeScheduler()

    func planItems(for strength: Strength, permissions: PermissionStates) throws -> [SchedulePlan.Item] {
        let reminder = Reminder(title: "Take the bins out", dueTime: dueTime, strength: strength)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: permissions)
        engine.update(reminders: [reminder])
        return try #require(scheduler.lastPlan).items
    }

    @Test func alarmsDeniedSendsUrgentNudgesAsTimeSensitiveNotifications() throws {
        let items = try planItems(for: .relentless, permissions: PermissionStates(alarms: .denied))
        #expect(items.count == 20)
        #expect(items.allSatisfy { $0.deliveryKind == .timeSensitiveNotification })
    }

    /// Nudges 1–20 with the switch on. Urgent still rings: only High weakens.
    @Test(arguments: [
        (Strength.gentle, [DeliveryKind](repeating: .notification, count: 20)),
        (.firm, [DeliveryKind](repeating: .notification, count: 3) + [DeliveryKind](repeating: .alarm, count: 17)),
        (.relentless, [DeliveryKind](repeating: .notification, count: 3) + [DeliveryKind](repeating: .alarm, count: 17)),
    ])
    func timeSensitiveOffSendsHighNudgesAsOrdinaryNotifications(strength: Strength, kinds: [DeliveryKind]) throws {
        let items = try planItems(for: strength, permissions: PermissionStates(timeSensitive: false))
        #expect(items.map(\.deliveryKind) == kinds)
    }

    /// Only Urgent nudges ring, so Gentle, which never reaches Urgent, has nothing left.
    @Test(arguments: [
        (Strength.gentle, [Int]()),
        (.firm, Array(4...20)),
        (.relentless, Array(4...20)),
    ])
    func notificationsDeniedLeavesOnlyAlarms(strength: Strength, nudgeNumbers: [Int]) throws {
        let permissions = PermissionStates(notifications: .denied, alarms: .allowed)
        let items = try planItems(for: strength, permissions: permissions)
        #expect(items.map(\.nudgeNumber) == nudgeNumbers)
        #expect(items.allSatisfy { $0.deliveryKind == .alarm })
    }

    /// The notifications banner's "Only Urgent nudges can reach you, as alarms".
    @Test func notificationsDeniedReachSaysOnlyUrgentNudgesRingAsAlarms() {
        let permissions = PermissionStates(notifications: .denied, alarms: .allowed)
        let engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: permissions)
        #expect(engine.reach == Reach(normal: nil, high: nil, urgent: .alarm))
    }

    /// The notifications banner's "Nudges can't reach you".
    @Test(arguments: [Strength.gentle, .firm, .relentless])
    func everythingDeniedPlansNothingAndReachSaysNothingCanReachYou(strength: Strength) throws {
        let permissions = PermissionStates(notifications: .denied, alarms: .denied, timeSensitive: false)
        let items = try planItems(for: strength, permissions: permissions)
        #expect(items.isEmpty)
        let engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: permissions)
        #expect(engine.reach == Reach(normal: nil, high: nil, urgent: nil))
    }

    /// Each of the mockup's `permBanner` cases, from what reaches the person.
    @Test(arguments: [
        // No banner. Not determined plans as allowed: the alarm prompt may not have been shown.
        (PermissionStates(alarms: .allowed), Reach(normal: .notification, high: .timeSensitiveNotification, urgent: .alarm)),
        (PermissionStates(alarms: .notDetermined), Reach(normal: .notification, high: .timeSensitiveNotification, urgent: .alarm)),
        // Alarms off: "a chain of Time Sensitive notifications instead".
        (PermissionStates(alarms: .denied), Reach(normal: .notification, high: .timeSensitiveNotification, urgent: .timeSensitiveNotification)),
        // Alarms and Time Sensitive off: "a chain of ordinary notifications instead".
        (PermissionStates(alarms: .denied, timeSensitive: false), Reach(normal: .notification, high: .notification, urgent: .notification)),
        // Time Sensitive off: "High nudges come as ordinary notifications".
        (PermissionStates(alarms: .allowed, timeSensitive: false), Reach(normal: .notification, high: .notification, urgent: .alarm)),
    ])
    func reachFollowsThePermissions(permissions: PermissionStates, reach: Reach) {
        let engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: permissions)
        #expect(engine.reach == reach)
    }

    /// Relentless nudges at 9:00, 9:10, 9:15, 9:17:30 and 9:19:30, so by 9:20 nudges 4 and 5 have
    /// already rung as alarms. They stay alarms; nudges 6–20 become Time Sensitive. A nudge firing
    /// exactly at the change (9:19:30) counts as delivered, as with an Edit's title.
    @Test(arguments: [NewYork.local(2026, 10, 16, 9, 20), NewYork.local(2026, 10, 16, 9, 19) + 30])
    func denyingAlarmsMidOccurrenceChangesOnlyNudgesNotYetDelivered(changedAt: Date) throws {
        let reminder = Reminder(title: "Take the bins out", dueTime: dueTime, strength: .relentless)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: PermissionStates(alarms: .allowed))
        engine.update(reminders: [reminder])

        clock.now = changedAt
        engine.update(permissions: PermissionStates(alarms: .denied))

        let items = try #require(scheduler.lastPlan).items
        #expect(items.map(\.deliveryKind) == [DeliveryKind](repeating: .timeSensitiveNotification, count: 3)
            + [.alarm, .alarm]
            + [DeliveryKind](repeating: .timeSensitiveNotification, count: 15))
    }

    /// Relentless's nudges 1–3 (9:00, 9:10, 9:15) fired while notifications were denied, so they
    /// reached no one. Allowing notifications at 9:16 doesn't bring them back.
    @Test func nudgesThatPassedWhileNotificationsWereDeniedStayOutOfThePlan() throws {
        let reminder = Reminder(title: "Take the bins out", dueTime: dueTime, strength: .relentless)
        let denied = PermissionStates(notifications: .denied, alarms: .allowed)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: denied)
        engine.update(reminders: [reminder])

        clock.now = NewYork.local(2026, 10, 16, 9, 16)
        engine.update(permissions: PermissionStates(alarms: .allowed))

        let items = try #require(scheduler.lastPlan).items
        #expect(items.map(\.nudgeNumber) == Array(4...20))
    }

    /// Alarms denied at 9:16 and allowed again at 9:20: nudges 4 and 5 (9:17:30, 9:19:30) came
    /// as Time Sensitive notifications in between, and nudges 6–20 ring again.
    @Test func allowingAlarmsAgainRestoresAlarmsForNudgesNotYetDelivered() throws {
        let reminder = Reminder(title: "Take the bins out", dueTime: dueTime, strength: .relentless)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: PermissionStates(alarms: .allowed))
        engine.update(reminders: [reminder])

        clock.now = NewYork.local(2026, 10, 16, 9, 16)
        engine.update(permissions: PermissionStates(alarms: .denied))
        clock.now = NewYork.local(2026, 10, 16, 9, 20)
        engine.update(permissions: PermissionStates(alarms: .allowed))

        let items = try #require(scheduler.lastPlan).items
        #expect(items.map(\.deliveryKind) == [DeliveryKind](repeating: .timeSensitiveNotification, count: 5)
            + [DeliveryKind](repeating: .alarm, count: 15))
    }

    /// The adapter may report the same states on every foreground; with nothing to act on, the
    /// engine applies no plan.
    @Test func reportingUnchangedPermissionsAppliesNoPlan() {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: PermissionStates(alarms: .denied))
        engine.update(reminders: [Reminder(title: "Take the bins out", dueTime: dueTime, strength: .firm)])

        engine.update(permissions: PermissionStates(alarms: .denied))

        #expect(scheduler.appliedPlans.count == 1)
    }

    /// The fallback rule applies only with the switch on. Off, every nudge is an ordinary
    /// notification, never an alarm, so with notifications denied nothing is left.
    @Test(arguments: [
        (PermissionStates(alarms: .allowed), [DeliveryKind](repeating: .notification, count: 20)),
        (PermissionStates(alarms: .denied, timeSensitive: false), [DeliveryKind](repeating: .notification, count: 20)),
        (PermissionStates(notifications: .denied, alarms: .allowed), []),
    ])
    func switchOffSendsOrdinaryNotificationsWhateverThePermissions(permissions: PermissionStates, kinds: [DeliveryKind]) throws {
        let reminder = Reminder(title: "Take the bins out", dueTime: dueTime, strength: .relentless, breakThroughFocus: false)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: permissions)
        engine.update(reminders: [reminder])
        #expect(try #require(scheduler.lastPlan).items.map(\.deliveryKind) == kinds)
    }
}
