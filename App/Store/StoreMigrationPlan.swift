import Foundation
import SwiftData

/// 1.3.0's store: schema version 2, which adds the reminder's creation date. Its records are the
/// current top-level ones in `StoredRecords.swift`; version 1's are nested in `StoreSchemaV1`.
enum StoreSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ReminderRecord.self, ClosedOccurrenceRecord.self, PauseSpanRecord.self, ReplacedTitleRecord.self, TagRecord.self]
    }
}

/// Opens a store saved under an older schema. Adding the creation date is lightweight; the instant
/// 1.2.0's reminders get is set by `ReminderStore.backfillCreationDates`.
enum StoreMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [StoreSchemaV1.self, StoreSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: StoreSchemaV1.self, toVersion: StoreSchemaV2.self)]
    }
}
