import Foundation
import SwiftData
import NudgeEngine

/// Keeps what sharing needs on the device, beside the reminder store: connections, sent reminders,
/// received reminders' sync state, `CKSyncEngine`'s saved state and the outbox of unsent changes.
/// It is its own SwiftData store in its own file, never synced by SwiftData, and new and empty on
/// the first launch of 1.4.0: nothing moves into it. `@MainActor` for the same reason as
/// `ReminderStore`.
@MainActor
struct SharingStore {
    /// Internal so a test can count the records a save leaves.
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(location: StoreLocation) throws {
        container = try ModelContainer(for: Self.schema, migrationPlan: SharingMigrationPlan.self, configurations: Self.configuration(for: location))
    }

    nonisolated private static let schema = Schema(versionedSchema: SharingSchemaV1.self)

    /// The store's file name in the App Group, which isn't the reminder store's: SwiftData's default
    /// name would open the reminder store's file.
    nonisolated static let fileName = "sharing"

    /// Where and how SwiftData keeps the store. Its own function so a test can check it without
    /// opening the real store.
    nonisolated static func configuration(for location: StoreLocation) -> ModelConfiguration {
        // `cloudKitDatabase` defaults to `.automatic`, which would start syncing the store with
        // iCloud once the entitlement exists. Sharing syncs through `CKSyncEngine`, never SwiftData.
        switch location {
        case .appGroup:
            ModelConfiguration(fileName, schema: schema, groupContainer: .identifier(ReminderStore.appGroupIdentifier), cloudKitDatabase: .none)
        case .inMemory:
            ModelConfiguration(fileName, schema: schema, isStoredInMemoryOnly: true, groupContainer: .none, cloudKitDatabase: .none)
        case .file(let url):
            ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        }
    }

    /// Replaces what the store holds with `data`: what it leaves out is deleted. Nothing changes if
    /// `data` lists an ID twice.
    func save(_ data: SharingData) throws {
        try Self.checkUnique(data.connections.map(\.id))
        try Self.checkUnique(data.sentReminders.map(\.reminder.id))
        try Self.checkUniqueCopies(data.sentCopies)
        try Self.checkUnique(data.receivedSyncStates.map(\.reminderID))
        try Self.checkUnique(data.outbox.map(\.id))
        guard Set(data.engineStates.map(\.database)).count == data.engineStates.count else {
            throw StoreError.duplicateDatabase
        }
        try saveConnections(data.connections)
        try saveSentReminders(data.sentReminders)
        try replaceWhole(data)
        try context.save()
    }

    /// Connections and sent reminders have IDs, so their records are matched up and kept.
    private func saveConnections(_ connections: [SharingConnection]) throws {
        var records = try recordsByID(of: ConnectionRecord.self)
        for (position, connection) in connections.enumerated() {
            let record = records.removeValue(forKey: connection.id) ?? {
                let record = ConnectionRecord(id: connection.id, position: position)
                context.insert(record)
                return record
            }()
            record.position = position
            record.name = connection.name
            record.state = connection.state.storedValue
            record.mySharesStatus = connection.mine.sharesStatus
            record.myDeliveryMode = connection.mine.deliveryMode.storedValue
            record.theirSharesStatus = connection.theirs.sharesStatus
            record.theirDeliveryMode = connection.theirs.deliveryMode.storedValue
            record.address = connection.address
            record.invitedAt = connection.invitedAt
            record.connectedAt = connection.connectedAt
        }
        records.values.forEach(context.delete)
    }

    private func saveSentReminders(_ sentReminders: [SentReminder]) throws {
        var records = try recordsByID(of: SentReminderRecord.self)
        for (position, sent) in sentReminders.enumerated() {
            let record = records.removeValue(forKey: sent.reminder.id) ?? {
                let record = SentReminderRecord(id: sent.reminder.id, position: position)
                context.insert(record)
                return record
            }()
            try record.update(from: sent, position: position)
        }
        records.values.forEach(context.delete)
    }

    /// The rest have no ID of their own, or are small queues and blobs with no history, so they are
    /// replaced whole. Each old record is deleted by itself, not with `delete(model:)`: that is the
    /// path SwiftData documents for the cascade rule (a copy's occurrences go with it), and the
    /// deletes then wait for the one `save()` with the inserts.
    private func replaceWhole(_ data: SharingData) throws {
        try deleteAll(SentCopyRecord.self)
        for (position, copy) in data.sentCopies.enumerated() {
            context.insert(SentCopyRecord(position: position, copy: copy))
        }
        try deleteAll(ReceivedSyncRecord.self)
        for (position, state) in data.receivedSyncStates.enumerated() {
            let record = ReceivedSyncRecord(position: position, reminderID: state.reminderID)
            record.notSharingThisOne = state.notSharingThisOne
            record.waitingToSync = state.waitingToSync
            record.recordSystemFields = state.recordSystemFields
            context.insert(record)
        }
        try deleteAll(SyncEngineStateRecord.self)
        for (position, state) in data.engineStates.enumerated() {
            context.insert(SyncEngineStateRecord(position: position, database: state.database.storedValue, data: state.data))
        }
        try deleteAll(OutboxRecord.self)
        for (position, change) in data.outbox.enumerated() {
            context.insert(OutboxRecord(id: change.id, position: position, kind: change.kind.storedValue, connectionID: change.connectionID, reminderID: change.reminderID))
        }
    }

