import Foundation

/// The give-up limit: 20 nudges or 24 hours after the due time, whichever comes first. Fixed,
/// with no editor; only tests use another.
public struct GiveUpLimit: Equatable, Sendable {
    public var nudgeCount: Int
    public var span: TimeInterval

    /// Public only so the app's tests can widen it: with `shipped`, a daily repeat gives up long
    /// before its next occurrence falls due, so only a wider limit reaches a take-over.
    public init(nudgeCount: Int, span: TimeInterval) {
        self.nudgeCount = nudgeCount
        self.span = span
    }

    /// With today's ladders every strength reaches nudge 20 well inside 24 hours (Gentle, the
    /// slowest, gives up at +8 h 4 min 4 s). The span is enforced anyway, so a retuned ladder
    /// can't nudge past a day.
    public static let shipped = GiveUpLimit(nudgeCount: 20, span: 24 * 60 * 60)
}

/// One strength's ladder: how the waits shrink and where urgency rises. Every number a strength
/// can be tuned by lives here, one constant per strength.
struct Ladder {
    /// The wait after nudge 1, in seconds.
    var initialWait: TimeInterval
    /// What each wait is multiplied by to get the next.
    var factor: Double
    /// The shortest wait, in seconds.
    var floor: TimeInterval
    /// The first High nudge. Nudges before it are Normal.
    var highFrom: Int
    /// The first Urgent nudge, or `nil` for a ladder that never reaches Urgent.
    var urgentFrom: Int?

    // Urgency is a nudge number per step, not the mockup's `priorityAt` formula, which derives
    // it from where the waits reach the floor. With the formula, tuning a factor or floor would
    // quietly move "Urgent from nudge 4" and could make Gentle ring. Here those rules are
    // written down and tuned on their own.

    static let gentle = Ladder(initialWait: 60 * 60, factor: 0.75, floor: 20 * 60, highFrom: 5, urgentFrom: nil)
    static let firm = Ladder(initialWait: 30 * 60, factor: 0.5, floor: 5 * 60, highFrom: 3, urgentFrom: 4)
    static let relentless = Ladder(initialWait: 10 * 60, factor: 0.5, floor: 2 * 60, highFrom: 1, urgentFrom: 4)
}

extension Strength {
    var ladder: Ladder {
        switch self {
        case .gentle: .gentle
        case .firm: .firm
        case .relentless: .relentless
        }
    }

    /// The wait after each nudge, in seconds: `initialWait × factor^(n − 1)` after nudge n, never
    /// below the floor.
    ///
    /// Each wait is rounded to the nearest whole second, as the mockup's How It Nudges table
    /// does (`Math.round(minutes * 60) / 60`). So Gentle's third wait is 33 min 45 s, shown as
    /// "33.8 min", not 34 min, and its fourth is 1518.75 s rounded to 1519 s (25 min 19 s).
    /// Firm's 7.5 min and Relentless's 2.5 min are whole seconds already (450 s and 150 s).
    func interval(afterNudge nudgeNumber: Int) -> TimeInterval {
        let eased = ladder.initialWait * pow(ladder.factor, Double(nudgeNumber - 1))
        return max(ladder.floor, eased).rounded()
    }

    /// When each nudge fires, from nudge 1 at the due time up to the give-up limit: at most
    /// the limit's nudge count, each before its span has passed.
    func nudgeTimes(from dueTime: Date, within limit: GiveUpLimit) -> [Date] {
        var times = [dueTime]
        while times.count < limit.nudgeCount {
            let next = times[times.count - 1] + interval(afterNudge: times.count)
            guard next < dueTime + limit.span else { break }
            times.append(next)
        }
        return times
    }

    /// When an occurrence due at `dueTime` gives up: one wait after its last nudge, when the next
    /// would have fired, as the mockup's `simulate` does. That leaves the person a full wait to
    /// answer the last nudge before it counts as Missed. If the span ends sooner, it gives up
    /// then. `nudgeTimes` is the occurrence's `nudgeTimes(from:within:)`, which the caller has
    /// already worked out.
    func giveUpTime(from dueTime: Date, after nudgeTimes: [Date], within limit: GiveUpLimit) -> Date {
        let nextNudgeTime = nudgeTimes[nudgeTimes.count - 1] + interval(afterNudge: nudgeTimes.count)
        return min(nextNudgeTime, dueTime + limit.span)
    }

    /// The urgency of a nudge, as in the mockup's How It Nudges table.
    func urgency(ofNudge nudgeNumber: Int) -> Urgency {
        if let urgentFrom = ladder.urgentFrom, nudgeNumber >= urgentFrom { return .urgent }
        return nudgeNumber >= ladder.highFrom ? .high : .normal
    }
}
