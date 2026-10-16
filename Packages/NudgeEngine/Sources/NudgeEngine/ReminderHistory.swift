import Foundation

/// What the engine records about a reminder because the clock can't work it out, in the form the
/// store saves and hands back at launch.
public struct ReminderHistory: Equatable, Sendable {
    /// Occurrences whose state is fixed, by due time, with how they closed. Done is the one the
    /// clock can never work out. An occurrence already closed when an Edit is applied is fixed
    /// too, since the clock would now work it out from the edited fields: the latest, and every
    /// one the Now tab's Last 24 Hours can still list. Keyed by due time, so Done on one day's
    /// occurrence of a repeat leaves the next day's open. A fixed one stays even when an Edit
    /// moves the due times away from it.
    public var closedOccurrences: [Date: Closing]
    /// The latest occurrence's due time when an Edit last changed the due time, repeat or
    /// strength. The Edit applies from the next occurrence, so the edited fields' due times up to
    /// this one never happened; the ones that did are in `closedOccurrences`. A due time the Edit
    /// moved to after it, even one already past, is the next occurrence (ticket 13).
    public var editAppliesAfter: Date?
    /// Every pause, oldest first, the last still open while it's paused. An occurrence still open
    /// during a pause is Skipped, so a due time that passed while paused never comes back as
    /// Nudging after Resume.
    public var pauseSpans: [PauseSpan]
    /// Earlier titles, oldest first, with when an Edit replaced them. A nudge that fired before the
    /// Edit was delivered with the old title, so its plan item keeps it.
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
