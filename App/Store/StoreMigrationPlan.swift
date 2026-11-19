import Foundation
import SwiftData

/// 1.5.0's store: schema version 4, which adds a reminder's alarm sound. Its records are the
/// current top-level ones in `StoredRecords.swift`; the earlier versions' are nested in
/// `StoreSchemaV1`, `StoreSchemaV2` and `StoreSchemaV3`.
enum StoreSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ReminderRecord.self, ClosedOccurrenceRecord.self, PauseSpanRecord.self, ReplacedTitleRecord.self, TagRecord.self]
    }
}

/// Opens a store saved under an older schema. Every stage is lightweight: each adds optional or
/// defaulted properties. The instant 1.2.0's reminders get as a creation date is set by
/// `ReminderStore.backfillCreationDates`; a reminder of the person's own gets no origin, which
/// reads as mine; every reminder saved before alarm sounds gets Default.
enum StoreMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [StoreSchemaV1.self, StoreSchemaV2.self, StoreSchemaV3.self, StoreSchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: StoreSchemaV1.self, toVersion: StoreSchemaV2.self),
            .lightweight(fromVersion: StoreSchemaV2.self, toVersion: StoreSchemaV3.self),
            .lightweight(fromVersion: StoreSchemaV3.self, toVersion: StoreSchemaV4.self),
        ]
    }
}
