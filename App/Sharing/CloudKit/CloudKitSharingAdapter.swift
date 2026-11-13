import CloudKit
import Foundation
import NudgeEngine
import os

/// The real sharing adapter, the only code that may talk to iCloud (`scripts/test.sh` keeps
/// CloudKit out of the rest of the app). This ticket (#215) gives it the account: its state from
/// `CKContainer.accountStatus`, and a report when `CKSyncEngine` sends its account-change event.
/// Sending, syncing records, invites and connectivity are #216's and #217's, and until then those
/// do nothing or throw.
///
/// Making one asks iCloud nothing. `signedInAccount()` and `start()` do, so the app calls them only
/// once the person opens Connections or accepts an invite (spec #127, decision 4).
@MainActor
final class CloudKitSharingAdapter: SharingAdapter {
    static let containerIdentifier = "iCloud.com.newrealityinteractive.nudgeinator"
    private static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "CloudKit")

    struct NotAvailableYet: Error {}

    weak var events: (any SharingAdapterEvents)?
    private let reader: CloudKitAccountReader
    private let container: CKContainer?
    private var engine: CKSyncEngine?
    private var delegate: AccountEventDelegate?

    /// A real adapter over the app's container.
    convenience init() {
        let container = CKContainer(identifier: Self.containerIdentifier)
        self.init(reader: CloudKitAccountReader(source: container), container: container)
    }

    init(reader: CloudKitAccountReader, container: CKContainer? = nil) {
        self.reader = reader
        self.container = container
    }

    /// Starts listening for account changes. Idempotent. The engine doesn't sync on its own: that
    /// is #216's.
    func start() {
        guard engine == nil, let container else { return }
        let delegate = AccountEventDelegate { [weak self] in
            Task { @MainActor in self?.events?.accountStateChanged() }
        }
        var configuration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: nil,
            delegate: delegate
        )
        configuration.automaticallySync = false
        self.delegate = delegate
        engine = CKSyncEngine(configuration)
    }

    func signedInAccount() async -> SharingAccount {
        await reader.read()
    }

    // MARK: Not yet (#216, #217)

    // Placeholder until connectivity is watched (#216).
    var isOnline: Bool { true }

    func submit(_ change: SharingChange) {
        Self.logger.error("Sending isn't built yet (#216)")
    }

    func invite(_ connectionID: UUID) async throws -> InvitedPerson? { throw NotAvailableYet() }
    func revokeInvite(_ connectionID: UUID) {}
    func accept(_ connectionID: UUID) async throws { throw NotAvailableYet() }
    func keepOnly(_ participant: SharingParticipant, in connectionID: UUID) {}
}

/// Hears `CKSyncEngine`'s account-change event. Everything else is #216's.
private final class AccountEventDelegate: CKSyncEngineDelegate, Sendable {
    let onAccountChange: @Sendable () -> Void

    init(onAccountChange: @escaping @Sendable () -> Void) {
        self.onAccountChange = onAccountChange
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        if case .accountChange = event { onAccountChange() }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        nil
    }
}
