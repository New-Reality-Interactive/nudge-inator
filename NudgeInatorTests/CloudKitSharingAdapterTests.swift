import CloudKit
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The real adapter over two real `CKSyncEngine`s, one per database, with `automaticallySync` off
/// so nothing reaches the network (#216, seam 2): what a change puts in each engine's pending
/// changes, the batch the engine would send, and what a relaunch hands a new engine. What iCloud
/// does with it is a two-account check (#218 to #220).
@MainActor
struct CloudKitSharingAdapterTests {
    let connectionID = UUID()
    let reminderID = UUID()
    let events = RecordingSharingEvents()

    func startedAdapter() -> CloudKitSharingAdapter {
        let container = CKContainer(identifier: CloudKitSharingAdapter.containerIdentifier)
        let adapter = CloudKitSharingAdapter(reader: CloudKitAccountReader(source: container), container: container, automaticallySync: false)
        adapter.events = events
        adapter.start()
        return adapter
    }

    func sent() -> SentReminder {
        SentReminder(reminder: Reminder(id: reminderID, title: "Water the plants", dueTime: Date(timeIntervalSinceReferenceDate: 815_000_000), strength: .firm), revision: 0)
    }

    func recordName(_ type: String) -> String {
        "\(type).owner.\(reminderID.uuidString)"
    }

    @Test func thereIsOneEnginePerDatabase() throws {
        let adapter = startedAdapter()

        #expect(adapter.engines[.private]?.database.databaseScope == .private)
        #expect(adapter.engines[.shared]?.database.databaseScope == .shared)
    }

    @Test func aChangeBecomesTheEnginesPendingSaveInTheConnectionsZone() throws {
        let adapter = startedAdapter()
        let zoneID = try #require(adapter.sync).makeZone(for: connectionID)

        adapter.submit(.send(sent(), to: connectionID))

        let engine = try #require(adapter.engines[.private])
        #expect(engine.state.pendingRecordZoneChanges == [.saveRecord(CKRecord.ID(recordName: recordName("SentReminder"), zoneID: zoneID))])
        #expect(engine.state.pendingDatabaseChanges.map(\.zoneID) == [zoneID])
        #expect(adapter.engines[.shared]?.state.pendingRecordZoneChanges.isEmpty == true)
    }

    @Test func theBatchCarriesTheRecordsInOrder() async throws {
        let adapter = startedAdapter()
        let sync = try #require(adapter.sync)
        sync.makeZone(for: connectionID)
        let report = StatusReport(label: .nudging, occurrences: [
            StatusReport.OccurrenceStatus(dueTime: Date(timeIntervalSinceReferenceDate: 815_000_000), day: CalendarDay(year: 2026, month: 10, day: 10), label: .done),
        ])
        adapter.submit(.status(SentCopy.StatusRecord(report: report, notSharingThisOne: false), for: reminderID, from: connectionID))
        let engine = try #require(adapter.engines[.private])

        let batch = await adapter.batch(of: sync.ordered(engine.state.pendingRecordZoneChanges), sync: sync)

        #expect(batch?.recordsToSave.map(\.recordID.recordName) == [recordName("Status"), recordName("OccurrenceStatus") + ".0"])
        #expect(batch?.recordsToSave.first?.encryptedValues["label"] as? String != nil)
    }

    @Test func aSharingStoreThatWontOpenStartsNothingUntilItDoes() throws {
        events.storeOpens = false
        let adapter = startedAdapter()
        #expect(adapter.sync == nil)

        events.storeOpens = true
        adapter.start()

        #expect(adapter.engines.count == 2)
    }

    @Test func whatWasUnsentIsHandedToTheEnginesAfterARelaunch() throws {
        let adapter = startedAdapter()
        let zoneID = try #require(adapter.sync).makeZone(for: connectionID)
        adapter.submit(.send(sent(), to: connectionID))

        let relaunched = startedAdapter()

        let engine = try #require(relaunched.engines[.private])
        #expect(engine.state.pendingRecordZoneChanges.contains(.saveRecord(CKRecord.ID(recordName: recordName("SentReminder"), zoneID: zoneID))))
    }
}

