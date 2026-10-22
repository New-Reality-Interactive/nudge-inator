import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The footer under How It Nudges (the mockup's `nudgeSummary`, less its chain, which the engine
/// doesn't send), worked out from the engine's read-out, so the app retypes no ladder number. The
/// expected totals are worked out by hand, as in `HowItNudgesTests`.
struct HowItNudgesSummaryTests {
    func summary(_ strength: Strength, pace: Pace = .escalating, breakThroughFocus: Bool = true, _ permissions: PermissionStates = PermissionStates(alarms: .allowed)) -> [HowItNudgesSentence] {
        let engine = Engine(clock: FakeClock(now: .now), scheduler: FakeScheduler(), permissions: permissions)
        return HowItNudgesSentence.summary(of: engine.howItNudges(strength, pace: pace, breakThroughFocus: breakThroughFocus))
    }

    @Test(arguments: [
        // Gentle's and Firm's Normal nudges are ordinary notifications, which a Focus holds.
        (Strength.gentle, true, PermissionStates(alarms: .allowed), [HowItNudgesSentence.givesUp(nudges: 20, after: 29044), .allNotifications(nudges: 20), .focusHoldsNormal]),
        (.firm, true, PermissionStates(alarms: .allowed), [.givesUp(nudges: 20, after: 8250), .notificationsThenAlarms(alarms: 4...20), .focusHoldsNormal]),
        // Every Relentless nudge rings, so nothing waits.
        (.relentless, true, PermissionStates(alarms: .allowed), [.givesUp(nudges: 20, after: 3090), .allRing(nudges: 20)]),
        (.relentless, true, PermissionStates(alarms: .denied), [.givesUp(nudges: 20, after: 3090), .allNotifications(nudges: 20), .urgentIsTimeSensitive]),
        (.firm, true, PermissionStates(alarms: .denied), [.givesUp(nudges: 20, after: 8250), .allNotifications(nudges: 20), .urgentIsTimeSensitive, .focusHoldsNormal]),
        (.firm, true, PermissionStates(alarms: .denied, timeSensitive: .off), [.givesUp(nudges: 20, after: 8250), .allNotifications(nudges: 20), .urgentIsOrdinary, .focusHoldsEveryNotification]),
        (.relentless, true, PermissionStates(alarms: .allowed, timeSensitive: .off), [.givesUp(nudges: 20, after: 3090), .allRing(nudges: 20)]),
        (.relentless, true, PermissionStates(notifications: .denied, alarms: .allowed), [.givesUp(nudges: 20, after: 3090), .allRing(nudges: 20)]),
        (.firm, true, PermissionStates(notifications: .denied, alarms: .allowed), [.givesUp(nudges: 20, after: 8250), .cannotArriveUntilAlarms(alarms: 4...20)]),
        (.gentle, true, PermissionStates(notifications: .denied, alarms: .allowed), [.givesUp(nudges: 20, after: 29044), .noneCanArrive]),
        (.firm, false, PermissionStates(alarms: .allowed), [.givesUp(nudges: 20, after: 8250), .allNotifications(nudges: 20), .focusHoldsEveryNudge]),
        // Relentless ignores its stored switch (ticket 06).
        (.relentless, false, PermissionStates(alarms: .allowed), [.givesUp(nudges: 20, after: 3090), .allRing(nudges: 20)]),
    ])
    func theSummarySaysHowEveryNudgeArrives(strength: Strength, breakThroughFocus: Bool, permissions: PermissionStates, expected: [HowItNudgesSentence]) {
        #expect(summary(strength, breakThroughFocus: breakThroughFocus, permissions) == expected)
    }

    /// Mockup item 10: a Consistent reminder's summary stays true for long waits, which can give up
    /// before High, Urgent or a third nudge. The span runs one wait past the last nudge, or to the
    /// 24 hr limit if that comes first.
    static let longWaits: [(Strength, Pace, [HowItNudgesSentence])] = [
        // Every 30 min, Firm sends all 20, ringing from nudge 4, and gives up 10 hr after the due time.
        (.firm, .consistent(wait: 30 * 60), [.givesUp(nudges: 20, after: 36000), .notificationsThenAlarms(alarms: 4...20), .focusHoldsNormal]),
        // Every 8 hr: nudges at 0, 8 and 16 hr. Nudge 3 is High, so Normal nudges still wait for it.
        (.firm, .consistent(wait: 8 * 60 * 60), [.givesUp(nudges: 3, after: 86400), .allNotifications(nudges: 3), .focusHoldsNormal]),
        // Every 12 hr: nudges at 0 and 12 hr, both Normal, so a Focus holds every one.
        (.firm, .consistent(wait: 12 * 60 * 60), [.givesUp(nudges: 2, after: 86400), .allNotifications(nudges: 2), .focusHoldsAllNormal]),
        (.gentle, .consistent(wait: 16 * 60 * 60), [.givesUp(nudges: 2, after: 86400), .allNotifications(nudges: 2), .focusHoldsAllNormal]),
        // Relentless is Urgent from nudge 1, so both ring.
        (.relentless, .consistent(wait: 16 * 60 * 60), [.givesUp(nudges: 2, after: 86400), .allRing(nudges: 2)]),
    ]

    @Test(arguments: longWaits)
    func aConsistentSummaryStaysTrueForLongWaits(strength: Strength, pace: Pace, expected: [HowItNudgesSentence]) {
        #expect(summary(strength, pace: pace) == expected)
    }
}
