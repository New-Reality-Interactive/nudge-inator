import Foundation
import SwiftData

/// 1.6.0's store: schema version 5, which adds how many of a fixed closing's nudges quiet hours
/// held. Its records are the current top-level ones in `StoredRecords.swift`; the earlier versions'
/// are nested in `StoreSchemaV1` to `StoreSchemaV4`.
enum StoreSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ReminderRecord.self, ClosedOccurrenceRecord.self, PauseSpanRecord.self, ReplacedTitleRecord.self, TagRecord.self]
    }
}

/// Opens a store saved under an older schema. Every stage is lightweight: each adds optional or
/// defaulted properties. The instant 1.2.0's reminders get as a creation date is set by
/// `ReminderStore.backfillCreationDates`; a reminder of the person's own gets no origin, which
/// reads as mine; every reminder saved before alarm sounds gets Default; every closing saved before
/// quiet hours gets no held count.
enum StoreMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [StoreSchemaV1.self, StoreSchemaV2.self, StoreSchemaV3.self, StoreSchemaV4.self, StoreSchemaV5.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: StoreSchemaV1.self, toVersion: StoreSchemaV2.self),
            .lightweight(fromVersion: StoreSchemaV2.self, toVersion: StoreSchemaV3.self),
            .lightweight(fromVersion: StoreSchemaV3.self, toVersion: StoreSchemaV4.self),
            .lightweight(fromVersion: StoreSchemaV4.self, toVersion: StoreSchemaV5.self),
        ]
    }
}
