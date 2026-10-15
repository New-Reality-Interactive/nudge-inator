/// One due instance of a reminder.
public struct Occurrence: Equatable, Sendable {
    public var state: OccurrenceState
}

/// Where an occurrence is in its life.
public enum OccurrenceState: Equatable, Sendable {
    /// Come due and not yet Done. `nudgeNumber` is the latest nudge sent, counting from 1.
    case nudging(nudgeNumber: Int)
}
