import Foundation

/// The give-up limit. Ticket 06 builds the rest of it (the 24-hour span and closing as Missed).
public enum GiveUpLimit {
    public static let nudgeCount = 20
}

extension Strength {
    /// The wait after each nudge, in seconds: `initial × factor^(n − 1)` after nudge n, never
    /// below the floor.
    ///
    /// Each wait is rounded to the nearest whole second, as the mockup's How It Nudges table
    /// does (`Math.round(minutes * 60) / 60`). So Gentle's third wait is 33 min 45 s, shown as
    /// "33.8 min", not 34 min, and its fourth is 1518.75 s rounded to 1519 s (25 min 19 s).
    func interval(afterNudge nudgeNumber: Int) -> TimeInterval {
        let (initial, factor, floor): (Double, Double, Double) = switch self {
        case .gentle: (60 * 60, 0.75, 20 * 60)
        }
        let eased = initial * pow(factor, Double(nudgeNumber - 1))
        return max(floor, eased).rounded()
    }

    /// When each nudge fires, from nudge 1 at the due time up to the give-up limit.
    func nudgeTimes(from dueTime: Date) -> [Date] {
        var times = [dueTime]
        while times.count < GiveUpLimit.nudgeCount {
            times.append(times[times.count - 1] + interval(afterNudge: times.count))
        }
        return times
    }
}

extension Strength {
    /// The urgency of a nudge, as in the mockup's How It Nudges table. Gentle turns High at
    /// nudge 5, where its waits reach the floor, and never reaches Urgent.
    func urgency(ofNudge nudgeNumber: Int) -> Urgency {
        switch self {
        case .gentle: nudgeNumber >= 5 ? .high : .normal
        }
    }
}
