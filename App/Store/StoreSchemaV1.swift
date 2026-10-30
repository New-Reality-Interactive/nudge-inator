import Foundation
import SwiftData

/// 1.2.0's store, frozen: schema version 1. The migration plan reads a store saved by 1.2.0 with
/// it, so these records must never change. A change to the store is a new schema version beside
/// this one, with a stage in `StoreMigrationPlan`.
enum StoreSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ReminderRecord.self, ClosedOccurrenceRecord.self, PauseSpanRecord.self, ReplacedTitleRecord.self, TagRecord.self]
    }

    @Model
    final class ReminderRecord: IdentifiedRecord {
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
        /// The exact instant of an UNTIL that ends at a time. RRULE text keeps only whole seconds.
        var repeatUntilTime: Date?
        var strength: String
        /// The pace's kind, as `Pace`'s stored spelling. Both pace properties carry default values so
        /// SwiftData opens a store saved before paces existed (no migration: the beta reinstalls).
        var paceKind: String = "escalating"
        /// The wait a Consistent pace carries, in seconds: `nil` for Escalating, whose waits come from
        /// the strength.
        var paceWait: Double?
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
    final class TagRecord: IdentifiedRecord {
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

    /// One pause of a reminder.
    @Model
    final class PauseSpanRecord {
        var reminder: ReminderRecord?
        /// Its place in the history, oldest first. A relationship has no order, and two pauses can
        /// start in the same instant (Pause, Resume, Pause), where only the order says which is open.
        var position: Int
        var start: Date
        var end: Date?

        init(position: Int, start: Date, end: Date?) {
            self.position = position
            self.start = start
            self.end = end
        }
    }

    /// An earlier title, with when an Edit replaced it.
    @Model
    final class ReplacedTitleRecord {
        var reminder: ReminderRecord?
        /// Its place in the history, oldest first, as for `PauseSpanRecord`.
        var position: Int
        var title: String
        var replacedAt: Date

        init(position: Int, title: String, replacedAt: Date) {
            self.position = position
            self.title = title
            self.replacedAt = replacedAt
        }
    }
}
