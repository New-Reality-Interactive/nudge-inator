import Foundation

/// One due instance of a reminder.
public struct Occurrence: Equatable, Sendable {
    public var dueTime: Date
    public var state: OccurrenceState
}

/// Where an occurrence is in its life.
public enum OccurrenceState: Equatable, Sendable {
    /// Come due and not yet Done. `nudgeNumber` is the latest nudge sent, counting from 1.
    case nudging(nudgeNumber: Int)
    /// Closed by the person's Done, the only way to close it as Done.
    case done
    /// Closed without Done.
    case missed(reason: MissedReason)
}

/// Why an occurrence closed as Missed.
public enum MissedReason: Equatable, Sendable {
    /// It reached the give-up limit.
    case giveUpLimit
}
