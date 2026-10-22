import Foundation
import Testing
@testable import NudgeEngine

/// The fallback for the alarm limit (spec story 53). An Urgent nudge whose alarm fails with
/// `maximumLimitReached`, or falls past the engine's own cap, comes as a Time Sensitive
/// notification instead, marked so the screens can say "Notification: too many alarms
/// scheduled", and the rest of the ladder stays.
struct AlarmLimitFallbackTests {
    let dueTime = NewYork.local(2026, 10, 16)
    let clock = FakeClock(now: NewYork.local(2026, 10, 16))
    /// Room for 10 alarms. Relentless rings from nudge 4, 17 alarms, so nudges 14–20 overflow.
    let scheduler = FakeScheduler(alarmLimit: 10)
    let bins = Reminder(title: "Take the bins out", dueTime: NewYork.local(2026, 10, 16), strength: .relentless)

    func engine(
        alarmLimit: AlarmLimit = .shipped,
        permissions: PermissionStates = PermissionStates(),
        holding reminders: [Reminder]
    ) -> Engine {
        var engine = Engine(
            clock: clock, scheduler: scheduler, giveUpLimit: .shipped, alarmLimit: alarmLimit,
            timeZone: NewYork.timeZone, permissions: permissions
        )
        engine.update(reminders: reminders)
        return engine
    }

    /// The engine holding `bins`, after the adapter has reported the alarms past the fake's limit.
    func engineWithBinsOverflowing(permissions: PermissionStates = PermissionStates()) -> Engine {
        var engine = engine(permissions: permissions, holding: [bins])
        reportAlarmLimit(to: &engine)
        return engine
    }

    /// What the adapter does with each alarm that failed: tell the engine, which re-plans.
    func reportAlarmLimit(to engine: inout Engine) {
        for item in scheduler.alarmsPastLimit(at: clock.now) {
            engine.markAlarmLimitReached(item.reminderID, firingAt: item.fireTime)
        }
    }

    func lastItems() throws -> [SchedulePlan.Item] {
        try #require(scheduler.lastPlan).items
    }

    @Test func alarmsPastTheLimitComeAsTimeSensitiveNotifications() throws {
        _ = engineWithBinsOverflowing()
        let items = try lastItems()
        #expect(items.count == 20)
        #expect(items.filter { $0.nudgeNumber >= 14 }.allSatisfy { $0.deliveryKind == .timeSensitiveNotification })
        #expect(items.filter { (4...13).contains($0.nudgeNumber) }.allSatisfy { $0.deliveryKind == .alarm })
    }

    @Test func onlyTheOverflowNudgesCarryTheMarker() throws {
        _ = engineWithBinsOverflowing()
        #expect(try lastItems().filter(\.isPastAlarmLimit).map(\.nudgeNumber) == Array(14...20))
    }

    /// With alarms denied the nudge would not have rung anyway, so the reason it's a notification
    /// is the denial ("alarms are off"), not the limit. Allowed again, the limit still holds.
    @Test func alarmsDeniedAfterAnOverflowDropsTheMarkerUntilAllowedAgain() throws {
        var engine = engineWithBinsOverflowing()

        engine.update(permissions: PermissionStates(alarms: .denied))
        let denied = try lastItems()
        #expect(denied.count == 20)
        #expect(denied.filter { $0.urgency == .urgent }.allSatisfy { $0.deliveryKind == .timeSensitiveNotification })
        #expect(denied.allSatisfy { !$0.isPastAlarmLimit })

        engine.update(permissions: PermissionStates(alarms: .allowed))
        let allowed = try lastItems()
        #expect(allowed.filter(\.isPastAlarmLimit).map(\.nudgeNumber) == Array(14...20))
        #expect(allowed.filter { (4...13).contains($0.nudgeNumber) }.allSatisfy { $0.deliveryKind == .alarm })
    }

    /// Each fallback only changes how a nudge arrives, so together they still give one item per
    /// nudge (ticket 14).
    @Test(arguments: [
        PermissionStates(alarms: .denied),
        PermissionStates(alarms: .denied, timeSensitive: .off),
        PermissionStates(alarms: .allowed),
    ])
    func bothFallbacksTogetherKeepOneItemPerNudge(permissions: PermissionStates) throws {
        var engine = engineWithBinsOverflowing()
        engine.update(permissions: permissions)
        #expect(try lastItems().map(\.nudgeNumber) == Array(1...20))
    }

    /// The overflow nudge takes Urgent's fallback, so Time Sensitive off makes it ordinary and
    /// notifications denied leaves nothing to deliver it (ticket 14).
    @Test(arguments: [
        (PermissionStates(timeSensitive: .off), [DeliveryKind](repeating: .notification, count: 7)),
        (PermissionStates(notifications: .denied), []),
    ])
    func overflowNudgesFollowTheOtherFallbacks(permissions: PermissionStates, kinds: [DeliveryKind]) throws {
        _ = engineWithBinsOverflowing(permissions: permissions)
        let overflow = try lastItems().filter { $0.nudgeNumber >= 14 }
        #expect(overflow.map(\.deliveryKind) == kinds)
        #expect(overflow.allSatisfy { $0.isPastAlarmLimit })
    }

