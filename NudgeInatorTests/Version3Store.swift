import Foundation
import NudgeEngine
import SwiftData
@testable import NudgeInator

/// A store file as 1.4.0 saved it, written with schema version 3, for the tests that open it with
/// version 4. Like `Version2Store`, it spells every value the way 1.4.0 did, on its own, never
/// through the app's current mapping: a change there must not change what a 1.4.0 phone holds. It
/// writes the creation date and the origin, and no alarm sound, since 1.4.0 had none.
@MainActor
enum Version3Store {
    /// Writes `reminders` in the order given, with their creation dates, as 1.4.0 saved them.
    static func write(to fileURL: URL, reminders: [Reminder], tags: [Tag], histories: [Reminder.ID: ReminderHistory]) throws {
        let schema = Schema(versionedSchema: StoreSchemaV3.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: fileURL, cloudKitDatabase: .none))
        let context = container.mainContext
        for (position, reminder) in reminders.enumerated() {
            let record = StoreSchemaV3.ReminderRecord(id: reminder.id, position: position)
            record.title = reminder.title
            record.notes = reminder.notes
            record.tagIDs = reminder.tagIDs
            record.dueTime = reminder.dueTime
            record.repeatRule = reminder.repeatRule?.rrule
            record.repeatMissingDay = reminder.repeatRule.map { rule in
                switch rule.missingDay {
                case .skip: "skip"
                case .lastDayOfMonth: "lastDayOfMonth"
                }
            }
            if case .untilTime(let time)? = reminder.repeatRule?.end { record.repeatUntilTime = time }
            record.strength = switch reminder.strength {
            case .gentle: "gentle"
            case .firm: "firm"
            case .relentless: "relentless"
            }
            switch reminder.pace {
            case .escalating:
                record.paceKind = "escalating"
            case .consistent(let wait):
                record.paceKind = "consistent"
                record.paceWait = wait
            }
            record.breakThroughFocus = reminder.breakThroughFocus
            record.createdAt = reminder.createdAt
            if case let .received(connectionID, sendersReminderID, revision, state, originalDueTime) = reminder.origin {
                record.receivedConnectionID = connectionID
                record.receivedSendersReminderID = sendersReminderID
                record.receivedRevision = revision
                record.receivedState = switch state {
                case .accepted: "accepted"
                case .waiting: "waiting"
                case .canceled: "canceled"
                }
                record.receivedOriginalDueTime = originalDueTime
            }
            context.insert(record)
            guard let history = histories[reminder.id] else { continue }
            for (dueTime, closing) in history.closedOccurrences {
                let (state, nudgeNumber) = Self.spelling(of: closing.state)
                record.closedOccurrences.append(StoreSchemaV3.ClosedOccurrenceRecord(
                    dueTime: dueTime, state: state, nudgeNumber: nudgeNumber, closedAt: closing.closedAt, nudgesSent: closing.nudgesSent
                ))
            }
            for (position, span) in history.pauseSpans.enumerated() {
                record.pauseSpans.append(StoreSchemaV3.PauseSpanRecord(position: position, start: span.start, end: span.end))
            }
            for (position, title) in history.replacedTitles.enumerated() {
                record.replacedTitles.append(StoreSchemaV3.ReplacedTitleRecord(position: position, title: title.value, replacedAt: title.replacedAt))
            }
            record.editAppliesAfter = history.editAppliesAfter
        }
        for (position, tag) in tags.enumerated() {
            context.insert(StoreSchemaV3.TagRecord(id: tag.id, position: position, name: tag.name))
        }
        try context.save()
    }

    /// A closing's state as 1.4.0 spelled it.
    private static func spelling(of state: OccurrenceState) -> (state: String, nudgeNumber: Int?) {
        switch state {
        case .nudging(let nudgeNumber): ("nudging", nudgeNumber)
        case .done: ("done", nil)
        case .missed(.giveUpLimit): ("missed.giveUpLimit", nil)
        case .missed(.nextTookOver): ("missed.nextTookOver", nil)
        case .skipped(.paused): ("skipped.paused", nil)
        }
    }
}
