import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The footer under How It Nudges (the mockup's `nudgeSummary`, less its chain, which the engine
/// doesn't send), worked out from the engine's read-out, so the app retypes no ladder number. The
/// expected totals are worked out by hand, as in `HowItNudgesTests`.
struct HowItNudgesSummaryTests {
    func summary(_ strength: Strength, breakThroughFocus: Bool = true, _ permissions: PermissionStates = PermissionStates(alarms: .allowed)) -> [HowItNudgesSentence] {
        let engine = Engine(clock: FakeClock(now: .now), scheduler: FakeScheduler(), permissions: permissions)
        return HowItNudgesSentence.summary(of: engine.howItNudges(strength, breakThroughFocus: breakThroughFocus))
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
        (.relentless, false, PermissionStates(alarms: .allowed), [.givesUp(nudges: 20, after: 3090), .allNotifications(nudges: 20), .focusHoldsEveryNudge]),
    ])
    func theSummarySaysHowEveryNudgeArrives(strength: Strength, breakThroughFocus: Bool, permissions: PermissionStates, expected: [HowItNudgesSentence]) {
        #expect(summary(strength, breakThroughFocus: breakThroughFocus, permissions) == expected)
    }
}