    // Reports the plan gives no alarm for, which the adapter can send stale after a re-plan.

    @Test func reportForAReminderNotHeldIsIgnored() throws {
        var engine = engine(holding: [bins])
        engine.markAlarmLimitReached(UUID(), firingAt: try lastItems()[19].fireTime)
        #expect(scheduler.appliedPlans.count == 1)
    }

    @Test func reportForAFireTimeNotInThePlanIsIgnored() throws {
        var engine = engine(holding: [bins])
        engine.markAlarmLimitReached(bins.id, firingAt: try lastItems()[19].fireTime + 1)
        #expect(scheduler.appliedPlans.count == 1)
    }

    /// Nudge 1 is a notification, so it has no alarm to fail.
    @Test func reportForANudgeThatIsNotAnAlarmIsIgnored() throws {
        var engine = engine(holding: [bins])
        engine.markAlarmLimitReached(bins.id, firingAt: try lastItems()[0].fireTime)
        #expect(scheduler.appliedPlans.count == 1)
    }

    @Test func repeatedReportIsIgnored() throws {
        var engine = engine(holding: [bins])
        let nudge20 = try lastItems()[19].fireTime
        engine.markAlarmLimitReached(bins.id, firingAt: nudge20)
        engine.markAlarmLimitReached(bins.id, firingAt: nudge20)
        #expect(scheduler.appliedPlans.count == 2)
    }

    /// Nudge 4 has rung, so the adapter has nothing to schedule for it.
    @Test func reportForANudgeThatHasFiredIsIgnored() throws {
        var engine = engine(holding: [bins])
        clock.now = try lastItems()[3].fireTime
        engine.markAlarmLimitReached(bins.id, firingAt: clock.now)
        #expect(scheduler.appliedPlans.count == 1)
        #expect(engine.openOccurrence(for: bins.id) != nil)
    }

    /// Ticket 02 hit no limit, so it couldn't show whether an alarm that fired or was stopped frees
    /// a slot. A nudge the system turned down stays a notification: a later reconcile, after
    /// earlier alarms have rung, doesn't try it as an alarm again.
    @Test func reportedNudgesStayNotificationsAfterEarlierAlarmsRing() throws {
        var engine = engineWithBinsOverflowing()
        clock.now = try lastItems()[9].fireTime
        engine.update(reminders: [bins])
        #expect(try lastItems().filter(\.isPastAlarmLimit).map(\.nudgeNumber) == Array(14...20))
        #expect(scheduler.alarmsPastLimit(at: clock.now).isEmpty)
    }

    /// Like a title or a delivery (tickets 13 and 14), a nudge keeps the delivery it fired with.
    @Test func overflowNudgeThatHasFiredKeepsTheMarker() throws {
        var engine = engineWithBinsOverflowing()
        clock.now = try lastItems()[15].fireTime
        engine.update(reminders: [bins])
        let nudge16 = try lastItems()[15]
        #expect(nudge16.deliveryKind == .timeSensitiveNotification)
        #expect(nudge16.isPastAlarmLimit)
    }

    /// Delete clears the reminder's history, so one coming back under the same ID rings again.
    @Test func deleteForgetsTheAlarmLimit() throws {
        var engine = engineWithBinsOverflowing()
        engine.delete(bins.id)
        engine.update(reminders: [bins])
        let items = try lastItems()
        #expect(items.allSatisfy { !$0.isPastAlarmLimit })
        #expect(items.filter { $0.deliveryKind == .alarm }.map(\.nudgeNumber) == Array(4...20))
    }

    /// The record is per nudge. An occurrence whose ladder enters the plan after the reports
    /// rings from nudge 4 as usual.
    @Test func laterOccurrenceRingsAsAlarms() throws {
        let pills = Reminder(title: "Take the pills", dueTime: dueTime, repeatRule: .everyDay, strength: .relentless)
        var engine = engine(holding: [pills])
        reportAlarmLimit(to: &engine)

        clock.now = NewYork.local(2026, 10, 17)
        engine.update(reminders: [pills])
        let dayAfter = try lastItems().filter { $0.fireTime >= NewYork.local(2026, 10, 18) }
        #expect(dayAfter.count == 20)
        #expect(dayAfter.allSatisfy { !$0.isPastAlarmLimit })
        #expect(dayAfter.filter { $0.deliveryKind == .alarm }.map(\.nudgeNumber) == Array(4...20))
    }

    /// Moving a reminder that isn't nudging moves its ladder, so the old fire times say nothing
    /// about the new nudges. Two minutes later, new nudges 13–19 land on old nudges 14–20.
    @Test func editMovingTheLadderForgetsTheReports() throws {
        let later = Reminder(title: "Take the bins out", dueTime: NewYork.local(2026, 10, 17), strength: .relentless)
        var engine = engine(holding: [later])
        reportAlarmLimit(to: &engine)
        #expect(try lastItems().filter(\.isPastAlarmLimit).map(\.nudgeNumber) == Array(14...20))

        var moved = later
        moved.dueTime += 2 * 60
        try engine.edit(moved)
        #expect(try lastItems().allSatisfy { !$0.isPastAlarmLimit })
    }

