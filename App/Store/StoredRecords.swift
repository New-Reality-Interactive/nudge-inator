import Foundation
import SwiftData

/// A reminder as SwiftData saves it. The store maps it to and from the engine's `Reminder`, so
/// the engine stays free of SwiftData.
@Model
final class ReminderRecord {
    @Attribute(.unique) var id: UUID
    /// The reminder's place in the list, which a relationship-free fetch doesn't keep.
    var position: Int
    var title: String
    var notes: String
    /// An array, not a relationship: SwiftData's to-many relationships have no order, and the
    /// engine's `tagIDs` does.
    var tagIDs: [UUID]
    var dueTime: Date
    /// The repeat as RRULE text, `nil` for Never.
    var repeatRule: String?
    /// The repeat's `missingDay`, which RRULE has no part for: it is what tells a preset from the
    /// custom rule with the same parts.
    var repeatMissingDay: String?
    var strength: String
    var breakThroughFocus: Bool
    /// Its history goes with it: Delete clears a reminder's whole history (ticket 12).
    @Relationship(deleteRule: .cascade, inverse: \ClosedOccurrenceRecord.reminder)
    var closedOccurrences: [ClosedOccurrenceRecord] = []
    @Relationship(deleteRule: .cascade, inverse: \PauseSpanRecord.reminder)
    var pauseSpans: [PauseSpanRecord] = []
    @Relationship(deleteRule: .cascade, inverse: \ReplacedTitleRecord.reminder)
    var replacedTitles: [ReplacedTitleRecord] = []
    /// The engine's `editAppliesAfter`: the edited fields' due times up to it never happened.
    var editAppliesAfter: Date?

    init(id: UUID, position: Int) {
        self.id = id
        self.position = position
        title = ""
        notes = ""
        tagIDs = []
        dueTime = .distantPast
        strength = ""
        breakThroughFocus = true
    }
}

/// A tag as SwiftData saves it.
@Model
final class TagRecord {
    @Attribute(.unique) var id: UUID
    var position: Int
    var name: String

    init(id: UUID, position: Int, name: String) {
        self.id = id
        self.position = position
        self.name = name
    }
}

/// An occurrence whose state the clock can't work out: Done, or Missed or Skipped fixed by an Edit.
@Model
final class ClosedOccurrenceRecord {
    var reminder: ReminderRecord?
    var dueTime: Date
    /// `OccurrenceState` as the store spells it.
    var state: String
    /// Only for a Nudging state, which a closing never has, but the engine's type allows.
    var nudgeNumber: Int?
    var closedAt: Date
    var nudgesSent: Int

    init(dueTime: Date, state: String, nudgeNumber: Int?, closedAt: Date, nudgesSent: Int) {
        self.dueTime = dueTime
        self.state = state
        self.nudgeNumber = nudgeNumber
        self.closedAt = closedAt
        self.nudgesSent = nudgesSent
    }
}

/// One pause of a reminder. A relationship has no order, so the store sorts by `start` to read
/// them back oldest first.
@Model
final class PauseSpanRecord {
    var reminder: ReminderRecord?
    var start: Date
    var end: Date?

    init(start: Date, end: Date?) {
        self.start = start
        self.end = end
    }
}

/// An earlier title, with when an Edit replaced it. Sorted by `replacedAt` to read back oldest
/// first.
@Model
final class ReplacedTitleRecord {
    var reminder: ReminderRecord?
    var title: String
    var replacedAt: Date

    init(title: String, replacedAt: Date) {
        self.title = title
        self.replacedAt = replacedAt
    }
}
