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

    /// What came of the latest invite this person tapped, for the screens to show until
    /// `dismissAcceptance()`, or `nil` when there's nothing to show.
    private(set) var acceptance: InviteAcceptance?

    /// What came of accepting an invite (ticket 195).
    enum InviteAcceptance: Equatable {
        /// The person is connected with whoever invited them.
        case connected(SharingConnection)
        /// The invite no longer includes them: canceled, or someone else accepted it first.
        case unavailable
        /// It couldn't be accepted now; tapping the invite again tries again.
        case failed
    }

    /// The person has seen what came of accepting.
    func dismissAcceptance() {
        acceptance = nil
    }

    /// Whether the connection with this ID is connected: an invite accepted, or one accepted here.
    func isConnected(_ connectionID: UUID) -> Bool {
        data.connections.contains { $0.id == connectionID && $0.state == .connected }
    }

    /// The invites this person is accepting now, and those of them taken off their share meanwhile.
    @ObservationIgnored private var accepting: Set<UUID> = []
    @ObservationIgnored private var withdrawnWhileAccepting: Set<UUID> = []

    /// What sharing can do, for the messages that say it is paused, or `nil` before the adapter
    /// has reported the account.
    var reach: SharingReach? { accountState?.reach }

    private let adapter: any SharingAdapter
    /// When an invite was sent.
    private let clock: any EngineClock
    /// Opens the store, as the reminder store's opener does. A store that won't open is tried
    /// again by whatever needs it next: the account read on App opened, a change coming or going.
    private let openStore: () throws -> SharingStore
    @ObservationIgnored private var store: SharingStore?
    /// The latest read of the account. Each waits for the one before, so reads that overlap can't
    /// finish out of order and put an older state back (as the permission reads do).
    @ObservationIgnored private var accountRefresh: Task<Void, Never>?

    init(adapter: any SharingAdapter, clock: any EngineClock, openStore: @escaping () throws -> SharingStore) {
        self.adapter = adapter
        self.clock = clock
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

    /// What came of Invite Someone.
    enum InviteOutcome: Equatable {
        /// The invite was sent, and the person is listed as Invited.
        case invited(SharingConnection)
        /// The person is already connected, so no second connection was made.
        case alreadyConnected(SharingConnection)
        /// The person closed the sharing sheet: nothing was sent.
        case canceled
    }

    /// Invites one person through the adapter's sharing sheet (ticket 194) and lists them as
    /// Invited. Someone already connected is not connected twice: the sheet's new invite is
    /// revoked and the outcome names them. An invite to someone already Invited, or Invite Again
    /// from the invite with `replacedID`, takes the old invite's place and revokes it. Throws,
    /// keeping nothing, if the store can't be opened (checked before the sheet shows) or keep the
    /// invite, or the invite couldn't be made.
    func invite(replacing replacedID: UUID? = nil) async throws -> InviteOutcome {
        _ = try openedStore()
        let connectionID = UUID()
        guard let person = try await adapter.invite(connectionID) else { return .canceled }
        do {
            // Read after the sheet: the data may have changed while it was up.
            var kept = try currentData()
            if let already = kept.connections.first(where: { $0.state == .connected && $0.isSamePerson(as: person) }) {
                adapter.revokeInvite(connectionID)
                return .alreadyConnected(already)
            }
            let connection = SharingConnection(
                id: connectionID,
                name: person.name,
                state: .invited,
                // Status sharing is on by default (spec #127), until the person's own settings arrive.
                sharesStatus: true,
                address: person.address,
                invitedAt: clock.now
            )
            let replaced = kept.list(connection, replacingInvitesTo: person, or: replacedID)
            try keep(kept)
            replaced.forEach { adapter.revokeInvite($0.id) }
            return .invited(connection)
        } catch {
            // The sheet sent an invite the app can't list, so it mustn't stay working.
            adapter.revokeInvite(connectionID)
            throw error
        }
    }

    /// What Settings › Connections lists, now by the model's clock, with days in `calendar`.
    func connectionsList(calendar: Calendar) -> ConnectionsList {
        ConnectionsList(data, now: clock.now, calendar: calendar)
    }

    /// Cancel Invite: revokes the invite to the connection with `connectionID`, so it stops
    /// working even for someone who already has it, and takes them off the list. Leaves a
    /// connection that is no longer an invite alone: ending one is Disconnect's (#197). Throws,
    /// revoking nothing, if the store can't keep it.
    func cancelInvite(_ connectionID: UUID) throws {
        var kept = try currentData()
        guard kept.connections.contains(where: { $0.id == connectionID && $0.state == .invited }) else { return }
        kept.connections.removeAll { $0.id == connectionID }
        try keep(kept)
        adapter.revokeInvite(connectionID)
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

private extension SharingData {
    /// Lists a new invite: in the place of the invites it replaces (Invite Again's, `replacedID`,
    /// and any other to the same person), or last. Returns the invites it replaced.
    mutating func list(_ connection: SharingConnection, replacingInvitesTo person: InvitedPerson, or replacedID: UUID?) -> [SharingConnection] {
        let replaced = connections.filter { $0.state == .invited && ($0.id == replacedID || $0.isSamePerson(as: person)) }
        if let index = connections.firstIndex(where: { replaced.contains($0) }) {
            connections[index] = connection
            connections.removeAll { replaced.contains($0) }
        } else {
            connections.append(connection)
        }
        return replaced
    }
}

private extension SharingConnection {
    /// Whether the sharing sheet's `person` is this connection's person: the same address, however
    /// it's written. Never the name alone, which two people can share (the developer's call at
    /// #194's phone check, over the mockup's `sendInvite`, which matches either).
    func isSamePerson(as person: InvitedPerson) -> Bool {
        guard let address else { return false }
        return Self.comparable(address) == Self.comparable(person.address)
    }

    /// An email address ignoring case and spaces; a phone number as its digits alone, so
    /// "+1 (555) 010-4477" is "+15550104477".
    static func comparable(_ address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") ? trimmed.lowercased() : trimmed.filter(\.isNumber)
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

    func invited(_ invite: IncomingInvite) async {
        let id = invite.connectionID
        do {
            // Opened first, so a store that won't open accepts nothing.
            if try showsConnection(id) { return }
            accepting.insert(id)
            defer { accepting.remove(id) }
            try await adapter.accept(id)
            // Taken off the share while accepting: someone else was first (spec #127, A6).
            if withdrawnWhileAccepting.remove(id) != nil { throw InviteUnavailable() }
            // Read after accepting: the data may have changed while it waited.
            if try showsConnection(id) { return }
            var kept = try currentData()
            let connection = SharingConnection(
                id: invite.connectionID,
                name: invite.senderName,
                state: .connected,
                // Status sharing is on by default (spec #127), until the person's own settings arrive.
                sharesStatus: true
            )
            kept.connections.append(connection)
            try keep(kept)
            acceptance = .connected(connection)
        } catch is InviteUnavailable {
            acceptance = .unavailable
        } catch {
            // Accepting again does no harm, so tapping the invite again tries it all again.
            Self.logger.error("An invite couldn't be accepted: \(error, privacy: .public)")
            acceptance = .failed
        }
    }

    func inviteAccepted(_ connectionID: UUID, by participant: SharingParticipant) async throws {
        var kept = try currentData()
        // By its ID, never by name: the person accepting has no address for the sender to match.
        guard let index = kept.connections.firstIndex(where: { $0.id == connectionID }) else {
            // Canceled before the acceptance arrived: it stays revoked.
            adapter.revokeInvite(connectionID)
            return
        }
        // Already connected: whoever accepted first was kept, and the rest taken off then.
        guard kept.connections[index].state == .invited else { return }
        kept.connections[index].state = .connected
        try keep(kept)
        adapter.keepOnly(participant, in: connectionID)
    }

    func inviteWithdrawn(_ connectionID: UUID) async throws {
        // Still accepting it: `invited` says it's unavailable once the accept returns, rather than
        // keeping a connection that no longer works.
        if accepting.contains(connectionID) {
            withdrawnWhileAccepting.insert(connectionID)
            return
        }
        var kept = try currentData()
        guard kept.connections.contains(where: { $0.id == connectionID }) else { return }
        kept.connections.removeAll { $0.id == connectionID }
        try keep(kept)
        acceptance = .unavailable
    }

    /// Shows the connection with this ID if it is already connected, and returns whether it did.
    /// Opens the store first.
    private func showsConnection(_ connectionID: UUID) throws -> Bool {
        guard let known = try currentData().connections.first(where: { $0.id == connectionID && $0.state == .connected }) else { return false }
        acceptance = .connected(known)
        return true
    }
}
