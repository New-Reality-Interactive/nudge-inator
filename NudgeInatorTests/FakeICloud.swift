import CloudKit
import Foundation
import NudgeEngine
@testable import NudgeInator

/// Stands in for one database's `CKSyncEngine.State`: the changes waiting to go, in order.
@MainActor
final class FakePendingQueue: PendingChangeQueue {
    private(set) var pendingRecordZoneChanges: [CKSyncEngine.PendingRecordZoneChange] = []
    private(set) var pendingDatabaseChanges: [CKSyncEngine.PendingDatabaseChange] = []

    func add(pendingRecordZoneChanges changes: [CKSyncEngine.PendingRecordZoneChange]) {
        for change in changes where !pendingRecordZoneChanges.contains(change) {
            pendingRecordZoneChanges.append(change)
        }
    }

    func remove(pendingRecordZoneChanges changes: [CKSyncEngine.PendingRecordZoneChange]) {
        pendingRecordZoneChanges.removeAll { changes.contains($0) }
    }

    func add(pendingDatabaseChanges changes: [CKSyncEngine.PendingDatabaseChange]) {
        for change in changes {
            pendingDatabaseChanges.removeAll { $0.zoneID == change.zoneID }
            pendingDatabaseChanges.append(change)
        }
    }

    func takeDatabaseChanges() -> [CKSyncEngine.PendingDatabaseChange] {
        defer { pendingDatabaseChanges = [] }
        return pendingDatabaseChanges
    }

    /// Empties both lists, as an engine made with no saved state, or reset by an account change,
    /// holds nothing.
    func empty() {
        pendingRecordZoneChanges = []
        pendingDatabaseChanges = []
    }
}

extension CKSyncEngine.PendingDatabaseChange {
    var zoneID: CKRecordZone.ID? {
        switch self {
        case .saveZone(let zone): zone.zoneID
        case .deleteZone(let zoneID): zoneID
        @unknown default: nil
        }
    }
}

/// Stands in for iCloud between two people's iPhones for `CloudKitSync` (#216, the WWDC23
/// two-engine pattern driven by hand): one connection zone per connection, in the inviter's private
/// database and shared with the invitee. It keeps a version per record and refuses a save made on
/// an older one with `serverRecordChanged`, as iCloud's change tags do, and a save to a zone that
/// isn't there with `zoneNotFound`. Nothing moves until a test calls `send()` or `fetch()`.
@MainActor
final class FakeICloud {
    struct Stored {
        var type: String
        var fields: [String: CloudKitSyncCache.StoredField]
        var version: Int
        weak var writer: FakeSyncDevice?
    }

    enum Entry {
        case record(zone: String, name: String)
        case zoneDeleted(String)
    }

    /// The zones that exist, by name, each with its inviter and the invitee it's shared with.
    fileprivate var zones: [String: (owner: FakeSyncDevice, invitee: FakeSyncDevice?)] = [:]
    fileprivate var records: [String: [String: Stored]] = [:]
    /// Every change, in order, for the devices' fetches to read on from.
    fileprivate var log: [Entry] = []
    /// The next zone save fails as an iCloud Keychain reset leaves it.
    var resetsEncryptedData: Set<String> = []
    /// The next save of each record named here is refused with its error.
    var refusals: [String: CKError.Code] = [:]

    /// The invitee accepted the share of the inviter's zone.
    func share(_ connectionID: UUID, with invitee: FakeSyncDevice) {
        zones[connectionID.uuidString]?.invitee = invitee
    }

    /// The record as iCloud holds it now, or `nil`.
    func stored(_ connectionID: UUID, _ recordName: String) -> Stored? {
        records[connectionID.uuidString]?[recordName]
    }

    /// Another of the writer's devices saved the record since: its version moves on.
    func changeElsewhere(_ connectionID: UUID, _ recordName: String) {
        records[connectionID.uuidString]?[recordName]?.version += 1
    }

    /// iCloud loses a zone, as an iCloud Keychain reset leaves it for its owner.
    func loseZone(_ connectionID: UUID) {
        zones[connectionID.uuidString] = nil
        records[connectionID.uuidString] = nil
    }
}