    private func deleteAll<Record: PersistentModel>(_ type: Record.Type) throws {
        try context.fetch(FetchDescriptor<Record>()).forEach(context.delete)
    }

    /// What the store holds, in the order it was saved.
    func load() throws -> SharingData {
        let connections = try context.fetch(FetchDescriptor<ConnectionRecord>(sortBy: [SortDescriptor(\.position)]))
        let sentReminders = try context.fetch(FetchDescriptor<SentReminderRecord>(sortBy: [SortDescriptor(\.position)]))
        let sentCopies = try context.fetch(FetchDescriptor<SentCopyRecord>(sortBy: [SortDescriptor(\.position)]))
        let receivedStates = try context.fetch(FetchDescriptor<ReceivedSyncRecord>(sortBy: [SortDescriptor(\.position)]))
        let engineStates = try context.fetch(FetchDescriptor<SyncEngineStateRecord>(sortBy: [SortDescriptor(\.position)]))
        let outbox = try context.fetch(FetchDescriptor<OutboxRecord>(sortBy: [SortDescriptor(\.position)]))
        return SharingData(
            connections: try connections.map {
                SharingConnection(
                    id: $0.id,
                    name: $0.name,
                    state: try .init(storedValue: $0.state),
                    mine: ConnectionChoices(sharesStatus: $0.mySharesStatus, deliveryMode: try .init(storedValue: $0.myDeliveryMode)),
                    theirs: ConnectionChoices(sharesStatus: $0.theirSharesStatus, deliveryMode: try .init(storedValue: $0.theirDeliveryMode)),
                    address: $0.address,
                    invitedAt: $0.invitedAt,
                    connectedAt: $0.connectedAt
                )
            },
            sentReminders: try sentReminders.map { try $0.sentReminder() },
            sentCopies: try sentCopies.map { try $0.sentCopy() },
            receivedSyncStates: receivedStates.map {
                ReceivedSyncState(reminderID: $0.reminderID, notSharingThisOne: $0.notSharingThisOne, waitingToSync: $0.waitingToSync, recordSystemFields: $0.recordSystemFields)
            },
            engineStates: try engineStates.map { SyncEngineState(database: try .init(storedValue: $0.database), data: $0.data) },
            outbox: try outbox.map {
                OutboxChange(id: $0.id, kind: try .init(storedValue: $0.kind), connectionID: $0.connectionID, reminderID: $0.reminderID)
            }
        )
    }

    /// Throws for the first reminder listed twice for one connection.
    private static func checkUniqueCopies(_ copies: [SentCopy]) throws {
        struct Key: Hashable { var connectionID: UUID; var reminderID: UUID }
        var seen: Set<Key> = []
        for copy in copies where !seen.insert(Key(connectionID: copy.connectionID, reminderID: copy.reminderID)).inserted {
            throw StoreError.duplicateID(copy.reminderID)
        }
    }

    private static func checkUnique(_ ids: [UUID]) throws {
        var seen: Set<UUID> = []
        for id in ids where !seen.insert(id).inserted {
            throw StoreError.duplicateID(id)
        }
    }

    private func recordsByID<Record: PersistentModel & IdentifiedRecord>(of type: Record.Type) throws -> [UUID: Record] {
        Dictionary(try context.fetch(FetchDescriptor<Record>()).map { ($0.id, $0) }) { first, _ in first }
    }
}

private extension SentReminderRecord {
    func update(from sent: SentReminder, position: Int) throws {
        let reminder = sent.reminder
        self.position = position
        title = reminder.title
        notes = reminder.notes
        dueTime = reminder.dueTime
        let repeating = reminder.repeatRule?.storedValue
        repeatRule = repeating?.rrule
        repeatMissingDay = repeating?.missingDay
        repeatUntilTime = repeating?.untilTime
        strength = reminder.strength.storedValue
        (paceKind, paceWait) = reminder.pace.storedValue
        breakThroughFocus = reminder.breakThroughFocus
        createdAt = reminder.createdAt
        revision = sent.revision
        changeNote = try sent.changeNote.storedData()
    }

    func sentReminder() throws -> SentReminder {
        SentReminder(
            reminder: Reminder(
                id: id,
                title: title,
                notes: notes,
                dueTime: dueTime,
                repeatRule: try repeatRule.map { try RepeatRule(storedRRULE: $0, missingDay: repeatMissingDay, untilTime: repeatUntilTime) },
                strength: try Strength(storedValue: strength),
                pace: try Pace(storedKind: paceKind, wait: paceWait),
                breakThroughFocus: breakThroughFocus,
                createdAt: createdAt
            ),
            revision: revision,
            changeNote: try [ReceivedChange](storedData: changeNote)
        )
    }
}

