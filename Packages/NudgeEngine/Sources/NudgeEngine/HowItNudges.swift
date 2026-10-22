import Foundation

/// A strength's ladder as How It Nudges shows it (ticket 31): which nudges come when, how urgent
/// they are and how they arrive with the permissions the person has given, up to the give-up
/// limit. The screens read it rather than retyping the ladder's constants.
public struct HowItNudges: Equatable, Sendable {
    public var rows: [Row]
    /// How many nudges an occurrence sends before it gives up.
    public var nudgeCount: Int
    /// From the due time to when it gives up: one wait after the last nudge (see `giveUpTime`).
    public var givesUpAfter: TimeInterval

    /// Nudges in a row that share an urgency, a wait and a delivery, as the mockup's `ladderRows`
    /// folds them: "Nudges 4–20, every 5 min".
    public struct Row: Equatable, Sendable {
        public var nudges: ClosedRange<Int>
        /// From the due time to the first of these nudges: 0 for nudge 1, "when due".
        public var startsAfter: TimeInterval
        /// The wait after each of these nudges.
        public var wait: TimeInterval
        public var urgency: Urgency
        public var delivery: NudgeDelivery

        public init(nudges: ClosedRange<Int>, startsAfter: TimeInterval, wait: TimeInterval, urgency: Urgency, delivery: NudgeDelivery) {
            self.nudges = nudges
            self.startsAfter = startsAfter
            self.wait = wait
            self.urgency = urgency
            self.delivery = delivery
        }
    }
}

extension Engine {
    /// How a reminder of this strength, pace and Break Through Focus switch nudges, with the current
    /// permissions and no alarm limit reached. There's no take-over: with the shipped give-up
    /// limit even a daily repeat gives up long before its next occurrence falls due.
    public func howItNudges(_ strength: Strength, pace: Pace = .escalating, breakThroughFocus: Bool) -> HowItNudges {
        let dueTime = Date(timeIntervalSinceReferenceDate: 0)
        let times = pace.nudgeTimes(from: dueTime, strength: strength, within: giveUpLimit)
        var rows: [HowItNudges.Row] = []
        for (index, time) in times.enumerated() {
            let number = index + 1
            let urgency = strength.urgency(ofNudge: number)
            let row = HowItNudges.Row(
                nudges: number...number,
                startsAfter: time.timeIntervalSince(dueTime),
                wait: pace.interval(afterNudge: number, strength: strength),
                urgency: urgency,
                delivery: Self.nudgeDelivery(
                    delivery(of: urgency, breakThroughFocus: breakThroughFocus, permissions: permissions, alarmLimitReached: false),
                    urgency: urgency,
                    breakThroughFocus: breakThroughFocus,
                    timeSensitive: permissions.timeSensitive
                )
            )
            if let last = rows.last, last.urgency == row.urgency, last.wait == row.wait, last.delivery == row.delivery {
                rows[rows.count - 1].nudges = last.nudges.lowerBound...number
            } else {
                rows.append(row)
            }
        }
        let giveUpTime = pace.giveUpTime(from: dueTime, after: times, strength: strength, within: giveUpLimit)
        return HowItNudges(rows: rows, nudgeCount: times.count, givesUpAfter: giveUpTime.timeIntervalSince(dueTime))
    }
}