/// One person's iPhone as `CloudKitSync` sees it: the sync and its two databases' queues.
@MainActor
final class FakeSyncDevice {
    let icloud: FakeICloud
    /// What this device's zones in the shared database are owned by: the inviter's user record.
    let userRecordName: String
    private(set) var sync: CloudKitSync
    let privateQueue = FakePendingQueue()
    let sharedQueue = FakePendingQueue()
    /// The other person's changes, as fetched.
    private(set) var received: [SharingChange] = []
    /// The outbox IDs reported as gone, in order.
    private(set) var sentIDs: [UUID] = []
    /// Which version of each record this device last saw, as a change tag says.
    private var seen: [String: Int] = [:]
    private var cursor = 0
    /// What the latest send was refused, for a test to look at.
    private(set) var lastFailures: [CKError.Code] = []
    /// The most records one send carries, as a batch stops at its size limit; `nil` for no limit.
    var batchLimit: Int?

    init(icloud: FakeICloud, userRecordName: String) {
        self.icloud = icloud
        self.userRecordName = userRecordName
        sync = CloudKitSync()
        attach()
    }

    private func attach() {
        sync.attach(privateQueue, for: .private)
        sync.attach(sharedQueue, for: .shared)
    }

    /// The app relaunched: a new sync over what was kept, and queues as new engines' with no
    /// saved state hold nothing.
    func relaunch() {
        privateQueue.empty()
        sharedQueue.empty()
        sync = CloudKitSync(cache: sync.cache)
        attach()
    }

    /// An account change, which empties the engines' queues as `CKSyncEngine` does.
    func accountChanged(_ change: CloudKitSync.AccountChange) {
        privateQueue.empty()
        sharedQueue.empty()
        sync.accountChanged(change)
    }

    private func take(_ outcome: CloudKitSync.Outcome) {
        received += outcome.received
        sentIDs += outcome.gone
    }

    func submit(_ change: SharingChange) {
        sentIDs += sync.submit(change)
    }

