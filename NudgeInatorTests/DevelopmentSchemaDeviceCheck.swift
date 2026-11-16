import CloudKit
import Foundation
import Testing
@testable import NudgeInator

/// #327's device check: puts every sharing record type and field into the development schema, so
/// the deploy to production carries them all. A Debug build on the iPhone talks to the development
/// environment. It saves `DevelopmentSchemaSample` to a zone of its own in the signed-in account's
/// private database, reads it back, and deletes that zone even when a step fails, so it leaves only
/// the schema behind. It runs only when asked (`TEST_RUNNER_NUDGE_DEV_SCHEMA=1`): it writes to iCloud.
@Suite(.enabled(if: DeviceCheck.isPhysicalDevice && ProcessInfo.processInfo.environment["NUDGE_DEV_SCHEMA"] == "1",
                "Writes to the development iCloud; run on the iPhone with TEST_RUNNER_NUDGE_DEV_SCHEMA=1"))
@MainActor
struct DevelopmentSchemaDeviceCheck {
    @Test func everyRecordTypeAndFieldIsSavedToDevelopment() async throws {
        let container = CKContainer(identifier: CloudKitSharingAdapter.containerIdentifier)
        try #require(try await container.accountStatus() == .available, "Sign in to iCloud on the iPhone")
        let database = container.privateCloudDatabase
        let zone = CKRecordZone(zoneName: UUID().uuidString)

        do {
            let made = try await database.modifyRecordZones(saving: [zone], deleting: [])
            _ = try made.saveResults[zone.zoneID]?.get()
            try await saveAndReadBack(in: zone.zoneID, database: database)
        } catch {
            Issue.record(error, "The schema check failed")
        }
        // The zone and every record in it go, whatever happened above. A zone's own result comes
        // back in the results, not as a thrown error.
        do {
            let removed = try await database.modifyRecordZones(saving: [], deleting: [zone.zoneID])
            try removed.deleteResults[zone.zoneID]?.get()
        } catch {
            Issue.record(error, "Zone \(zone.zoneID.zoneName) wasn't deleted: delete it in the CloudKit Console")
        }
    }

    private func saveAndReadBack(in zoneID: CKRecordZone.ID, database: CKDatabase) async throws {
        let records = try DevelopmentSchemaSample.records(in: zoneID)
        // A refused record comes back in its own result, not as a thrown error.
        let saved = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys, atomically: true)
        for (id, result) in saved.saveResults {
            if case .failure(let error) = result { Issue.record("\(id.recordName) wasn't saved: \(error)") }
        }

        let read = try await database.records(for: records.map(\.recordID))
        var fields: Set<String> = []
        for (id, result) in read {
            switch result {
            case .success(let record): fields.formUnion(DevelopmentSchemaSample.fields(of: record))
            case .failure(let error): Issue.record("\(id.recordName) wasn't read back: \(error)")
            }
        }
        #expect(fields == Set(SharingRecordMapping.fieldNames))
    }
}
