import Foundation
import SwiftData

/// 1.4.0's store: schema version 3, which adds a received reminder's origin. Its records are the
/// current top-level ones in `StoredRecords.swift`; version 1's and 2's are nested in
/// `StoreSchemaV1` and `StoreSchemaV2`.
enum StoreSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ReminderRecord.self, ClosedOccurrenceRecord.self, PauseSpanRecord.self, ReplacedTitleRecord.self, TagRecord.self]
    }
}

/// Opens a store saved under an older schema. Both stages are lightweight: each adds optional or
/// defaulted properties. The instant 1.2.0's reminders get as a creation date is set by
/// `ReminderStore.backfillCreationDates`; a reminder of the person's own gets no origin, which
/// reads as mine.
enum StoreMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [StoreSchemaV1.self, StoreSchemaV2.self, StoreSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: StoreSchemaV1.self, toVersion: StoreSchemaV2.self),
            .lightweight(fromVersion: StoreSchemaV2.self, toVersion: StoreSchemaV3.self),
        ]
    }
}
