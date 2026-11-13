import CloudKit
import Foundation
import NudgeEngine
import os

/// Where a database's unsent changes wait: `CKSyncEngine.State`, or a test's stand-in for it.
@MainActor
protocol PendingChangeQueue: AnyObject {
    var pendingRecordZoneChanges: [CKSyncEngine.PendingRecordZoneChange] { get }
    func add(pendingRecordZoneChanges: [CKSyncEngine.PendingRecordZoneChange])
    func remove(pendingRecordZoneChanges: [CKSyncEngine.PendingRecordZoneChange])
    func add(pendingDatabaseChanges: [CKSyncEngine.PendingDatabaseChange])
}

extension CKSyncEngine.State: PendingChangeQueue {}

/// The sharing adapter's sync, between the app's changes and the two `CKSyncEngine`s (#216): one
/// for the private database, which holds the zones of the connections this person invited, and one
/// for the shared database, where the zones they were invited to appear. Each connection is one
/// record zone, named with its ID, in the inviter's private database; both directions' records live
/// there (spec #127, CloudKit model).
///
/// It turns a submitted change into records through `SharingRecordMapping`, holds them until iCloud
/// has them, gives each batch its records, and turns what the engines report into an `Outcome`.
/// Synchronous and free of the engines themselves, so tests drive two of them by hand through a
/// stand-in for iCloud.
@MainActor
final class CloudKitSync {
    private static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "CloudKit")

    /// What an event comes to for the app: the other person's changes, and the outbox IDs of this
    /// person's changes that have gone, or never will and so count as gone.
    struct Outcome: Equatable {
        var received: [SharingChange] = []
        var gone: [OutboxChange.ID] = []

        static func + (lhs: Outcome, rhs: Outcome) -> Outcome {
            Outcome(received: lhs.received + rhs.received, gone: lhs.gone + rhs.gone)
        }
    }

    private(set) var cache: CloudKitSyncCache
    private var queues: [SyncEngineState.Database: any PendingChangeQueue] = [:]
    /// The version of each record the latest batch carried, to tell the save iCloud took from a
    /// later one. Not kept: after a relaunch the batch is built again.
    private var batched: [CloudKitSyncCache.RecordKey: Int] = [:]

    init(cache: CloudKitSyncCache = CloudKitSyncCache()) {
        self.cache = cache
    }

    /// Where `database`'s changes go from now on. Everything still unsent for it is handed over
    /// again, since a new engine, or one reset by an account change, knows none of it. The engine
    /// ignores a change it already holds.
    func attach(_ queue: any PendingChangeQueue, for database: SyncEngineState.Database) {
        queues[database] = queue
        requeueEverything(in: database)
    }

    // MARK: Zones

    /// The zone of a connection this person invited someone to, made in their private database
    /// (#217 makes its share).
    @discardableResult
    func makeZone(for connectionID: UUID) -> CKRecordZone.ID {
        cache.zones[connectionID] = CloudKitSyncCache.Zone(ownerName: CKCurrentUserDefaultName)
        cache.zoneSaves.insert(connectionID)
        let zoneID = zoneID(of: connectionID, ownerName: CKCurrentUserDefaultName)
        queues[.private]?.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        return zoneID
    }

    /// The zone of a connection this person accepted an invite to, as their shared database names
    /// it (#217 calls this on accepting; a fetch of the shared database finds it too).
    func joinZone(_ zoneID: CKRecordZone.ID) {
        guard let connectionID = UUID(uuidString: zoneID.zoneName), cache.zones[connectionID] == nil else { return }
        cache.zones[connectionID] = CloudKitSyncCache.Zone(ownerName: zoneID.ownerName)
    }

    /// Whether this person invited the other to the connection, so its zone is in their private
    /// database.
    func ownsZone(of connectionID: UUID) -> Bool {
        cache.zones[connectionID]?.isOwn == true
    }

    /// The share that makes a connection's zone the other person's too: private, so only someone
    /// invited can join, and read-write once they have (spec #127, CloudKit model). The sharing
    /// sheet (#217) adds the participant with read-write permission.
    static func share(for zoneID: CKRecordZone.ID) -> CKShare {
        let share = CKShare(recordZoneID: zoneID)
        share.publicPermission = .none
        return share
    }

    /// Whether someone other than the owner has accepted `share`.
    static func hasAcceptedParticipant(_ share: CKShare) -> Bool {
        share.participants.contains { $0.role != .owner && $0.acceptanceStatus == .accepted }
    }

    // MARK: Sending

    /// Takes a change to send. Returns the outbox IDs of changes that went already: those that
    /// need nothing of iCloud, and those a disconnect makes moot. A change for a connection with
    /// no zone known here can't be written, so it's logged and stays in the outbox; every
    /// connection has one once #217 makes zones on inviting and accepting.
    func submit(_ change: SharingChange) -> [OutboxChange.ID] {
        let connectionID = change.connectionID
        guard let zone = cache.zones[connectionID] else {
            Self.logger.error("No zone for a \(String(describing: change.kind), privacy: .public) change's connection")
            return []
        }
        if change.kind == .disconnect {
            return disconnect(connectionID, zone: zone, changeID: change.entry.id)
        }
        if case .settings(let settings) = change.content {
            cache.sharesStatus[connectionID] = settings.choices.sharesStatus
        }
        let writes: SharingRecordMapping.Writes
        do {
            let mapping = try mapping(for: zoneID(of: connectionID, ownerName: zone.ownerName))
            writes = try mapping.writes(for: change, statusSharingOn: cache.sharesStatus[connectionID] ?? true)
        } catch {
            Self.logger.error("A \(String(describing: change.kind), privacy: .public) change couldn't be written: \(error, privacy: .public)")
            return []
        }
        guard !writes.save.isEmpty || !writes.delete.isEmpty else { return [change.entry.id] }
        for record in writes.save {
            write(RecordKey(connectionID, record.recordID), type: record.recordType, fields: CloudKitSyncCache.StoredField.fields(of: record), for: change.entry.id)
        }
        for recordID in writes.delete {
            write(RecordKey(connectionID, recordID), type: nil, fields: nil, for: change.entry.id)
        }
        return []
    }

    /// Ending a connection: the inviter deletes the zone, which ends the share and takes every
    /// record with it; the invitee leaves the share by deleting it from their shared database
    /// (CloudKit: "Shared Records"). Whatever was still to go through the connection never will,
    /// so those changes count as gone.
    private func disconnect(_ connectionID: UUID, zone: CloudKitSyncCache.Zone, changeID: UUID) -> [OutboxChange.ID] {
        var moot = forgetRecords(of: connectionID)
        if zone.isOwn {
            cache.zoneSaves.remove(connectionID)
            cache.zoneDeletes[connectionID, default: []].append(changeID)
            queues[.private]?.add(pendingDatabaseChanges: [.deleteZone(zoneID(of: connectionID, ownerName: zone.ownerName))])
        } else {
            let shareKey = CloudKitSyncCache.RecordKey(connectionID: connectionID, recordName: CKRecordNameZoneWideShare)
            let pending = CloudKitSyncCache.PendingWrite(isDelete: true, version: 1, changeIDs: [changeID])
            cache.records[shareKey] = CloudKitSyncCache.CachedRecord(recordType: CKRecord.SystemType.share, pending: pending)
            queue(shareKey, pending)
        }
        moot.removeAll { $0 == changeID }
        return moot
    }

    /// Records a write to `key` waiting for `changeID`: a save of `fields`, or with `type` `nil`, a
    /// delete. It replaces any earlier write still waiting, and so takes over its changes.
    private func write(_ key: CloudKitSyncCache.RecordKey, type: String?, fields: [String: CloudKitSyncCache.StoredField]?, for changeID: UUID) {
        var record = cache.records[key] ?? CloudKitSyncCache.CachedRecord(recordType: type ?? "")
        let earlier = record.pending
        var pending = CloudKitSyncCache.PendingWrite(
            isDelete: fields == nil,
            version: (earlier?.version ?? 0) + 1,
            changeIDs: (earlier?.changeIDs ?? []) + [changeID]
        )
        if let fields, let type {
            let before = Set(record.fields.keys).union(earlier?.clears ?? [])
            pending.clears = before.subtracting(fields.keys).sorted()
            record.recordType = type
            record.fields = fields
        }
        record.pending = pending
        cache.records[key] = record
        queue(key, pending)
    }

    // MARK: Batches

    /// The record to save for `recordID`: what this person's app last wrote, on iCloud's latest
    /// version so it carries the change tag, or `nil` when there's nothing to save. Notes which
    /// version the batch carries.
    func record(for recordID: CKRecord.ID) -> CKRecord? {
        guard let key = RecordKey(recordID), let cached = cache.records[key], let pending = cached.pending, !pending.isDelete else { return nil }
        let record = cached.systemFields.flatMap(CKRecord.fromSystemFields)
            ?? CKRecord(recordType: cached.recordType, recordID: recordID)
        cached.set(on: record)
        for field in pending.clears {
            record.encryptedValues[field] = nil
        }
        batched[key] = pending.version
        return record
    }

    /// Whether `change` is still one of this person's writes: a change left in an engine's queue
    /// for a record since forgotten is not, and is taken out.
    func isWaiting(_ change: CKSyncEngine.PendingRecordZoneChange) -> Bool {
        let recordID: CKRecord.ID
        switch change {
        case .saveRecord(let id), .deleteRecord(let id): recordID = id
        @unknown default: return true
        }
        guard let key = RecordKey(recordID) else { return false }
        return cache.records[key]?.pending != nil
    }

    /// `pending` in the order to send: a status ahead of its occurrences, which reference it,
    /// since a batch can stop at its size limit; saves ahead of deletes.
    func ordered(_ pending: [CKSyncEngine.PendingRecordZoneChange]) -> [CKSyncEngine.PendingRecordZoneChange] {
        func rank(_ change: CKSyncEngine.PendingRecordZoneChange) -> Int {
            switch change {
            case .saveRecord(let id): SharingRecordMapping.sendRank(of: id.recordName)
            case .deleteRecord: SharingRecordMapping.sendRanks + 1
            @unknown default: SharingRecordMapping.sendRanks + 2
            }
        }
        return pending.enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map(\.element)
    }

    // MARK: What was sent

    /// A save that failed, and why.
    struct FailedSave {
        let record: CKRecord
        let error: CKError
    }

    /// What a batch did in iCloud.
    func sent(saved: [CKRecord], failedSaves: [FailedSave], deleted: [CKRecord.ID], failedDeletes: [CKRecord.ID: CKError]) -> Outcome {
        var settled: [UUID] = []
        var ended = Outcome()
        for record in saved {
            settled += settle(record.recordID, systemFields: record.archivedSystemFields)
        }
        for recordID in deleted {
            settled += settle(recordID, systemFields: nil)
        }
        for (recordID, error) in failedDeletes {
            switch error.code {
            // Already gone, as most of a status's unused occurrence slots always are.
            case .unknownItem: settled += settle(recordID, systemFields: nil)
            case .zoneNotFound: ended = ended + zoneLost(recordID.zoneID)
            default: settled += giveUp(recordID, error)
            }
        }
        for failure in failedSaves {
            if failure.error.code == .zoneNotFound {
                ended = ended + zoneLost(failure.record.recordID.zoneID)
            } else {
                settled += retry(failure)
            }
        }
        return Outcome(received: ended.received, gone: done(among: settled + ended.gone))
    }

    /// The write to `recordID` reached iCloud. If it was the latest, its changes are through; if
    /// one came after it, that one goes next.
    private func settle(_ recordID: CKRecord.ID, systemFields: Data?) -> [UUID] {
        guard let key = RecordKey(recordID), var record = cache.records[key] else { return [] }
        let carried = batched.removeValue(forKey: key)
        guard let pending = record.pending else { return [] }
        guard carried == nil || carried == pending.version else {
            record.systemFields = systemFields ?? record.systemFields
            cache.records[key] = record
            queue(key, pending)
            return []
        }
        if pending.isDelete, key.recordName == CKRecordNameZoneWideShare {
            // The invitee left the share: nothing of the zone is theirs any more.
            return pending.changeIDs + forgetZone(key.connectionID)
        } else if pending.isDelete {
            cache.records[key] = nil
        } else {
            record.systemFields = systemFields
            record.pending = nil
            cache.records[key] = record
        }
        return pending.changeIDs
    }

    /// What to do about a save iCloud refused for a reason other than its zone. Returns the
    /// changes that count as gone.
    private func retry(_ failure: FailedSave) -> [UUID] {
        let recordID = failure.record.recordID
        guard let key = RecordKey(recordID), var record = cache.records[key], var pending = record.pending else { return [] }
        batched[key] = nil
        switch failure.error.code {
        case .serverRecordChanged:
            // This person's app is the record's only writer, so its values win: they go again on
            // iCloud's version, clearing what that has and they don't.
            if let server = failure.error.serverRecord {
                record.systemFields = server.archivedSystemFields
                let theirs = Set(CloudKitSyncCache.StoredField.fields(of: server).keys)
                pending.clears = Set(pending.clears).union(theirs.subtracting(record.fields.keys)).sorted()
                record.pending = pending
            }
            cache.records[key] = record
            queue(key, pending)
        case .unknownItem:
            // Gone from iCloud since: saved as new.
            record.systemFields = nil
            cache.records[key] = record
            queue(key, pending)
        case .batchRequestFailed:
            // Another record in the batch failed; this one goes again.
            queue(key, pending)
        default:
            return giveUp(recordID, failure.error)
        }
        return []
    }

    /// A write iCloud refused. One the engine retries itself (the network, the account, throttling)
    /// waits. A full iCloud keeps it waiting too, as Waiting to sync says, until the next launch or
    /// sign-in hands it over again. Anything else won't go however often it's tried, so it counts
    /// as gone, and the log says so (#216; #396 shows it to the person). Returns the changes that
    /// count as gone.
    private func giveUp(_ recordID: CKRecord.ID, _ error: CKError) -> [UUID] {
        guard !Self.engineRetries(error.code), error.code != .quotaExceeded else { return [] }
        Self.logger.error("iCloud refused a change to \(recordID.recordName, privacy: .public) for good: \(error, privacy: .public)")
        guard let key = RecordKey(recordID), var record = cache.records[key], let pending = record.pending else { return [] }
        batched[key] = nil
        if record.systemFields == nil || pending.isDelete {
            cache.records[key] = nil
        } else {
            record.pending = nil
            cache.records[key] = record
        }
        return pending.changeIDs
    }

    /// The errors `CKSyncEngine` retries by itself when conditions allow (WWDC23 "Sync to iCloud
    /// with CKSyncEngine": network failures, throttling and account issues).
    private static func engineRetries(_ code: CKError.Code) -> Bool {
        let retried: Set<CKError.Code> = [
            .networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited, .zoneBusy,
            .notAuthenticated, .accountTemporarilyUnavailable, .operationCancelled,
        ]
        return retried.contains(code)
    }

    /// Zones iCloud made or deleted, and zone saves it refused.
    func sentZones(saved: [CKRecordZone.ID], deleted: [CKRecordZone.ID], failedSaves: [CKRecordZone.ID: CKError], failedDeletes: [CKRecordZone.ID: CKError]) -> Outcome {
        for zoneID in saved {
            if let connectionID = UUID(uuidString: zoneID.zoneName) { cache.zoneSaves.remove(connectionID) }
        }
        for (zoneID, error) in failedSaves where !Self.engineRetries(error.code) {
            Self.logger.error("iCloud refused to make a zone: \(error, privacy: .public)")
            if let connectionID = UUID(uuidString: zoneID.zoneName) { cache.zoneSaves.remove(connectionID) }
        }
        var settled: [UUID] = []
        let gone = deleted + failedDeletes.filter { $0.value.code == .zoneNotFound }.map(\.key)
        for zoneID in gone {
            guard let connectionID = UUID(uuidString: zoneID.zoneName) else { continue }
            settled += forgetZone(connectionID)
        }
        return Outcome(gone: done(among: settled))
    }

    // MARK: What was fetched

    /// Records fetched from one database, and records it deleted. Returns the other person's
    /// changes, in the order fetched. Records this person's own app wrote only update their change
    /// tags; the other person's statuses are held until they read whole.
    func fetched(_ records: [SharingRecordMapping.FetchedRecord], deleted: [CKRecord.ID]) -> Outcome {
        var byZone: [CKRecordZone.ID: [SharingRecordMapping.FetchedRecord]] = [:]
        var zoneOrder: [CKRecordZone.ID] = []
        for item in records {
            let recordID = item.record.recordID
            guard let key = RecordKey(recordID), let mapping = try? mapping(for: recordID.zoneID) else { continue }
            joinZone(recordID.zoneID)
            if mapping.isOwn(recordName: recordID.recordName) {
                cache.records[key, default: .init(recordType: item.record.recordType)].systemFields = item.record.archivedSystemFields
                continue
            }
            if mapping.isStatus(recordName: recordID.recordName) {
                cache.records[key] = CloudKitSyncCache.CachedRecord(
                    recordType: item.record.recordType,
                    systemFields: item.record.archivedSystemFields,
                    fields: CloudKitSyncCache.StoredField.fields(of: item.record)
                )
            }
            if byZone[recordID.zoneID] == nil { zoneOrder.append(recordID.zoneID) }
            byZone[recordID.zoneID, default: []].append(item)
        }
        var changes: [SharingChange] = []
        for zoneID in zoneOrder {
            guard let mapping = try? mapping(for: zoneID) else { continue }
            changes += mapping.changes(from: byZone[zoneID] ?? [], held: held)
        }
        for recordID in deleted {
            guard let key = RecordKey(recordID), let mapping = try? mapping(for: recordID.zoneID) else { continue }
            if cache.records[key]?.pending == nil { cache.records[key] = nil }
            if let change = mapping.change(fromDeleted: recordID) {
                changes.append(change)
            }
        }
        return Outcome(received: changes)
    }

    /// The other person's record with this ID, as fetched earlier: only their statuses are held.
    private func held(_ recordID: CKRecord.ID) -> SharingRecordMapping.FetchedRecord? {
        guard let key = RecordKey(recordID), let held = cache.records[key], held.pending == nil else { return nil }
        let record = CKRecord(recordType: held.recordType, recordID: recordID)
        held.set(on: record)
        return SharingRecordMapping.FetchedRecord(record: record, writtenByOtherPerson: true)
    }

    /// The inviter fetched their zone's share: whether anyone has accepted it now. Someone who had
    /// and no longer has left it, which ends the connection: the zone, of no more use, is deleted.
    func fetchedShare(in connectionID: UUID, hasAcceptedParticipant: Bool) -> Outcome {
        guard let zone = cache.zones[connectionID], zone.isOwn else { return Outcome() }
        if hasAcceptedParticipant {
            cache.zones[connectionID]?.participantJoined = true
            return Outcome()
        }
        guard zone.participantJoined else { return Outcome() }
        let moot = forgetRecords(of: connectionID)
        cache.zoneDeletes[connectionID] = cache.zoneDeletes[connectionID] ?? []
        queues[.private]?.add(pendingDatabaseChanges: [.deleteZone(zoneID(of: connectionID, ownerName: zone.ownerName))])
        cache.zones[connectionID]?.participantJoined = false
        return Outcome(received: [.disconnect(connectionID)], gone: done(among: moot))
    }

    /// Zones a database fetch found deleted. One this person deleted is forgotten; any other means
    /// the connection is over.
    func fetchedZoneDeletions(_ zoneIDs: [CKRecordZone.ID]) -> Outcome {
        var ended = Outcome()
        for zoneID in zoneIDs {
            guard let connectionID = UUID(uuidString: zoneID.zoneName), cache.zones[connectionID] != nil else { continue }
            if cache.zoneDeletes[connectionID] != nil {
                ended.gone += forgetZone(connectionID)
            } else {
                ended = ended + zoneLost(zoneID)
            }
        }
        return Outcome(received: ended.received, gone: done(among: ended.gone))
    }

    /// A connection's zone is gone from iCloud though this person didn't delete it: the inviter
    /// deleted it, ending the connection, or for the inviter's own zone, iCloud lost it (an iCloud
    /// Keychain reset, or the person deleting the app's data in iCloud). The share went with it, so
    /// the connection is over either way: the app hears it ended, and the inviter invites again.
    /// Apple's `CKSyncEngine` docs say not to upload a reset zone's data again.
    private func zoneLost(_ zoneID: CKRecordZone.ID) -> Outcome {
        guard let connectionID = UUID(uuidString: zoneID.zoneName), cache.zones[connectionID] != nil else { return Outcome() }
        Self.logger.notice("A connection's zone is gone from iCloud, so the connection ended")
        return Outcome(received: [.disconnect(connectionID)], gone: forgetZone(connectionID))
    }

    // MARK: Accounts

    /// How the iCloud account changed, as `CKSyncEngine` says.
    enum AccountChange {
        case signIn
        case signOut
        case switchAccounts
    }

    /// The engines forget their unsent changes on any account change, so a sign-in hands them back:
    /// sharing pauses while signed out and keeps the outbox (#210), and the same account returning
    /// carries on. Another account's sharing is none of this one's, so a switch forgets it all, as
    /// the app model does (#212).
    func accountChanged(_ change: AccountChange) {
        switch change {
        case .signIn:
            for database in queues.keys { requeueEverything(in: database) }
        case .signOut:
            break
        case .switchAccounts:
            cache = CloudKitSyncCache()
            batched = [:]
        }
    }

    // MARK: Helpers

    private func requeueEverything(in database: SyncEngineState.Database) {
        guard let engineQueue = queues[database] else { return }
        for (connectionID, zone) in cache.zones where self.database(of: connectionID) == database {
            let zoneID = zoneID(of: connectionID, ownerName: zone.ownerName)
            if cache.zoneDeletes[connectionID] != nil {
                engineQueue.add(pendingDatabaseChanges: [.deleteZone(zoneID)])
            } else if cache.zoneSaves.contains(connectionID) {
                engineQueue.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
            }
        }
        for (key, record) in cache.records {
            guard let pending = record.pending, self.database(of: key.connectionID) == database else { continue }
            queue(key, pending)
        }
    }

    private func queue(_ key: CloudKitSyncCache.RecordKey, _ pending: CloudKitSyncCache.PendingWrite) {
        guard let recordID = recordID(of: key), let database = database(of: key.connectionID) else { return }
        let (wanted, other): (CKSyncEngine.PendingRecordZoneChange, CKSyncEngine.PendingRecordZoneChange) =
            pending.isDelete ? (.deleteRecord(recordID), .saveRecord(recordID)) : (.saveRecord(recordID), .deleteRecord(recordID))
        queues[database]?.remove(pendingRecordZoneChanges: [other])
        queues[database]?.add(pendingRecordZoneChanges: [wanted])
    }

    /// Forgets the connection's records, pending or not, and takes them out of the queue. Returns
    /// the changes that were waiting for them.
    private func forgetRecords(of connectionID: UUID) -> [UUID] {
        var waiting: [UUID] = []
        for (key, record) in cache.records where key.connectionID == connectionID {
            waiting += record.pending?.changeIDs ?? []
            if record.pending != nil, let recordID = recordID(of: key), let database = database(of: connectionID) {
                queues[database]?.remove(pendingRecordZoneChanges: [.saveRecord(recordID), .deleteRecord(recordID)])
            }
            cache.records[key] = nil
            batched[key] = nil
        }
        return waiting
    }

    /// Forgets everything about the connection's zone. Returns the changes that were waiting for it.
    private func forgetZone(_ connectionID: UUID) -> [UUID] {
        let waiting = forgetRecords(of: connectionID) + (cache.zoneDeletes.removeValue(forKey: connectionID) ?? [])
        cache.zones[connectionID] = nil
        cache.zoneSaves.remove(connectionID)
        cache.sharesStatus[connectionID] = nil
        return waiting
    }

    /// Of `settled`, the changes nothing else waits for any more, each once.
    private func done(among settled: [UUID]) -> [UUID] {
        guard !settled.isEmpty else { return [] }
        var stillWaiting = Set(cache.records.values.flatMap { $0.pending?.changeIDs ?? [] })
        stillWaiting.formUnion(cache.zoneDeletes.values.joined())
        var seen: Set<UUID> = []
        return settled.filter { !stillWaiting.contains($0) && seen.insert($0).inserted }
    }

    /// The database a connection's zone is in: the inviter's private one, or the invitee's shared one.
    private func database(of connectionID: UUID) -> SyncEngineState.Database? {
        cache.zones[connectionID].map { $0.isOwn ? .private : .shared }
    }

    private func zoneID(of connectionID: UUID, ownerName: String) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: connectionID.uuidString, ownerName: ownerName)
    }

    private func recordID(of key: CloudKitSyncCache.RecordKey) -> CKRecord.ID? {
        guard let zone = cache.zones[key.connectionID] else { return nil }
        return CKRecord.ID(recordName: key.recordName, zoneID: zoneID(of: key.connectionID, ownerName: zone.ownerName))
    }

    /// The zone isn't a connection's: its name isn't a connection's ID.
    private struct NotAConnectionZone: Error {}

    private func mapping(for zoneID: CKRecordZone.ID) throws -> SharingRecordMapping {
        guard let mapping = SharingRecordMapping(zoneID: zoneID) else { throw NotAConnectionZone() }
        return mapping
    }

    private typealias RecordKey = CloudKitSyncCache.RecordKey
}

private extension CloudKitSyncCache.RecordKey {
    /// The key of a record in a connection's zone, or `nil` for a zone that isn't one.
    init?(_ recordID: CKRecord.ID) {
        guard let connectionID = UUID(uuidString: recordID.zoneID.zoneName) else { return nil }
        self.init(connectionID, recordID)
    }

    init(_ connectionID: UUID, _ recordID: CKRecord.ID) {
        self.init(connectionID: connectionID, recordName: recordID.recordName)
    }
}

private extension CloudKitSyncCache.CachedRecord {
    /// Puts the cached fields on `record`.
    func set(on record: CKRecord) {
        for (field, value) in fields {
            value.set(field, on: record)
        }
    }
}
