import CloudKit
import Foundation
import Network
import NudgeEngine
import os

/// The real sharing adapter, the only code that may talk to iCloud (`scripts/test.sh` keeps
/// CloudKit out of the rest of the app). Two `CKSyncEngine`s, one for the private database and one
/// for the shared database (spec #127, CloudKit through `CKSyncEngine`), with `CloudKitSync`
/// between them and the app (#216). The engines manage their database subscriptions and silent
/// pushes, fetch when iCloud says something changed, and retry what network and account errors
/// stopped; what hasn't gone stays in the outbox until `sent(_:)` says it has.
///
/// The account comes from `CKContainer.accountStatus`, and a report when an engine sends its
/// account-change event (#215). Invites (making a share, accepting one) are #217's.
///
/// Making one asks iCloud nothing. `start()` and `signedInAccount()` do, and the app model calls
/// them only once the person opens Connections or an invite reaches them, or sharing holds
/// something already (spec #127, decision 4).
@MainActor
final class CloudKitSharingAdapter: SharingAdapter {
    static let containerIdentifier = "iCloud.com.newrealityinteractive.nudgeinator"
    private static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "CloudKit")

    struct NotAvailableYet: Error {}

    weak var events: (any SharingAdapterEvents)?
    private let reader: CloudKitAccountReader
    private let container: CKContainer?
    /// Off in tests, which send and fetch by hand (WWDC23 "Sync to iCloud with CKSyncEngine").
    private let automaticallySync: Bool
    private(set) var sync: CloudKitSync?
    private(set) var engines: [SyncEngineState.Database: CKSyncEngine] = [:]
    /// Each engine's latest saved state, and the one last kept in the store: while a fetched
    /// change waits to be kept, the store keeps the state from before it, so a relaunch fetches it
    /// again.
    private var engineStates: [SyncEngineState.Database: Data] = [:]
    private var keptEngineStates: [SyncEngineState.Database: Data] = [:]
    /// The other person's changes the app model hasn't kept yet, offered again on the next event.
    private var undelivered: [SharingChange] = []
    /// Changes that went, which the app model hasn't kept as gone yet.
    private var unreported: [OutboxChange.ID] = []
    private var isReporting = false
    private let connectivity = Connectivity()

    /// A real adapter over the app's container.
    convenience init() {
        let container = CKContainer(identifier: Self.containerIdentifier)
        self.init(reader: CloudKitAccountReader(source: container), container: container)
    }

    init(reader: CloudKitAccountReader, container: CKContainer? = nil, automaticallySync: Bool = true) {
        self.reader = reader
        self.container = container
        self.automaticallySync = automaticallySync
        connectivity.onChange = { [weak self] in self?.events?.connectivityChanged() }
    }

    /// Makes the engines over what the store kept, and hands them everything still unsent.
    /// Idempotent. Waits for a sharing store that won't open, rather than starting over and then
    /// writing an empty state over what it holds: the next call tries again.
    func start() {
        guard sync == nil, let container, let saved = events?.savedSyncState() else { return }
        let cache = saved.cache.flatMap { try? JSONDecoder().decode(CloudKitSyncCache.self, from: $0) } ?? CloudKitSyncCache()
        let sync = CloudKitSync(cache: cache)
        self.sync = sync
        for state in saved.engines { engineStates[state.database] = state.data }
        keptEngineStates = engineStates
        for database in [SyncEngineState.Database.private, .shared] {
            let serialization = engineStates[database].flatMap { try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0) }
            var configuration = CKSyncEngine.Configuration(
                database: database == .private ? container.privateCloudDatabase : container.sharedCloudDatabase,
                stateSerialization: serialization,
                delegate: self
            )
            configuration.automaticallySync = automaticallySync
            let engine = CKSyncEngine(configuration)
            engines[database] = engine
            sync.attach(engine.state, for: database)
        }
        connectivity.start()
        keep()
    }

    /// Also offers the app model again what it couldn't keep before (at launch, before its
    /// reminders were read, say): read at launch and on App opened.
    func signedInAccount() async -> SharingAccount {
        if !undelivered.isEmpty || !unreported.isEmpty { report(CloudKitSync.Outcome()) }
        return await reader.read()
    }

    /// Whether the iPhone has a network path, which a path monitor keeps up to date. Online until
    /// `start()`, as the app model assumes.
    var isOnline: Bool { connectivity.isOnline }

    func submit(_ change: SharingChange) {
        start()
        guard let sync else { return }
        let gone = sync.submit(change)
        keep()
        report(CloudKitSync.Outcome(gone: gone))
    }

    /// Deletes the invite's zone, which ends its share for everyone, whether they accepted or not.
    func revokeInvite(_ connectionID: UUID) {
        start()
        guard let sync, sync.ownsZone(of: connectionID) else { return }
        _ = sync.submit(.disconnect(connectionID))
        keep()
    }

    // MARK: Not yet (#217)

    func invite(_ connectionID: UUID) async throws -> InvitedPerson? { throw NotAvailableYet() }
    func accept(_ connectionID: UUID) async throws { throw NotAvailableYet() }
    func keepOnly(_ participant: SharingParticipant, in connectionID: UUID) {}

    // MARK: Keeping and reporting

    /// Has the store keep the engines' states and the sync's cache.
    private func keep() {
        guard let sync, let events else { return }
        if undelivered.isEmpty { keptEngineStates = engineStates }
        do {
            let cache = try JSONEncoder().encode(sync.cache)
            let engines = keptEngineStates.sorted { $0.key == .private && $1.key == .shared }.map { SyncEngineState(database: $0.key, data: $0.value) }
            try events.keepSyncState(SharingSyncState(engines: engines, cache: cache))
        } catch {
            Self.logger.error("The sync state couldn't be kept: \(error, privacy: .public)")
        }
    }

    private func report(_ outcome: CloudKitSync.Outcome) {
        unreported += outcome.gone
        undelivered += outcome.received
        Task { await reportWaiting() }
    }

    /// Tells the app model what arrived and what went, oldest first, until nothing waits or the
    /// model can't keep one, which then waits for the next event or account read.
    private func reportWaiting() async {
        guard !isReporting, let events else { return }
        isReporting = true
        defer { isReporting = false }
        var stuck = false
        while !stuck, !undelivered.isEmpty || !unreported.isEmpty {
            if let change = undelivered.first {
                do {
                    try await events.received(change)
                    undelivered.removeFirst()
                } catch {
                    Self.logger.error("An incoming change couldn't be kept: \(error, privacy: .public)")
                    stuck = true
                }
            } else if let changeID = unreported.first {
                do {
                    try await events.sent(changeID)
                    unreported.removeFirst()
                } catch {
                    Self.logger.error("A change sent couldn't be kept as sent: \(error, privacy: .public)")
                    stuck = true
                }
            }
        }
        keep()
    }
}

