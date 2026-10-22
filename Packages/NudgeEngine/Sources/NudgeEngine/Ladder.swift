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

/// One strength's ladder: where urgency rises. The waits between nudges come from the pace
/// (`Pace`), which for Escalating reads the strength's `Waits`.
struct Ladder {
    /// The first High nudge. Nudges before it are Normal.
    var highFrom: Int
    /// The first Urgent nudge, or `nil` for a ladder that never reaches Urgent.
    var urgentFrom: Int?

    // Urgency is a nudge number per step, not the mockup's `priorityAt` formula, which derives
    // it from where the waits reach the floor. With the formula, tuning a factor or floor would
    // quietly move "Urgent from nudge 4" and could make Gentle ring. Here those rules are
    // written down and tuned on their own.

    static let gentle = Ladder(highFrom: 5, urgentFrom: nil)
    static let firm = Ladder(highFrom: 3, urgentFrom: 4)
    static let relentless = Ladder(highFrom: 1, urgentFrom: 4)
}

extension Strength {
    var ladder: Ladder {
        switch self {
        case .gentle: .gentle
        case .firm: .firm
        case .relentless: .relentless
        }
    }

    /// The urgency of a nudge, as in the mockup's How It Nudges table.
    func urgency(ofNudge nudgeNumber: Int) -> Urgency {
        if let urgentFrom = ladder.urgentFrom, nudgeNumber >= urgentFrom { return .urgent }
        return nudgeNumber >= ladder.highFrom ? .high : .normal
    }
}