    func zoneID(_ connectionID: UUID, owner: FakeSyncDevice) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: connectionID.uuidString, ownerName: owner === self ? CKCurrentUserDefaultName : owner.userRecordName)
    }

    /// Sends everything waiting, as each engine would: zones first, then records in batches.
    func send() {
        lastFailures = []
        var savedZones: [CKRecordZone.ID] = []
        var deletedZones: [CKRecordZone.ID] = []
        for change in privateQueue.takeDatabaseChanges() {
            switch change {
            case .saveZone(let zone):
                icloud.zones[zone.zoneID.zoneName] = icloud.zones[zone.zoneID.zoneName] ?? (self, nil)
                savedZones.append(zone.zoneID)
            case .deleteZone(let zoneID):
                icloud.zones[zoneID.zoneName] = nil
                icloud.records[zoneID.zoneName] = nil
                icloud.log.append(.zoneDeleted(zoneID.zoneName))
                deletedZones.append(zoneID)
            @unknown default: break
            }
        }
        take(sync.sentZones(saved: savedZones, deleted: deletedZones, failedSaves: [:], failedDeletes: [:]))
        for queue in [privateQueue, sharedQueue] {
            let batch = Array(sync.ordered(queue.pendingRecordZoneChanges).prefix(batchLimit ?? .max))
            queue.remove(pendingRecordZoneChanges: batch)
            var saved: [CKRecord] = []
            var failedSaves: [CloudKitSync.FailedSave] = []
            var deleted: [CKRecord.ID] = []
            var failedDeletes: [CKRecord.ID: CKError] = [:]
            for change in batch {
                switch change {
                case .saveRecord(let id):
                    guard let record = sync.record(for: id) else { continue }
                    if let error = save(record) {
                        failedSaves.append(.init(record: record, error: error))
                    } else {
                        saved.append(record)
                    }
                case .deleteRecord(let id):
                    if let error = delete(id) { failedDeletes[id] = error } else { deleted.append(id) }
                @unknown default: break
                }
            }
            lastFailures += failedSaves.map(\.error.code) + failedDeletes.values.map(\.code)
            // The engine keeps what it retries itself.
            let retried: Set<CKError.Code> = [.networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited]
            queue.add(pendingRecordZoneChanges: failedSaves.filter { retried.contains($0.error.code) }.map { .saveRecord($0.record.recordID) })
            take(sync.sent(saved: saved, failedSaves: failedSaves, deleted: deleted, failedDeletes: failedDeletes))
        }
    }

    private func canReach(_ zoneName: String) -> Bool {
        guard let zone = icloud.zones[zoneName] else { return false }
        return zone.owner === self || zone.invitee === self
    }

    private func save(_ record: CKRecord) -> CKError? {
        let zone = record.recordID.zoneID.zoneName, name = record.recordID.recordName
        guard canReach(zone) else {
            var info: [String: Any] = [:]
            if icloud.resetsEncryptedData.remove(zone) != nil { info[CKErrorUserDidResetEncryptedDataKey] = true }
            return CKError(.zoneNotFound, userInfo: info)
        }
        if let code = icloud.refusals.removeValue(forKey: name) {
            return CKError(code)
        }
        let key = "\(zone)/\(name)"
        if let current = icloud.records[zone]?[name], seen[key] != current.version {
            // The error carries iCloud's record, and with it the change tag the retry is made on.
            seen[key] = current.version
            return CKError(.serverRecordChanged, userInfo: [CKRecordChangedErrorServerRecordKey: rebuilt(current, name: name, zone: zone)])
        }
        // The sync writes every field of its records, clearing those it no longer has.
        let fields = CloudKitSyncCache.StoredField.fields(of: record)
        let version = (icloud.records[zone]?[name]?.version ?? 0) + 1
        icloud.records[zone, default: [:]][name] = FakeICloud.Stored(type: record.recordType, fields: fields, version: version, writer: self)
        seen[key] = version
        icloud.log.append(.record(zone: zone, name: name))
        return nil
    }

    private func delete(_ id: CKRecord.ID) -> CKError? {
        let zone = id.zoneID.zoneName
        guard canReach(zone) else { return CKError(.zoneNotFound) }
        if id.recordName == CKRecordNameZoneWideShare {
            icloud.zones[zone]?.invitee = nil
            return nil
        }
        guard icloud.records[zone]?.removeValue(forKey: id.recordName) != nil else { return CKError(.unknownItem) }
        // Deleting a status takes its occurrences, whose references to it are `deleteSelf`.
        if id.recordName.hasPrefix("Status.") {
            let occurrences = "Occurrence" + id.recordName + "."
            for name in icloud.records[zone]?.keys.filter({ $0.hasPrefix(occurrences) }) ?? [] {
                icloud.records[zone]?[name] = nil
                icloud.log.append(.record(zone: zone, name: name))
            }
        }
        icloud.log.append(.record(zone: zone, name: id.recordName))
        return nil
    }

    private func rebuilt(_ stored: FakeICloud.Stored, name: String, zone: String) -> CKRecord {
        let owner = icloud.zones[zone]?.owner ?? self
        let record = CKRecord(recordType: stored.type, recordID: CKRecord.ID(recordName: name, zoneID: zoneID(UUID(uuidString: zone)!, owner: owner)))
        for (field, value) in stored.fields { value.set(field, on: record) }
        return record
    }

    /// Fetches what changed in iCloud since the last fetch, as both engines would.
    func fetch() {
        let entries = icloud.log[cursor...]
        cursor = icloud.log.count
        var modified: [String: SharingRecordMapping.FetchedRecord] = [:]
        var order: [String] = []
        var deletions: [CKRecord.ID] = []
        var zonesDeleted: [CKRecordZone.ID] = []
        for entry in entries {
            switch entry {
            case .zoneDeleted(let zone):
                guard let connectionID = UUID(uuidString: zone), sync.cache.zones[connectionID] != nil else { continue }
                let ownerName = sync.cache.zones[connectionID]!.ownerName
                zonesDeleted.append(CKRecordZone.ID(zoneName: zone, ownerName: ownerName))
            case .record(let zone, let name):
                guard canReach(zone) else { continue }
                let key = "\(zone)/\(name)"
                if let stored = icloud.records[zone]?[name] {
                    if modified[key] == nil { order.append(key) }
                    modified[key] = .init(record: rebuilt(stored, name: name, zone: zone), writtenByOtherPerson: stored.writer !== self)
                    seen[key] = stored.version
                } else {
                    modified[key] = nil
                    order.removeAll { $0 == key }
                    let owner = icloud.zones[zone]!.owner
                    deletions.append(CKRecord.ID(recordName: name, zoneID: zoneID(UUID(uuidString: zone)!, owner: owner)))
                }
            }
        }
        take(sync.fetchedZoneDeletions(zonesDeleted))
        take(sync.fetched(order.compactMap { modified[$0] }, deleted: deletions))
    }
}
