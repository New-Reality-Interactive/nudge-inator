import Foundation
import NudgeEngine

/// One sentence of the footer under How It Nudges (the mockup's `nudgeSummary`), worked out from
/// the engine's read-out. The mockup's chain sentences are left out: the engine sends no chain.
enum HowItNudgesSentence: Hashable {
    /// "20 nudges over 2 hr, 18 min, then it gives up."
    case givesUp(nudges: Int, after: TimeInterval)
    /// Notifications are off and none of them rings.
    case noneCanArrive
    /// Notifications are off: only these nudges, which ring, reach the person.
    case cannotArriveUntilAlarms(alarms: ClosedRange<Int>)
    case allRing(nudges: Int)
    case allNotifications(nudges: Int)
    case notificationsThenAlarms(alarms: ClosedRange<Int>)
    /// Alarms are off, so Urgent nudges come as Time Sensitive notifications.
    case urgentIsTimeSensitive
    /// Alarms and Time Sensitive are off, so Urgent nudges come as ordinary notifications.
    case urgentIsOrdinary
    /// During a Focus, Normal nudges wait until High.
    case focusHoldsNormal
    /// Break Through Focus is off, so during a Focus every nudge waits.
    case focusHoldsEveryNudge
    /// Time Sensitive is off, so during a Focus every notification waits.
    case focusHoldsEveryNotification

    static func summary(of howItNudges: HowItNudges) -> [HowItNudgesSentence] {
        let rows = howItNudges.rows
        let count = howItNudges.nudgeCount
        var sentences: [HowItNudgesSentence] = [.givesUp(nudges: count, after: howItNudges.givesUpAfter)]
        // Urgent comes last on every ladder, so the alarms are the last nudges.
        let alarms = howItNudges.firstAlarm.map { $0...count }
        let notificationsOff = rows.contains { $0.delivery == .cannotArrive }
        switch (alarms, notificationsOff) {
        case (nil, true): return sentences + [.noneCanArrive]
        case (let alarms?, _) where alarms.lowerBound == 1: sentences.append(.allRing(nudges: count))
        case (let alarms?, true): return sentences + [.cannotArriveUntilAlarms(alarms: alarms)]
        case (nil, false): sentences.append(.allNotifications(nudges: count))
        case (let alarms?, false): sentences.append(.notificationsThenAlarms(alarms: alarms))
        }
        let reasons = rows.compactMap { row -> NudgeDelivery.Reason? in
            if case .notification(let reason) = row.delivery { reason } else { nil }
        }
        if reasons.contains(.alarmsAndTimeSensitiveOff) {
            sentences.append(.urgentIsOrdinary)
        } else if reasons.contains(.alarmsOff) {
            sentences.append(.urgentIsTimeSensitive)
        }
        if reasons.contains(.breakThroughFocusOff) {
            sentences.append(.focusHoldsEveryNudge)
        } else if reasons.contains(.timeSensitiveOff) || reasons.contains(.alarmsAndTimeSensitiveOff) {
            sentences.append(.focusHoldsEveryNotification)
        } else if rows.contains(where: { $0.urgency == .normal }) {
            sentences.append(.focusHoldsNormal)
        }
        return sentences
    }
}

extension HowItNudges {
    /// The first nudge that rings, or `nil` if none does.
    var firstAlarm: Int? {
        rows.first { $0.delivery == .alarm }?.nudges.lowerBound
    }
}
