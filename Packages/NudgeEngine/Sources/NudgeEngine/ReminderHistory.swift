import Foundation

/// What the engine records about a reminder because the clock can't work it out, in the form the
/// store saves and hands back at launch.
public struct ReminderHistory: Equatable, Sendable {
    /// Occurrences whose state is fixed, by due time: Done, and Missed or Skipped fixed by an Edit.
    public var closedOccurrences: [Date: Closing]
    /// The latest occurrence's due time when an Edit last changed the due time, repeat or strength.
    /// The edited fields' due times up to it never happened.
    public var editAppliesAfter: Date?
    /// Every pause, oldest first, the last still open while the reminder is paused.
    public var pauseSpans: [PauseSpan]
    /// Earlier titles, oldest first, with when an Edit replaced them.
    public var replacedTitles: [Replaced<String>]

    public init(
        closedOccurrences: [Date: Closing] = [:],
        editAppliesAfter: Date? = nil,
        pauseSpans: [PauseSpan] = [],
        replacedTitles: [Replaced<String>] = []
    ) {
        self.closedOccurrences = closedOccurrences
        self.editAppliesAfter = editAppliesAfter
        self.pauseSpans = pauseSpans
        self.replacedTitles = replacedTitles
    }
}

/// One pause of a reminder: from Pause to Resume.
public struct PauseSpan: Equatable, Sendable {
    public var start: Date
    /// `nil` until Resume.
    public var end: Date?

    public init(start: Date, end: Date? = nil) {
        self.start = start
        self.end = end
    }
}
