import Foundation
import Testing
@testable import NudgeEngine

/// The fallback for the system's alarm limit (spec story 53). An Urgent nudge whose alarm fails
/// with `maximumLimitReached` comes as a Time Sensitive notification instead, marked so the
/// screens can say "Notification: too many alarms scheduled", and the rest of the ladder stays.
struct AlarmLimitFallbackTests {
    let dueTime = NewYork.local(2026, 10, 16)
    let clock = FakeClock(now: NewYork.local(2026, 10, 16))

    func reminder(_ strength: Strength = .relentless) -> Reminder {
        Reminder(title: "Take the bins out", dueTime: dueTime, strength: strength)
    }

    /// What the adapter does with each alarm that failed: tell the engine, which re-plans.
    func reportAlarmLimit(of scheduler: FakeScheduler, to engine: inout Engine) {
        for item in scheduler.alarmsPastLimit(at: clock.now) {
            engine.markAlarmLimitReached(item.reminderID, firingAt: item.fireTime)
        }
    }

    /// Relentless rings from nudge 4, 17 alarms. With room for 10, nudges 14–20 overflow.
    @Test func alarmsPastTheLimitComeAsMarkedTimeSensitiveNotifications() throws {
        let scheduler = FakeScheduler(alarmLimit: 10)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: [reminder()])
        reportAlarmLimit(of: scheduler, to: &engine)

