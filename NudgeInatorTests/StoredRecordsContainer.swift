import Foundation
import SwiftData
@testable import NudgeInator

/// Opens the store file at `url` for its raw records, as a test that reads or damages a saved
/// field does. It uses the current schema, with no migration plan.
func openStoredRecords(at url: URL) throws -> ModelContainer {
    try ModelContainer(
        for: ReminderRecord.self, ClosedOccurrenceRecord.self, PauseSpanRecord.self, ReplacedTitleRecord.self, TagRecord.self,
        configurations: ReminderStore.configuration(for: .file(url))
    )
}
