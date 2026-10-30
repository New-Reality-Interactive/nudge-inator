import Foundation
import NudgeEngine
import SwiftData
@testable import NudgeInator

/// A store file as 1.2.0 saved it, written with schema version 1, for the tests that open it with
/// version 2.
@MainActor
enum Version1Store {
    /// Writes `reminders` in the order given, as 1.2.0 saved them, and closes the file.
    static func write(to fileURL: URL, reminders: [Reminder], tags: [Tag], histories: [Reminder.ID: ReminderHistory]) throws {
        let schema = Schema(versionedSchema: StoreSchemaV1.self)
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: fileURL, cloudKitDatabase: .none))
        let context = container.mainContext
        for (position, reminder) in reminders.enumerated() {
            let record = StoreSchemaV1.ReminderRecord(id: reminder.id, position: position)
            record.title = reminder.title
            record.notes = reminder.notes
            record.tagIDs = reminder.tagIDs
            record.dueTime = reminder.dueTime
            record.repeatRule = reminder.repeatRule?.rrule
            record.repeatMissingDay = reminder.repeatRule.map { _ in "skip" }
            record.strength = switch reminder.strength {
            case .gentle: "gentle"
            case .firm: "firm"
            case .relentless: "relentless"
            }
            if case .consistent(let wait) = reminder.pace {
                record.paceKind = "consistent"
                record.paceWait = wait
            }
            record.breakThroughFocus = reminder.breakThroughFocus
            context.insert(record)
            guard let history = histories[reminder.id] else { continue }
            for (dueTime, closing) in history.closedOccurrences {
                let state = switch closing.state {
                case .done: "done"
                default: "missed.giveUpLimit"
                }
                record.closedOccurrences.append(StoreSchemaV1.ClosedOccurrenceRecord(
                    dueTime: dueTime, state: state, nudgeNumber: nil, closedAt: closing.closedAt, nudgesSent: closing.nudgesSent
                ))
            }
            for (position, span) in history.pauseSpans.enumerated() {
                record.pauseSpans.append(StoreSchemaV1.PauseSpanRecord(position: position, start: span.start, end: span.end))
            }
            for (position, title) in history.replacedTitles.enumerated() {
                record.replacedTitles.append(StoreSchemaV1.ReplacedTitleRecord(position: position, title: title.value, replacedAt: title.replacedAt))
            }
            record.editAppliesAfter = history.editAppliesAfter
        }
        for (position, tag) in tags.enumerated() {
            context.insert(StoreSchemaV1.TagRecord(id: tag.id, position: position, name: tag.name))
        }
        try context.save()
    }
}
