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
    /// is a notification weakened for that reason. Its Escalating waits split it into four rows;
    /// a Consistent pace folds it into the mockup's one (`consistentRelentlessIsOneRow`).
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

    /// Normal nudges are ordinary anyway, so only High and Urgent say the switch weakened them.
    @Test func breakThroughFocusOffSendsEveryNudgeAsAnOrdinaryNotification() {
        let rows = engine().howItNudges(.firm, breakThroughFocus: false).rows
        #expect(rows.map(\.delivery) == [
            .notification(weakerBecause: nil),
            .notification(weakerBecause: nil),
            .notification(weakerBecause: .breakThroughFocusOff),
            .notification(weakerBecause: .breakThroughFocusOff),
        ])
    }

    /// Relentless ignores its stored switch (ADR 0004), so off reads as on.
    @Test func relentlessWithItsSwitchOffStillRingsEveryNudge() {
        let rows = engine().howItNudges(.relentless, breakThroughFocus: false).rows
        #expect(rows.map(\.delivery) == [NudgeDelivery](repeating: .alarm, count: 4))
    }

    /// Equal waits fold into one row per urgency (ticket 07; mockup items 10 and 11). Relentless at
    /// Consistent is one Urgent alarm row, "Nudges 1–20 when due", and with 10 min between nudges
    /// it gives up one wait after nudge 20: 19 × 600 + 600 = 12,000 s.
    @Test func consistentRelentlessIsOneRow() {
        let howItNudges = engine().howItNudges(.relentless, pace: .consistent(wait: 600), breakThroughFocus: true)
        #expect(howItNudges.rows == [
            HowItNudges.Row(nudges: 1...20, startsAfter: 0, wait: 600, urgency: .urgent, delivery: .alarm),
        ])
        #expect(howItNudges.nudgeCount == 20)
        #expect(howItNudges.givesUpAfter == 12_000)
    }

    /// Firm keeps its three urgency steps at 10 min: Normal for nudges 1 and 2, High for 3, Urgent
    /// from 4, which starts at 3 × 600 = 1800 s. Gentle, at 1 h, turns High at nudge 5, 4 h in.
    @Test func consistentFoldsEachUrgencyIntoOneRow() {
        let firm = engine().howItNudges(.firm, pace: .consistent(wait: 600), breakThroughFocus: true).rows
        #expect(firm == [
            HowItNudges.Row(nudges: 1...2, startsAfter: 0, wait: 600, urgency: .normal, delivery: .notification(weakerBecause: nil)),
            HowItNudges.Row(nudges: 3...3, startsAfter: 1200, wait: 600, urgency: .high, delivery: .notification(weakerBecause: nil)),
            HowItNudges.Row(nudges: 4...20, startsAfter: 1800, wait: 600, urgency: .urgent, delivery: .alarm),
        ])
        let gentle = engine().howItNudges(.gentle, pace: .consistent(wait: 3600), breakThroughFocus: true)
        #expect(gentle.rows.map(\.nudges) == [1...4, 5...20])
        #expect(gentle.rows.map(\.startsAfter) == [0, 4 * 3600])
        #expect(gentle.givesUpAfter == 20 * 3600)
    }

    /// A 16 h wait nudges twice and gives up at 24 h, so its read-out says so.
    @Test func aLongWaitShowsTwoNudgesAndGivingUpAtADay() {
        let howItNudges = engine().howItNudges(.relentless, pace: .consistent(wait: 16 * 3600), breakThroughFocus: true)
        #expect(howItNudges.nudgeCount == 2)
        #expect(howItNudges.rows.map(\.nudges) == [1...2])
        #expect(howItNudges.givesUpAfter == 24 * 3600)
    }
}
