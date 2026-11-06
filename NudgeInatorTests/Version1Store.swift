import Foundation
import NudgeEngine
import SwiftData
@testable import NudgeInator

/// A store file as 1.2.0 saved it, written with schema version 1, for the tests that open it with
/// version 2. It spells every value the way 1.2.0 did, on its own, never through the app's current
/// mapping: a change there must not change what a 1.2.0 phone holds. It writes every closing state,
/// repeat shape and field 1.2.0 could save.
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
            record.repeatMissingDay = reminder.repeatRule.map { rule in
                switch rule.missingDay {
                case .skip: "skip"
                case .lastDayOfMonth: "lastDayOfMonth"
                }
            }
            // RRULE text keeps UNTIL to the second, so 1.2.0 saved the exact instant beside it.
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
            context.insert(record)
            guard let history = histories[reminder.id] else { continue }
            for (dueTime, closing) in history.closedOccurrences {
                let (state, nudgeNumber) = Self.spelling(of: closing.state)
                record.closedOccurrences.append(StoreSchemaV1.ClosedOccurrenceRecord(
                    dueTime: dueTime, state: state, nudgeNumber: nudgeNumber, closedAt: closing.closedAt, nudgesSent: closing.nudgesSent
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

    /// A closing's state as 1.2.0 spelled it. A Nudging state, which a closing never has but the
    /// engine's type allows, keeps its number beside it.
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