        let items = try #require(scheduler.lastPlan).items
        #expect(items.count == 20)
        let overflow = items.filter { $0.nudgeNumber >= 14 }
        #expect(overflow.allSatisfy { $0.deliveryKind == .timeSensitiveNotification && $0.isPastAlarmLimit })
        #expect(items.filter { (4...13).contains($0.nudgeNumber) }.allSatisfy { $0.deliveryKind == .alarm })
    }

    @Test func onlyTheOverflowNudgesCarryTheMarker() throws {
        let scheduler = FakeScheduler(alarmLimit: 10)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: [reminder()])
        reportAlarmLimit(of: scheduler, to: &engine)

        let items = try #require(scheduler.lastPlan).items
        #expect(items.filter(\.isPastAlarmLimit).map(\.nudgeNumber) == Array(14...20))
    }

    /// With alarms denied the nudge would not have rung anyway, so the reason it's a notification
    /// is the denial ("alarms are off"), not the limit. Allowed again, the limit still holds.
    @Test func alarmsDeniedAfterAnOverflowDropsTheMarkerUntilAllowedAgain() throws {
        let scheduler = FakeScheduler(alarmLimit: 10)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: [reminder()])
        reportAlarmLimit(of: scheduler, to: &engine)

        engine.update(permissions: PermissionStates(alarms: .denied))
        let denied = try #require(scheduler.lastPlan).items
        #expect(denied.count == 20)
        #expect(denied.filter { $0.urgency == .urgent }.allSatisfy { $0.deliveryKind == .timeSensitiveNotification })
        #expect(denied.allSatisfy { !$0.isPastAlarmLimit })

        engine.update(permissions: PermissionStates(alarms: .allowed))
        let allowed = try #require(scheduler.lastPlan).items
        #expect(allowed.filter(\.isPastAlarmLimit).map(\.nudgeNumber) == Array(14...20))
        #expect(allowed.filter { (4...13).contains($0.nudgeNumber) }.allSatisfy { $0.deliveryKind == .alarm })
    }

    /// The overflow nudge takes Urgent's fallback, so Time Sensitive off makes it ordinary and
    /// notifications denied leaves nothing to deliver it (ticket 14).
    @Test(arguments: [
        (PermissionStates(timeSensitive: .off), [DeliveryKind](repeating: .notification, count: 7)),
        (PermissionStates(notifications: .denied), []),
    ])
    func overflowNudgesFollowTheOtherFallbacks(permissions: PermissionStates, kinds: [DeliveryKind]) throws {
        let scheduler = FakeScheduler(alarmLimit: 10)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: permissions)
        engine.update(reminders: [reminder()])
        reportAlarmLimit(of: scheduler, to: &engine)

        let overflow = try #require(scheduler.lastPlan).items.filter { $0.nudgeNumber >= 14 }
        #expect(overflow.map(\.deliveryKind) == kinds)
        #expect(overflow.allSatisfy { $0.isPastAlarmLimit })
    }

    /// The engine holding a Relentless reminder, and its first plan's items. Reports below are
    /// ones the plan gives no alarm for, which the adapter can send stale after a re-plan.
    func engineHoldingBins(_ scheduler: FakeScheduler) throws -> (Engine, Reminder, [SchedulePlan.Item]) {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        let bins = reminder()
        engine.update(reminders: [bins])
        return (engine, bins, try #require(scheduler.lastPlan).items)
    }

    @Test func reportForAReminderNotHeldIsIgnored() throws {
        let scheduler = FakeScheduler()
        var (engine, _, items) = try engineHoldingBins(scheduler)
        engine.markAlarmLimitReached(UUID(), firingAt: items[19].fireTime)
        #expect(scheduler.appliedPlans.count == 1)
    }

    @Test func reportForAFireTimeNotInThePlanIsIgnored() throws {
        let scheduler = FakeScheduler()
        var (engine, bins, items) = try engineHoldingBins(scheduler)
        engine.markAlarmLimitReached(bins.id, firingAt: items[19].fireTime + 1)
        #expect(scheduler.appliedPlans.count == 1)
    }

    /// Nudge 1 is a notification, so it has no alarm to fail.
    @Test func reportForANudgeThatIsNotAnAlarmIsIgnored() throws {
        let scheduler = FakeScheduler()
        var (engine, bins, items) = try engineHoldingBins(scheduler)
        engine.markAlarmLimitReached(bins.id, firingAt: items[0].fireTime)
        #expect(scheduler.appliedPlans.count == 1)
    }

    @Test func repeatedReportIsIgnored() throws {
        let scheduler = FakeScheduler()
        var (engine, bins, items) = try engineHoldingBins(scheduler)
        engine.markAlarmLimitReached(bins.id, firingAt: items[19].fireTime)
        engine.markAlarmLimitReached(bins.id, firingAt: items[19].fireTime)
        #expect(scheduler.appliedPlans.count == 2)
    }

    /// Nudge 4 has rung, so the adapter has nothing to schedule for it.
    @Test func reportForANudgeThatHasFiredIsIgnored() throws {
        let scheduler = FakeScheduler()
        var (engine, bins, items) = try engineHoldingBins(scheduler)
        clock.now = items[3].fireTime
        engine.markAlarmLimitReached(bins.id, firingAt: items[3].fireTime)
        #expect(scheduler.appliedPlans.count == 1)
        #expect(engine.openOccurrence(for: bins.id) != nil)
    }

    /// Ticket 02 hit no limit, so it couldn't show whether an alarm that fired or was stopped frees
    /// a slot. A nudge that fell back stays a notification: a later reconcile, after earlier
    /// alarms have rung, doesn't try it as an alarm again.
    @Test func fallenBackNudgesStayNotificationsAfterEarlierAlarmsRing() throws {
        let scheduler = FakeScheduler(alarmLimit: 10)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        let bins = reminder()
        engine.update(reminders: [bins])
        reportAlarmLimit(of: scheduler, to: &engine)
        let nudge10 = try #require(scheduler.lastPlan?.items.first { $0.nudgeNumber == 10 })

        clock.now = nudge10.fireTime
        engine.update(reminders: [bins])
        let items = try #require(scheduler.lastPlan).items
        #expect(items.filter(\.isPastAlarmLimit).map(\.nudgeNumber) == Array(14...20))
        #expect(scheduler.alarmsPastLimit(at: clock.now).isEmpty)
    }

    /// Like a title or a delivery (tickets 13 and 14), a nudge keeps the delivery it fired with.
    @Test func overflowNudgeThatHasFiredKeepsTheMarker() throws {
        let scheduler = FakeScheduler(alarmLimit: 10)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        let bins = reminder()
        engine.update(reminders: [bins])
        reportAlarmLimit(of: scheduler, to: &engine)
        let nudge16 = try #require(scheduler.lastPlan?.items.first { $0.nudgeNumber == 16 })

        clock.now = nudge16.fireTime
        engine.update(reminders: [bins])
        let fired = try #require(scheduler.lastPlan?.items.first { $0.nudgeNumber == 16 })
        #expect(fired.deliveryKind == .timeSensitiveNotification)
        #expect(fired.isPastAlarmLimit)
    }

    /// Delete clears the reminder's history, so one coming back under the same ID rings again.
    @Test func deleteForgetsTheAlarmLimit() throws {
        let scheduler = FakeScheduler(alarmLimit: 10)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        let bins = reminder()
        engine.update(reminders: [bins])
        reportAlarmLimit(of: scheduler, to: &engine)

        engine.delete(bins.id)
        engine.update(reminders: [bins])
        let items = try #require(scheduler.lastPlan).items
        #expect(items.allSatisfy { !$0.isPastAlarmLimit })
        #expect(items.filter { $0.deliveryKind == .alarm }.map(\.nudgeNumber) == Array(4...20))
    }

    /// The record is per nudge. An occurrence whose ladder enters the plan after the reports
    /// rings from nudge 4 as usual.
    @Test func laterOccurrenceRingsAsAlarms() throws {
        let scheduler = FakeScheduler(alarmLimit: 10)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        let pills = Reminder(title: "Take the pills", dueTime: dueTime, repeatRule: .everyDay, strength: .relentless)
        engine.update(reminders: [pills])
        reportAlarmLimit(of: scheduler, to: &engine)

        clock.now = NewYork.local(2026, 10, 17)
        engine.update(reminders: [pills])
        let dayAfter = try #require(scheduler.lastPlan).items.filter { $0.fireTime >= NewYork.local(2026, 10, 18) }
        #expect(dayAfter.count == 20)
        #expect(dayAfter.allSatisfy { !$0.isPastAlarmLimit })
        #expect(dayAfter.filter { $0.deliveryKind == .alarm }.map(\.nudgeNumber) == Array(4...20))
    }

    /// The engine never plans more pending alarms than ticket 02 measured scheduling, soonest
    /// first, whether or not the system has reported its limit.
    @Test func alarmsPastTheEnginesCapComeAsMarkedNotificationsWithoutAReport() throws {
        let scheduler = FakeScheduler()
        var engine = Engine(
            clock: clock, scheduler: scheduler, giveUpLimit: .shipped, alarmLimit: AlarmLimit(pendingAlarms: 10),
            timeZone: NewYork.timeZone
        )
        engine.update(reminders: [reminder()])

        let items = try #require(scheduler.lastPlan).items
        #expect(items.filter(\.isPastAlarmLimit).map(\.nudgeNumber) == Array(14...20))
        #expect(items.filter { $0.deliveryKind == .alarm }.map(\.nudgeNumber) == Array(4...13))
    }

    /// Alarms that have rung hold no slot the engine counts, so the app opening mid-ladder fits
    /// the ten still to ring.
    @Test func engineCapCountsOnlyAlarmsYetToRing() throws {
        let bins = reminder()
        let nudge10 = try #require(bins.strength.nudgeTimes(from: dueTime, within: .shipped).dropFirst(9).first)
        clock.now = nudge10
        let scheduler = FakeScheduler()
        var engine = Engine(
            clock: clock, scheduler: scheduler, giveUpLimit: .shipped, alarmLimit: AlarmLimit(pendingAlarms: 10),
            timeZone: NewYork.timeZone
        )
        engine.update(reminders: [bins])

        let items = try #require(scheduler.lastPlan).items
        #expect(items.allSatisfy { !$0.isPastAlarmLimit })
        #expect(items.filter { $0.deliveryKind == .alarm }.map(\.nudgeNumber) == Array(4...20))
    }

    /// The shipped cap is the 4,000 pending alarms ticket 02 ("Summary for tickets 15, 19 and
    /// 20", point A) scheduled on an iPhone without `maximumLimitReached`. Each Relentless
    /// reminder rings 17 times: 235 of them plan 3,995 alarms, 236 plan 4,012, 12 past the cap.
    @Test(arguments: [(235, 3_995, 0), (236, 4_000, 12)])
    func shippedEnginePlansAtMostTheFourThousandAlarmsTicket02Measured(
        reminderCount: Int, alarmCount: Int, overflowCount: Int
    ) throws {
        let scheduler = FakeScheduler()
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: (0..<reminderCount).map { _ in reminder() })

        let items = try #require(scheduler.lastPlan).items
        #expect(items.filter { $0.deliveryKind == .alarm }.count == alarmCount)
        #expect(items.filter(\.isPastAlarmLimit).count == overflowCount)
    }
}