private extension SentCopyRecord {
    convenience init(position: Int, copy: SentCopy) {
        self.init(position: position, connectionID: copy.connectionID, reminderID: copy.reminderID)
        createdAt = copy.createdAt
        receipt = copy.receipt.storedValue
        waitingToSync = copy.waitingToSync
        guard let record = copy.statusRecord else { return }
        hasStatusRecord = true
        notSharingThisOne = record.notSharingThisOne
        statusLabel = record.report.label.storedValue
        occurrences = record.report.occurrences.enumerated().map { position, occurrence in
            SentCopyOccurrenceRecord(
                position: position,
                dueTime: occurrence.dueTime,
                year: occurrence.day.year,
                month: occurrence.day.month,
                day: occurrence.day.day,
                label: occurrence.label.storedValue
            )
        }
    }

    func sentCopy() throws -> SentCopy {
        var statusRecord: SentCopy.StatusRecord?
        if hasStatusRecord {
            guard let statusLabel else { throw StoreError.unreadable(field: .reportedStatus, value: "no label") }
            statusRecord = SentCopy.StatusRecord(
                report: StatusReport(
                    label: try ReportedStatus(storedValue: statusLabel),
                    occurrences: try occurrences.sorted { $0.position < $1.position }.map {
                        StatusReport.OccurrenceStatus(
                            dueTime: $0.dueTime,
                            day: CalendarDay(year: $0.year, month: $0.month, day: $0.day),
                            label: try ReportedStatus(storedValue: $0.label)
                        )
                    }
                ),
                notSharingThisOne: notSharingThisOne
            )
        }
        return SentCopy(
            connectionID: connectionID,
            reminderID: reminderID,
            createdAt: createdAt,
            receipt: try SentCopy.Receipt(storedValue: receipt),
            statusRecord: statusRecord,
            waitingToSync: waitingToSync
        )
    }
}

extension SentCopy.Receipt {
    var storedValue: String {
        switch self {
        case .notDelivered: "notDelivered"
        case .waitingForAcceptance: "waitingForAcceptance"
        case .started: "started"
        }
    }

    init(storedValue: String) throws {
        switch storedValue {
        case "notDelivered": self = .notDelivered
        case "waitingForAcceptance": self = .waitingForAcceptance
        case "started": self = .started
        default: throw StoreError.unreadable(field: .sentCopyReceipt, value: storedValue)
        }
    }
}

extension ReportedStatus {
    var storedValue: String {
        switch self {
        case .nudging: "nudging"
        case .comingUp: "comingUp"
        case .paused: "paused"
        case .done: "done"
        case .missed: "missed"
        case .skipped: "skipped"
        case .removed: "removed"
        }
    }

    init(storedValue: String) throws {
        switch storedValue {
        case "nudging": self = .nudging
        case "comingUp": self = .comingUp
        case "paused": self = .paused
        case "done": self = .done
        case "missed": self = .missed
        case "skipped": self = .skipped
        case "removed": self = .removed
        default: throw StoreError.unreadable(field: .reportedStatus, value: storedValue)
        }
    }
}

private extension SyncEngineState.Database {
    var storedValue: String {
        switch self {
        case .private: "private"
        case .shared: "shared"
        }
    }

    init(storedValue: String) throws {
        switch storedValue {
        case "private": self = .private
        case "shared": self = .shared
        default: throw StoreError.unreadable(field: .syncDatabase, value: storedValue)
        }
    }
}

private extension OutboxChange.Kind {
    var storedValue: String {
        switch self {
        case .send: "send"
        case .revise: "revise"
        case .cancel: "cancel"
        case .receipt: "receipt"
        case .status: "status"
        case .settings: "settings"
        case .disconnect: "disconnect"
        }
    }

    init(storedValue: String) throws {
        switch storedValue {
        case "send": self = .send
        case "revise": self = .revise
        case "cancel": self = .cancel
        case "receipt": self = .receipt
        case "status": self = .status
        case "settings": self = .settings
        case "disconnect": self = .disconnect
        default: throw StoreError.unreadable(field: .outboxKind, value: storedValue)
        }
    }
}

/// Internal, not private: the record mapping spells it the same way in the connection settings record.
extension DeliveryMode {
    var storedValue: String {
        switch self {
        case .startRightAway: "startRightAway"
        case .askMeFirst: "askMeFirst"
        }
    }

    init(storedValue: String) throws {
        switch storedValue {
        case "startRightAway": self = .startRightAway
        case "askMeFirst": self = .askMeFirst
        default: throw StoreError.unreadable(field: .deliveryMode, value: storedValue)
        }
    }
}

private extension SharingConnection.State {
    var storedValue: String {
        switch self {
        case .invited: "invited"
        case .connected: "connected"
        case .ended: "ended"
        }
    }

    init(storedValue: String) throws {
        switch storedValue {
        case "invited": self = .invited
        case "connected": self = .connected
        case "ended": self = .ended
        default: throw StoreError.unreadable(field: .connectionState, value: storedValue)
        }
    }
}
