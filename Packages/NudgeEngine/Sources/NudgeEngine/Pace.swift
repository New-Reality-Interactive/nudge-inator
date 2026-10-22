import Foundation

/// How the waits between a reminder's nudges are spaced.
public enum Pace: Equatable, Sendable {
    /// The waits come from the strength and shrink as the nudging goes on.
    case escalating
}

/// How an Escalating pace's waits shrink for one strength. Every number a strength's waits can be
/// tuned by lives here, one constant per strength.
struct Waits {
    /// The wait after nudge 1, in seconds.
    var initialWait: TimeInterval
    /// What each wait is multiplied by to get the next.
    var factor: Double
    /// The shortest wait, in seconds.
    var floor: TimeInterval

    static let gentle = Waits(initialWait: 60 * 60, factor: 0.75, floor: 20 * 60)
    static let firm = Waits(initialWait: 30 * 60, factor: 0.5, floor: 5 * 60)
    static let relentless = Waits(initialWait: 10 * 60, factor: 0.5, floor: 2 * 60)
}

extension Strength {
    var escalatingWaits: Waits {
        switch self {
        case .gentle: .gentle
        case .firm: .firm
        case .relentless: .relentless
        }
    }
}

extension Pace {
    /// The wait after each nudge, in seconds. Escalating: `initialWait × factor^(n − 1)` after
    /// nudge n, never below the floor.
    ///
    /// Each wait is rounded to the nearest whole second, as the mockup's How It Nudges table
    /// does (`Math.round(minutes * 60) / 60`). So Gentle's third wait is 33 min 45 s, shown as
    /// "33.8 min", not 34 min, and its fourth is 1518.75 s rounded to 1519 s (25 min 19 s).
    /// Firm's 7.5 min and Relentless's 2.5 min are whole seconds already (450 s and 150 s).
    func interval(afterNudge nudgeNumber: Int, strength: Strength) -> TimeInterval {
        switch self {
        case .escalating:
            let waits = strength.escalatingWaits
            let eased = waits.initialWait * pow(waits.factor, Double(nudgeNumber - 1))
            return max(waits.floor, eased).rounded()
        }
    }

    /// When each nudge fires, from nudge 1 at the due time up to the give-up limit: at most
    /// the limit's nudge count, each before its span has passed.
    func nudgeTimes(from dueTime: Date, strength: Strength, within limit: GiveUpLimit) -> [Date] {
        var times = [dueTime]
        while times.count < limit.nudgeCount {
            let next = times[times.count - 1] + interval(afterNudge: times.count, strength: strength)
            guard next < dueTime + limit.span else { break }
            times.append(next)
        }
        return times
    }

    /// When an occurrence due at `dueTime` gives up: one wait after its last nudge, when the next
    /// would have fired, as the mockup's `simulate` does. That leaves the person a full wait to
    /// answer the last nudge before it counts as Missed. If the span ends sooner, it gives up
    /// then. `nudgeTimes` is the occurrence's `nudgeTimes(from:strength:within:)`, which the
    /// caller has already worked out.
    func giveUpTime(from dueTime: Date, after nudgeTimes: [Date], strength: Strength, within limit: GiveUpLimit) -> Date {
        let nextNudgeTime = nudgeTimes[nudgeTimes.count - 1] + interval(afterNudge: nudgeTimes.count, strength: strength)
        return min(nextNudgeTime, dueTime + limit.span)
    }
}

extension Reminder {
    /// When each nudge of an occurrence due at `dueTime` fires, from the reminder's pace and
    /// strength together.
    func nudgeTimes(from dueTime: Date, within limit: GiveUpLimit) -> [Date] {
        pace.nudgeTimes(from: dueTime, strength: strength, within: limit)
    }

    /// When an occurrence due at `dueTime` gives up, from the reminder's pace and strength
    /// together. `nudgeTimes` is its `nudgeTimes(from:within:)`.
    func giveUpTime(from dueTime: Date, after nudgeTimes: [Date], within limit: GiveUpLimit) -> Date {
        pace.giveUpTime(from: dueTime, after: nudgeTimes, strength: strength, within: limit)
    }
}