extension CloudKitSharingAdapter: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard let sync else { return }
        let database: SyncEngineState.Database = syncEngine.database.databaseScope == .shared ? .shared : .private
        switch event {
        case .stateUpdate(let update):
            keepState(update.stateSerialization, of: database)
        case .accountChange(let change):
            accountChanged(change.changeType, sync: sync)
        case .fetchedDatabaseChanges(let changes):
            if database == .shared {
                changes.modifications.forEach { sync.joinZone($0.zoneID) }
            }
            if changes.deletions.contains(where: { $0.reason == .encryptedDataReset }) {
                Self.logger.notice("iCloud Keychain was reset: a connection's zone is gone")
            }
            report(sync.fetchedZoneDeletions(changes.deletions.map(\.zoneID)))
        case .fetchedRecordZoneChanges(let changes):
            report(fetched(changes, sync: sync))
        case .sentDatabaseChanges(let sent):
            report(sync.sentZones(
                saved: sent.savedZones.map(\.zoneID),
                deleted: sent.deletedZoneIDs,
                failedSaves: Dictionary(sent.failedZoneSaves.map { ($0.zone.zoneID, $0.error) }) { first, _ in first },
                failedDeletes: sent.failedZoneDeletes
            ))
        case .sentRecordZoneChanges(let sent):
            report(sync.sent(
                saved: sent.savedRecords,
                failedSaves: sent.failedRecordSaves.map { CloudKitSync.FailedSave(record: $0.record, error: $0.error) },
                deleted: sent.deletedRecordIDs,
                failedDeletes: sent.failedRecordDeletes
            ))
        default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard let sync else { return nil }
        let inScope = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        let stale = inScope.filter { !sync.isWaiting($0) }
        if !stale.isEmpty { syncEngine.state.remove(pendingRecordZoneChanges: stale) }
        return await batch(of: sync.ordered(inScope.filter(sync.isWaiting)), sync: sync)
    }

    /// A batch of `pending`, in that order, with each record built on the main actor.
    func batch(of pending: [CKSyncEngine.PendingRecordZoneChange], sync: CloudKitSync) async -> CKSyncEngine.RecordZoneChangeBatch? {
        await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending) { recordID in
            await sync.record(for: recordID)
        }
    }

    private func keepState(_ serialization: CKSyncEngine.State.Serialization, of database: SyncEngineState.Database) {
        do {
            engineStates[database] = try JSONEncoder().encode(serialization)
        } catch {
            // The next launch then starts the engine with no state, and fetches everything again.
            Self.logger.error("An engine's state couldn't be encoded: \(error, privacy: .public)")
            engineStates[database] = nil
        }
        keep()
    }

    private func accountChanged(_ change: CKSyncEngine.Event.AccountChange.ChangeType, sync: CloudKitSync) {
        switch change {
        case .signIn: sync.accountChanged(.signIn)
        case .signOut: sync.accountChanged(.signOut)
        case .switchAccounts:
            sync.accountChanged(.switchAccounts)
            undelivered = []
            unreported = []
        @unknown default: break
        }
        keep()
        events?.accountStateChanged()
    }

    /// The other person's changes in fetched records, and what the zones' shares say: an inviter
    /// hears from their zone's share whether the other person is still on it.
    private func fetched(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges, sync: CloudKitSync) -> CloudKitSync.Outcome {
        var outcome = CloudKitSync.Outcome()
        var records: [SharingRecordMapping.FetchedRecord] = []
        for modification in changes.modifications {
            if let share = modification.record as? CKShare {
                guard let connectionID = UUID(uuidString: share.recordID.zoneID.zoneName) else { continue }
                outcome = outcome + sync.fetchedShare(in: connectionID, hasAcceptedParticipant: CloudKitSync.hasAcceptedParticipant(share))
            } else {
                records.append(SharingRecordMapping.FetchedRecord(fetched: modification.record))
            }
        }
        return outcome + sync.fetched(records, deleted: changes.deletions.map(\.recordID))
    }
}

/// Whether the iPhone has a network path, from `NWPathMonitor`: it asks nothing of iCloud.
@MainActor
private final class Connectivity {
    private let monitor = NWPathMonitor()
    private(set) var isOnline = true
    var onChange: () -> Void = {}
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.update(online) }
        }
        monitor.start(queue: DispatchQueue(label: "com.newrealityinteractive.nudgeinator.connectivity"))
    }

    private func update(_ online: Bool) {
        guard online != isOnline else { return }
        isOnline = online
        onChange()
    }
}
