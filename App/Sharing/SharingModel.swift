import Foundation
import NudgeEngine
import Observation
import os

/// What the app model keeps for sharing (ticket 192): the sharing store's data, the iCloud account
/// state, and the changes going to and coming from the other person, all through the sharing
/// adapter. Beside the reminder store's model, never in its way: a sharing store that won't open
/// leaves personal reminders exactly as they are, and so does an adapter that never reports.
@MainActor
@Observable
final class SharingModel {
    /// Everything the sharing store holds, as the screens read it. Empty until the store is read.
    private(set) var data = SharingData()
    /// The iCloud account as the adapter last reported it, or `nil` before it has.
    private(set) var accountState: SharingAccountState?

    /// What sharing can do, for the messages that say it is paused, or `nil` before the adapter
    /// has reported the account.
    var reach: SharingReach? { accountState?.reach }

    private let adapter: any SharingAdapter
    /// Opens the store, as the reminder store's opener does. A store that won't open is tried
    /// again by whatever needs it next: the account read on App opened, a change coming or going.
    private let openStore: () throws -> SharingStore
    @ObservationIgnored private var store: SharingStore?
    /// The latest read of the account. Each waits for the one before, so reads that overlap can't
    /// finish out of order and put an older state back (as the permission reads do).
    @ObservationIgnored private var accountRefresh: Task<Void, Never>?

    init(adapter: any SharingAdapter, openStore: @escaping () throws -> SharingStore) {
        self.adapter = adapter
        self.openStore = openStore
        adapter.events = self
    }

    /// Opens and reads the store if that hasn't worked yet, and returns it. Synchronous, so two
    /// callers can't both open it and calls keep their order: the open is quick, and awaiting it
    /// would let changes overtake each other.
    private func openedStore() throws -> SharingStore {
        if let store { return store }
        do {
            let store = try openStore()
            data = try store.load()
            self.store = store
            return store
        } catch {
            Self.logger.error("The sharing store couldn't be read: \(error, privacy: .public)")
            throw error
        }
    }

    /// Reads the account from the adapter, after the store is read (and tried again if it wouldn't
    /// open). At launch and on App opened, since the system may have changed it while the app was
    /// suspended, and when the adapter says it changed. It starts the read and returns: asking
    /// iCloud may take a while, and no event waits for it.
    func refreshAccountState() {
        let previous = accountRefresh
        accountRefresh = Task {
            await previous?.value
            _ = try? openedStore()
            accountState = await adapter.accountState()
        }
    }

    /// Returns once the account read started so far has finished.
    func waitUntilApplied() async {
        await accountRefresh?.value
    }

    /// Hands a change to the adapter and keeps it in the outbox until the adapter says it has gone
    /// through iCloud. The one door every outgoing change goes through. Throws, sending nothing, if
    /// the store can't be opened or can't keep the outbox entry, since a change that isn't kept is a
    /// change the person can't see as Waiting to sync.
    func submit(_ change: SharingChange) throws {
        var kept = try currentData()
        kept.outbox.append(change.entry)
        try keep(kept)
        adapter.submit(change)
    }

    /// What the store holds, opening it first if it isn't open.
    private func currentData() throws -> SharingData {
        _ = try openedStore()
        return data
    }

    /// Saves `kept` and only then makes it the model's data, so what the model shows is what the store
    /// holds.
    private func keep(_ kept: SharingData) throws {
        try openedStore().save(kept)
        data = kept
    }
}

extension SharingModel {
    static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "SharingModel")
}

extension SharingModel: SharingAdapterEvents {
    func received(_ change: SharingChange) async throws {
        var applied = try currentData()
        if applied.apply(incoming: change) {
            try keep(applied)
        } else {
            Self.logger.info("An incoming \(String(describing: change.kind), privacy: .public) change wasn't applied")
        }
    }

    func sent(_ changeID: OutboxChange.ID) async throws {
        var remaining = try currentData()
        remaining.outbox.removeAll { $0.id == changeID }
        try keep(remaining)
    }

    func accountStateChanged() {
        refreshAccountState()
    }
}