    /// A new title leaves the ladder where it is, so the system's answer still holds.
    @Test func editOfTheTitleKeepsTheReports() throws {
        var engine = engineWithBinsOverflowing()
        var renamed = bins
        renamed.title = "Bins out tonight"
        try engine.edit(renamed)
        #expect(try lastItems().filter(\.isPastAlarmLimit).map(\.nudgeNumber) == Array(14...20))
    }

    // The engine's own cap.

    /// The engine never plans more pending alarms than its cap, soonest first, whether or not the
    /// system has reported its limit.
    @Test func alarmsPastTheEnginesCapComeAsMarkedNotificationsWithoutAReport() throws {
        _ = engine(alarmLimit: AlarmLimit(pendingAlarms: 10), holding: [bins])
        let items = try lastItems()
        #expect(items.filter(\.isPastAlarmLimit).map(\.nudgeNumber) == Array(14...20))
        #expect(items.filter { $0.deliveryKind == .alarm }.map(\.nudgeNumber) == Array(4...13))
    }

    /// Alarms that have rung hold no slot the engine counts, so the app opening mid-ladder fits
    /// the ten still to ring.
    @Test func engineCapCountsOnlyAlarmsYetToRing() throws {
        clock.now = try #require(bins.nudgeTimes(from: dueTime, within: .shipped).dropFirst(9).first)
        _ = engine(alarmLimit: AlarmLimit(pendingAlarms: 10), holding: [bins])
        let items = try lastItems()
        #expect(items.allSatisfy { !$0.isPastAlarmLimit })
        #expect(items.filter { $0.deliveryKind == .alarm }.map(\.nudgeNumber) == Array(4...20))
    }

    /// Unlike the system's limit, the engine knows its own count, so a slot it frees is reused.
    @Test func engineCapGivesAlarmsBackWhenAnotherReminderGoes() throws {
        let cat = Reminder(title: "Feed the cat", dueTime: dueTime - 60, strength: .relentless)
        var engine = engine(alarmLimit: AlarmLimit(pendingAlarms: 17), holding: [cat, bins])
        #expect(try lastItems().contains { $0.reminderID == bins.id && $0.isPastAlarmLimit })

        engine.delete(cat.id)
        let items = try lastItems()
        #expect(items.allSatisfy { !$0.isPastAlarmLimit })
        #expect(items.filter { $0.deliveryKind == .alarm }.map(\.nudgeNumber) == Array(4...20))
    }

    /// Nudges past the cap that fired before a slot freed were delivered as notifications.
    @Test func engineCapOverflowThatHasFiredKeepsTheMarker() throws {
        var engine = engine(alarmLimit: AlarmLimit(pendingAlarms: 10), holding: [bins])
        clock.now = try lastItems()[15].fireTime
        engine.update(reminders: [bins])
        let items = try lastItems()
        #expect(items.filter(\.isPastAlarmLimit).map(\.nudgeNumber) == Array(14...16))
        #expect(items.filter { $0.deliveryKind == .alarm }.map(\.nudgeNumber) == Array(4...13) + Array(17...20))
    }

    /// Which of two reminders ringing at the same times keeps its alarms doesn't depend on the
    /// order the store lists them in.
    @Test func engineCapBreaksTiesTheSameWhateverTheOrder() throws {
        let cat = Reminder(title: "Feed the cat", dueTime: dueTime, strength: .relentless)
        let limit = AlarmLimit(pendingAlarms: 17)
        _ = engine(alarmLimit: limit, holding: [cat, bins])
        let first = try lastItems().filter { $0.deliveryKind == .alarm }.map(\.reminderID)
        _ = engine(alarmLimit: limit, holding: [bins, cat])
        let second = try lastItems().filter { $0.deliveryKind == .alarm }.map(\.reminderID)
        #expect(Set(first) == Set(second))
        #expect(first.count == 17)
    }

    /// The shipped cap is the 4,000 pending alarms ticket 02 ("Summary for tickets 15, 19 and
    /// 20", point A) scheduled on an iPhone without `maximumLimitReached`. Each Relentless
    /// reminder that isn't a repeat rings 17 times: 235 of them plan 3,995 alarms, 236 plan
    /// 4,012, 12 past the cap.
    @Test(arguments: [(235, 3_995, 0), (236, 4_000, 12)])
    func shippedEnginePlansAtMostTheFourThousandAlarmsTicket02Measured(
        reminderCount: Int, alarmCount: Int, overflowCount: Int
    ) throws {
        let reminders = (0..<reminderCount).map { _ in
            Reminder(title: "Take the bins out", dueTime: dueTime, strength: .relentless)
        }
        // The public init, so the shipped cap.
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        let items = try lastItems()
        #expect(items.filter { $0.deliveryKind == .alarm }.count == alarmCount)
        #expect(items.filter(\.isPastAlarmLimit).count == overflowCount)
    }
}
