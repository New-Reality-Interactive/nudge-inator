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
    /// Closed without Done, and not counted against the person as Missed is.
    case skipped(reason: SkippedReason)
}

/// Why an occurrence closed as Missed.
public enum MissedReason: Equatable, Sendable {
    /// It reached the give-up limit.
    case giveUpLimit
    /// The next occurrence of its repeat fell due while it was still Nudging.
    case nextTookOver
}

/// Why an occurrence closed as Skipped.
public enum SkippedReason: Equatable, Sendable {
    /// Its reminder was paused while it was Nudging, or it fell due while the reminder was paused.
    case paused
}
