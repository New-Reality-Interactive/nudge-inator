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

    func engine(permissions: PermissionStates, holding reminders: [Reminder] = []) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: permissions)
        if !reminders.isEmpty { engine.update(reminders: reminders) }
        return engine
    }

    func reminder(_ strength: Strength, breakThroughFocus: Bool = true) -> Reminder {
        Reminder(title: "Take the bins out", dueTime: dueTime, strength: strength, breakThroughFocus: breakThroughFocus)
    }

    func planItems(for strength: Strength, permissions: PermissionStates) throws -> [SchedulePlan.Item] {
        _ = engine(permissions: permissions, holding: [reminder(strength)])
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
        let items = try planItems(for: strength, permissions: PermissionStates(timeSensitive: .off))
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
        #expect(engine(permissions: permissions).reach == Reach(normal: nil, high: nil, urgent: .alarm))
    }

    static let everythingDenied = PermissionStates(notifications: .denied, alarms: .denied, timeSensitive: .off)

    @Test(arguments: [Strength.gentle, .firm, .relentless])
    func everythingDeniedPlansNothing(strength: Strength) throws {
        #expect(try planItems(for: strength, permissions: Self.everythingDenied).isEmpty)
    }

    /// The notifications banner's "Nudges can't reach you".
    @Test func everythingDeniedReachSaysNothingCanReachYou() {
        #expect(engine(permissions: Self.everythingDenied).reach == Reach(normal: nil, high: nil, urgent: nil))
    }

    /// The ladder moves on whether or not a nudge can be delivered, so the occurrence still counts
    /// its nudges and reaches its give-up limit on time; the banner says why nothing arrives.
    @Test func nudgesThatCantBeDeliveredStillCountAlongTheLadder() {
        let bins = reminder(.relentless)
        let engine = engine(permissions: Self.everythingDenied, holding: [bins])
        clock.now = NewYork.local(2026, 10, 16, 9, 20)
        #expect(engine.latestOccurrence(for: bins.id)?.state == .nudging(nudgeNumber: 5))
    }

    /// Each of the mockup's `permBanner` cases, from what reaches the person.
    @Test(arguments: [
        // No banner. Not determined plans as allowed: the alarm prompt may not have been shown.
        (PermissionStates(alarms: .allowed), Reach(normal: .notification, high: .timeSensitiveNotification, urgent: .alarm)),
        (PermissionStates(alarms: .notDetermined), Reach(normal: .notification, high: .timeSensitiveNotification, urgent: .alarm)),
        // Alarms off: "a chain of Time Sensitive notifications instead".
        (PermissionStates(alarms: .denied), Reach(normal: .notification, high: .timeSensitiveNotification, urgent: .timeSensitiveNotification)),
        // Alarms and Time Sensitive off: "a chain of ordinary notifications instead".
        (PermissionStates(alarms: .denied, timeSensitive: .off), Reach(normal: .notification, high: .notification, urgent: .notification)),
        // Time Sensitive off: "High nudges come as ordinary notifications".
        (PermissionStates(alarms: .allowed, timeSensitive: .off), Reach(normal: .notification, high: .notification, urgent: .alarm)),
    ])
    func reachFollowsThePermissions(permissions: PermissionStates, reach: Reach) {
        #expect(engine(permissions: permissions).reach == reach)
    }

    /// Relentless nudges at 9:00, 9:10, 9:15, 9:17:30 and 9:19:30, so by 9:20 nudges 4 and 5 have
    /// already rung as alarms. They stay alarms; nudges 6–20 become Time Sensitive. A nudge firing
    /// exactly at the change (9:19:30) counts as delivered, as with an Edit's title.
    @Test(arguments: [NewYork.local(2026, 10, 16, 9, 20), NewYork.local(2026, 10, 16, 9, 19) + 30])
    func denyingAlarmsMidOccurrenceChangesOnlyNudgesNotYetDelivered(changedAt: Date) throws {
        var engine = engine(permissions: PermissionStates(alarms: .allowed), holding: [reminder(.relentless)])

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
        let denied = PermissionStates(notifications: .denied, alarms: .allowed)
        var engine = engine(permissions: denied, holding: [reminder(.relentless)])

        clock.now = NewYork.local(2026, 10, 16, 9, 16)
        engine.update(permissions: PermissionStates(alarms: .allowed))

        let items = try #require(scheduler.lastPlan).items
        #expect(items.map(\.nudgeNumber) == Array(4...20))
    }

    /// Alarms denied at 9:18 and allowed again at 9:20. Nudge 4 (9:17:30) rang before either
    /// change, so it keeps the first states; nudge 5 (9:19:30) came as a Time Sensitive
    /// notification in between; nudges 6–20 ring again.
    @Test func allowingAlarmsAgainRestoresAlarmsForNudgesNotYetDelivered() throws {
        var engine = engine(permissions: PermissionStates(alarms: .allowed), holding: [reminder(.relentless)])

        clock.now = NewYork.local(2026, 10, 16, 9, 18)
        engine.update(permissions: PermissionStates(alarms: .denied))
        clock.now = NewYork.local(2026, 10, 16, 9, 20)
        engine.update(permissions: PermissionStates(alarms: .allowed))

        let items = try #require(scheduler.lastPlan).items
        #expect(items.map(\.deliveryKind) == [DeliveryKind](repeating: .timeSensitiveNotification, count: 3)
            + [.alarm, .timeSensitiveNotification]
            + [DeliveryKind](repeating: .alarm, count: 15))
    }

    /// The adapter may report the same states on every foreground; with nothing to act on, the
    /// engine applies no plan.
    @Test func reportingUnchangedPermissionsAppliesNoPlan() {
        var engine = engine(permissions: PermissionStates(alarms: .denied), holding: [reminder(.firm)])

        engine.update(permissions: PermissionStates(alarms: .denied))

        #expect(scheduler.appliedPlans.count == 1)
    }

    /// The fallback rule applies only with the switch on. Off, every nudge is an ordinary
    /// notification, never an alarm, so with notifications denied nothing is left.
    @Test(arguments: [
        (PermissionStates(alarms: .allowed), [DeliveryKind](repeating: .notification, count: 20)),
        (PermissionStates(alarms: .denied, timeSensitive: .off), [DeliveryKind](repeating: .notification, count: 20)),
        (PermissionStates(notifications: .denied, alarms: .allowed), []),
    ])
    func switchOffSendsOrdinaryNotificationsWhateverThePermissions(permissions: PermissionStates, kinds: [DeliveryKind]) throws {
        _ = engine(permissions: permissions, holding: [reminder(.relentless, breakThroughFocus: false)])
        #expect(try #require(scheduler.lastPlan).items.map(\.deliveryKind) == kinds)
    }
}
