import Foundation
import Testing
import NudgeEngine

/// How It Nudges (ticket 31): a strength's ladder as rows, read from the engine so the screens never
/// retype a constant. Expected values are worked out by hand from the ladder: Firm waits 30, 15,
/// 7.5 min, then the 5 min floor; High from nudge 3, Urgent from 4.
struct HowItNudgesTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 16))
    let scheduler = FakeScheduler()

    func engine(permissions: PermissionStates = PermissionStates(alarms: .allowed)) -> Engine {
        Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone, permissions: permissions)
    }

    /// Nudges with the same urgency and wait fold into one row, as the mockup's `ladderRows` does.
    @Test func firmFoldsItsFloorIntoOneUrgentRow() {
        let rows = engine().howItNudges(.firm, breakThroughFocus: true).rows
        #expect(rows == [
            HowItNudges.Row(nudges: 1...1, startsAfter: 0, wait: 30 * 60, urgency: .normal, delivery: .notification(weakerBecause: nil)),
            HowItNudges.Row(nudges: 2...2, startsAfter: 30 * 60, wait: 15 * 60, urgency: .normal, delivery: .notification(weakerBecause: nil)),
            HowItNudges.Row(nudges: 3...3, startsAfter: 45 * 60, wait: 450, urgency: .high, delivery: .notification(weakerBecause: nil)),
            HowItNudges.Row(nudges: 4...20, startsAfter: 3150, wait: 5 * 60, urgency: .urgent, delivery: .alarm),
        ])
    }

    /// Gentle waits 60, 45, 33.75 and 25.3 min (1519 s), then the 20 min floor from nudge 5,
    /// where it turns High. It gives up one wait after nudge 20: 9844 + 15 × 1200 + 1200 s.
    /// Relentless waits 10, 5, 2.5 min, then 2: nudge 20 at 1050 + 16 × 120, one wait more.
    @Test(arguments: [
        (Strength.gentle, 29044.0, [1...1, 2...2, 3...3, 4...4, 5...20]),
        (.firm, 8250, [1...1, 2...2, 3...3, 4...20]),
        (.relentless, 3090, [1...1, 2...2, 3...3, 4...20]),
    ])
    func everyStrengthSendsTwentyNudgesThenGivesUp(strength: Strength, givesUpAfter: TimeInterval, nudges: [ClosedRange<Int>]) {
        let howItNudges = engine().howItNudges(strength, breakThroughFocus: true)
        #expect(howItNudges.nudgeCount == 20)
        #expect(howItNudges.givesUpAfter == givesUpAfter)
        #expect(howItNudges.rows.map(\.nudges) == nudges)
    }

    /// The via labels follow the permissions, as the nudge card's do.
    @Test(arguments: [
        (PermissionStates(alarms: .denied), [NudgeDelivery.notification(weakerBecause: nil), .notification(weakerBecause: nil), .notification(weakerBecause: nil), .notification(weakerBecause: .alarmsOff)]),
        (PermissionStates(alarms: .denied, timeSensitive: .off), [.notification(weakerBecause: nil), .notification(weakerBecause: nil), .notification(weakerBecause: .timeSensitiveOff), .notification(weakerBecause: .alarmsAndTimeSensitiveOff)]),
        (PermissionStates(notifications: .denied, alarms: .allowed), [.cannotArrive, .cannotArrive, .cannotArrive, .alarm]),
        // Not asked yet plans as allowed.
        (PermissionStates(alarms: .notDetermined), [.notification(weakerBecause: nil), .notification(weakerBecause: nil), .notification(weakerBecause: nil), .alarm]),
    ])
    func firmDeliveriesFollowThePermissions(permissions: PermissionStates, deliveries: [NudgeDelivery]) {
        let rows = engine(permissions: permissions).howItNudges(.firm, breakThroughFocus: true).rows
        #expect(rows.map(\.delivery) == deliveries)
    }

    /// Every Relentless nudge is Urgent (ticket 05), so each row rings, or with alarms denied each
    /// is a notification weakened for that reason. Its waits still split it into four rows until
    /// a Consistent pace (ticket 07) folds it into the mockup's one.
    @Test(arguments: [
        (PermissionStates(alarms: .allowed), NudgeDelivery.alarm),
        (PermissionStates(alarms: .denied), .notification(weakerBecause: .alarmsOff)),
        (PermissionStates(alarms: .denied, timeSensitive: .off), .notification(weakerBecause: .alarmsAndTimeSensitiveOff)),
    ])
    func relentlessIsUrgentFromNudgeOne(permissions: PermissionStates, delivery: NudgeDelivery) {
        let rows = engine(permissions: permissions).howItNudges(.relentless, breakThroughFocus: true).rows
        #expect(rows.map(\.urgency) == [Urgency](repeating: .urgent, count: 4))
        #expect(rows.map(\.delivery) == [NudgeDelivery](repeating: delivery, count: 4))
    }

    @Test func breakThroughFocusOffSendsEveryNudgeAsAnOrdinaryNotification() {
        let rows = engine().howItNudges(.relentless, breakThroughFocus: false).rows
        #expect(rows.map(\.delivery) == [NudgeDelivery](repeating: .notification(weakerBecause: .breakThroughFocusOff), count: 4))
    }
}
