import Foundation
import SwiftData

/// The sharing store's schema, version 1: new in 1.4.0, so nothing is older to migrate from.
enum SharingSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ConnectionRecord.self, SentReminderRecord.self, SentCopyRecord.self, SentCopyOccurrenceRecord.self,
         ReceivedSyncRecord.self, SyncEngineStateRecord.self, OutboxRecord.self]
    }
}

/// Opens the sharing store. It has no stages yet: the first change to the schema after 1.4.0 adds
/// the next version and the stage to it, as `StoreMigrationPlan` does for the reminder store.
enum SharingMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SharingSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
