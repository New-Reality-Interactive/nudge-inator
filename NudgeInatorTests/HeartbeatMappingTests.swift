import CloudKit
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The heartbeat's record mapping (#435, spec #127 seam 3): one more field on each person's
/// connection settings record, which iCloud timestamps when it is saved. No network.
struct HeartbeatMappingTests {
    let connectionID = UUID()
    let writer: SharingRecordMapping
    let reader: SharingRecordMapping
    let iCloudTime = Date(timeIntervalSinceReferenceDate: 815_000_000)

    init() throws {
        writer = try #require(SharingRecordMapping(zoneID: CKRecordZone.ID(zoneName: connectionID.uuidString, ownerName: CKCurrentUserDefaultName)))
        reader = try #require(SharingRecordMapping(zoneID: CKRecordZone.ID(zoneName: connectionID.uuidString, ownerName: "_theOwnersUserRecord")))
    }

    func settingsRecord(sharesStatus: Bool, existing: CKRecord? = nil) throws -> CKRecord {
        let change = SharingChange.settings(.init(ConnectionChoices(sharesStatus: sharesStatus)), for: connectionID)
        return try #require(try writer.writes(for: change, statusSharingOn: sharesStatus, existing: { _ in existing }).save.first)
    }

    /// What the reader reads, with iCloud stamping the record at `iCloudTime`.
    func lastSynced(of record: CKRecord) throws -> Date? {
        let fetched = SharingRecordMapping.FetchedRecord(record: record, writtenByOtherPerson: true, modifiedAt: iCloudTime)
        let change = try #require(reader.changes(from: [fetched]).first)
        guard case .settings(let settings) = change.content else { Issue.record("Not a settings change"); return nil }
        return settings.lastSynced
    }

    @Test func settingsWrittenWithStatusSharingOnCarryAHeartbeat() throws {
        let record = try settingsRecord(sharesStatus: true)

        #expect(record.encryptedValues["heartbeat"] != nil)
    }

    @Test func settingsWrittenWithStatusSharingOffClearTheHeartbeat() throws {
        let before = try settingsRecord(sharesStatus: true)
        let after = try settingsRecord(sharesStatus: false, existing: before)

        #expect(after.encryptedValues["heartbeat"] == nil)
    }

    @Test func eachHeartbeatDiffersFromTheOneBefore() throws {
        let first = try settingsRecord(sharesStatus: true)
        let firstValue = first.encryptedValues["heartbeat"] as? Int64
        let second = try settingsRecord(sharesStatus: true, existing: first)

        #expect(firstValue != nil)
        #expect(firstValue != second.encryptedValues["heartbeat"] as? Int64)
    }

    @Test func theOtherPersonReadsLastSyncedFromICloudsTimeOfTheRecord() throws {
        #expect(try lastSynced(of: settingsRecord(sharesStatus: true)) == iCloudTime)
    }

    @Test func settingsWithoutAHeartbeatGiveNoLastSynced() throws {
        #expect(try lastSynced(of: settingsRecord(sharesStatus: false)) == nil)
    }

    @Test func aHeartbeatOnItsOwnWritesOnlyTheHeartbeatOnARecordTheSyncHoldsNoFieldsOf() throws {
        let held = CKRecord(recordType: "ConnectionSettings", recordID: CKRecord.ID(recordName: "ConnectionSettings.owner", zoneID: writer.zoneID))
        let record = writer.heartbeat(existing: held, choices: ConnectionChoices(deliveryMode: .askMeFirst))

        #expect(Set(record.encryptedValues.allKeys()) == ["heartbeat"])
    }

    @Test func aHeartbeatOnItsOwnWritesThePersonsChoicesWhenNoRecordIsHeld() throws {
        let choices = ConnectionChoices(sharesStatus: true, deliveryMode: .askMeFirst)
        let record = writer.heartbeat(existing: nil, choices: choices)

        #expect(Set(record.encryptedValues.allKeys()) == ["sharesStatus", "deliveryMode", "heartbeat"])
        #expect(record.encryptedValues["deliveryMode"] as? String == choices.deliveryMode.storedValue)
        #expect(try lastSynced(of: record) == iCloudTime)
    }
}
