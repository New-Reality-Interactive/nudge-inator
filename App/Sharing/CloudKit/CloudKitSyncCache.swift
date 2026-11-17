import CloudKit
import Foundation

/// What the CloudKit sync keeps between launches beside `CKSyncEngine`'s own state (#216): which
/// record zone each connection is, the records this person's app writes (and what iCloud last said
/// of each, for its change tag), the changes not yet in iCloud, and the other person's status
/// records until a status reads whole. The engine's pending list names records only; this holds
/// what goes in them, so a change made before a relaunch, or before the same account signs in
/// again, still goes.
///
/// Kept in the sharing store as bytes the store doesn't read (`SharingSyncState`).
struct CloudKitSyncCache: Codable, Equatable {
    var zones: [UUID: Zone] = [:]
    var records: [RecordKey: CachedRecord] = [:]
    /// Zones to delete, each with the outbox changes waiting for it: a disconnect or a revoke.
    var zoneDeletes: [UUID: [UUID]] = [:]
    /// Zones to make, by connection.
    var zoneSaves: Set<UUID> = []
    /// This person's own Status sharing per connection, as their latest settings said. On by
    /// default, as `ConnectionChoices`.
    var sharesStatus: [UUID: Bool] = [:]
    /// The outbox changes that have gone, or never will, which the app model hasn't kept as gone
    /// yet, oldest first. Kept so a relaunch before the report still makes it: the outbox entry
    /// would otherwise wait for good. Optional, as `refused` is, so a cache kept before #396 reads.
    var unreported: [UUID]?
    /// The changes iCloud refused for good (#396), until the app model has kept them as given up.
    var refused: Set<UUID>?
    /// When iCloud last saved this person's settings record with a heartbeat on it, per connection
    /// (#435): iCloud's time, which the next heartbeat is measured from. Optional, so a cache kept
    /// before it reads.
    var lastHeartbeats: [UUID: Date]?

    /// A connection's record zone: named with the connection's ID, owned by whoever invited.
    struct Zone: Codable, Equatable {
        /// `CKCurrentUserDefaultName` in the inviter's own zone; the inviter's user record name in
        /// the invitee's shared database.
        var ownerName: String
        /// Whether someone has accepted the zone's share, as the inviter last fetched it.
        var participantJoined = false

        var isOwn: Bool { ownerName == CKCurrentUserDefaultName }
    }

    /// A record, named within its connection's zone.
    struct RecordKey: Codable, Hashable {
        var connectionID: UUID
        var recordName: String
    }

    struct CachedRecord: Codable, Equatable {
        var recordType: String
        /// iCloud's latest version's system fields (`encodeSystemFields`), so a save carries its
        /// change tag, or `nil` before iCloud has had it.
        var systemFields: Data?
        /// This person's record: its values as last written or waiting to go. The other person's
        /// (status records only): its values as fetched.
        var fields: [String: StoredField] = [:]
        /// A write waiting to reach iCloud, or `nil` when there's none.
        var pending: PendingWrite?
    }

    struct PendingWrite: Codable, Equatable {
        var isDelete: Bool
        /// Goes up with each write to the record, so a save that iCloud took can be told from a
        /// later one still waiting.
        var version: Int
        /// The outbox changes waiting for this write.
        var changeIDs: [UUID]
        /// Fields to clear on iCloud's record: written before, or there in iCloud's, and not now.
        var clears: [String] = []
    }

    /// One field's value. CloudKit's own values aren't `Codable`, and a number must keep its type:
    /// an `Int64` field can't take a `Double`.
    enum StoredField: Codable, Equatable {
        case string(String)
        case int(Int64)
        case double(Double)
        case bytes(Data)
        /// A reference to a record in the same zone that deletes its holder with it.
        case reference(recordName: String)
    }
}

extension CloudKitSyncCache {
    /// The invites this person made that the sharing store doesn't list, by connection: each one's
    /// share has the person on it, but the app was closed while its compose screen was up, so the
    /// link was never sent and Connections has no Invited row for it (#400). `listed` is every
    /// connection the store lists, in any state. An invite already being deleted isn't one.
    func leftoverInvites(listed: Set<UUID>) -> [UUID] {
        zones.filter { id, zone in zone.isOwn && !listed.contains(id) && zoneDeletes[id] == nil }.map(\.key)
    }
}

extension CloudKitSyncCache.StoredField {
    /// Every field the mapping writes is encrypted except a reference (`SharingRecordMapping`).
    static func fields(of record: CKRecord) -> [String: Self] {
        var fields: [String: Self] = [:]
        for key in record.allKeys() {
            if let reference = record[key] as? CKRecord.Reference {
                fields[key] = .reference(recordName: reference.recordID.recordName)
            }
        }
        for key in record.encryptedValues.allKeys() {
            fields[key] = Self(record.encryptedValues[key])
        }
        return fields
    }

    private init?(_ value: (any __CKRecordObjCValue)?) {
        switch value {
        case let text as String: self = .string(text)
        case let data as Data: self = .bytes(data)
        case let number as NSNumber:
            self = CFNumberIsFloatType(number) ? .double(number.doubleValue) : .int(number.int64Value)
        default: return nil
        }
    }

    func set(_ key: String, on record: CKRecord) {
        switch self {
        case .string(let text): record.encryptedValues[key] = text
        case .int(let number): record.encryptedValues[key] = number
        case .double(let number): record.encryptedValues[key] = number
        case .bytes(let data): record.encryptedValues[key] = data
        case .reference(let recordName):
            let target = CKRecord.ID(recordName: recordName, zoneID: record.recordID.zoneID)
            record[key] = CKRecord.Reference(recordID: target, action: .deleteSelf)
        }
    }
}

extension CKRecord {
    /// This record's system fields as bytes, for `CloudKitSyncCache.CachedRecord.systemFields`.
    var archivedSystemFields: Data {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    /// A record with only the system fields `archivedSystemFields` kept, or `nil` if they don't read.
    static func fromSystemFields(_ data: Data) -> CKRecord? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = true
        defer { unarchiver.finishDecoding() }
        return CKRecord(coder: unarchiver)
    }
}
