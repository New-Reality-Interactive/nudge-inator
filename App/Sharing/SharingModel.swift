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
        connection(connectionID) != nil
    }

    /// The connection with this ID if it is connected, or `nil`: an invite, ended, or never made.
    func connection(_ connectionID: UUID) -> SharingConnection? {
        data.connections.first { $0.id == connectionID && $0.state == .connected }
    }

    /// The people a reminder can be sent to (Send To, ticket 198): every connection that is
    /// connected, in the order Connections lists them. Never an invite, nor one the other person ended.
    var connected: [SharingConnection] {
        data.connections.filter { $0.state == .connected }
    }

    /// The invites this person is accepting now, and those of them taken off their share meanwhile.
    @ObservationIgnored private var accepting: Set<UUID> = []
    @ObservationIgnored private var withdrawnWhileAccepting: Set<UUID> = []

    /// What sharing can do, for the messages that say it is paused, or `nil` before the adapter
    /// has reported the account.
    var reach: SharingReach? { accountState?.reach }

    /// Where a received reminder's copy is kept: the app model, which holds the person's reminders
    /// (ticket 198). Held weakly; until it is set, a send that arrives is turned down, and the
    /// adapter offers it again.
    @ObservationIgnored weak var receivedCopies: (any ReceivedCopies)?

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

    /// Send To (ticket 198): sends `reminder` to each person whose connection is in `connectionIDs`,
    /// each getting a copy of their own. It is kept as sent, with one sent copy per person, and never
    /// joins this person's own reminders, so it doesn't nudge them (spec #127, Decisions, Q2). Its
    /// tags stay here: a sent reminder has none. Throws, keeping and sending nothing, if one of them
    /// isn't connected any more, or the store can't keep the send.
    func send(_ reminder: Reminder, to connectionIDs: [UUID]) throws {
        var kept = try currentData()
        guard !connectionIDs.isEmpty, connectionIDs.allSatisfy({ connection($0) != nil }) else { throw NotConnected() }
        var stripped = reminder
        stripped.tagIDs = []
        stripped.origin = .mine
        stripped.createdAt = clock.now
        // Revision 0 is a send; the record mapping reads anything later as a revision (#193).
        let sent = SentReminder(reminder: stripped, revision: 0)
        kept.sentReminders.append(sent)
        let changes = connectionIDs.map { SharingChange.send(sent, to: $0) }
        for connectionID in connectionIDs {
            kept.sentCopies.append(SentCopy(connectionID: connectionID, reminderID: stripped.id, createdAt: clock.now, receipt: .notDelivered, statusRecord: nil, waitingToSync: false))
        }
        kept.outbox.append(contentsOf: changes.map(\.entry))
        try keep(kept)
        changes.forEach(adapter.submit)
    }

    /// Someone chosen in Send To is no longer connected, so nothing was sent.
    struct NotConnected: Error {}

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
            // Both people's choices start as the defaults (spec #127), so neither is sent until changed.
            let connection = SharingConnection(id: connectionID, name: person.name, state: .invited, address: person.address, invitedAt: clock.now)
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

    /// A connection the other person ended, which waits for this person to choose what happens to
    /// what they received from them (ticket 197): the Connection Ended sheet's. The first, if the
    /// other people ended more than one.
    var endedConnection: SharingConnection? {
        data.connections.first { $0.state == .ended }
    }

    /// Disconnect, and the other person's choice on Connection Ended (ticket 197): ends the
    /// connection with `connectionID`, connected or ended by the other person, with what this
    /// person sent through it and the sync states of `receivedIDs` (`SharingData.removeConnection`).
    /// A connection still connected sends the other person a disconnect; one they ended sends
    /// nothing back. Throws, changing and sending nothing, if the store can't keep it.
    func disconnect(_ connectionID: UUID, received receivedIDs: Set<Reminder.ID>) throws {
        var kept = try currentData()
        guard let ended = kept.removeConnection(connectionID, received: receivedIDs) else { return }
        guard ended.state == .connected else { return try keep(kept) }
        let change = SharingChange.disconnect(connectionID)
        kept.outbox.append(change.entry)
        try keep(kept)
        adapter.submit(change)
    }

    /// Changes this person's own Status sharing and Delivery mode for the connection with
    /// `connectionID` (ticket 196), and sends them to the other person, whose app shows them as
    /// theirs. Changes nothing for a connection that isn't connected, or choices already set.
    /// Throws, sending nothing, if the store can't keep the choices and the outbox entry together.
    func change(_ choices: ConnectionChoices, for connectionID: UUID) throws {
        var kept = try currentData()
        guard let index = kept.connections.firstIndex(where: { $0.id == connectionID && $0.state == .connected }),
              kept.connections[index].mine != choices
        else { return }
        kept.connections[index].mine = choices
        let change = SharingChange.settings(.init(choices), for: connectionID)
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

/// Where the copies of reminders this person receives are kept: their own reminders, in the app
/// model (ticket 198).
@MainActor
protocol ReceivedCopies: AnyObject {
    /// The copy held of the sender's reminder with `sendersReminderID`, received through the
    /// connection with `connectionID`, or `nil` when none is. Throws if the reminders haven't been
    /// read, so it can't say.
    func copy(of sendersReminderID: Reminder.ID, through connectionID: UUID) throws -> Reminder?
    /// Keeps `copy` among the person's reminders and plans it as their own. Throws, keeping
    /// nothing, if the reminders haven't been read or the store won't keep it.
    func keep(_ copy: Reminder) throws
}

extension SentReminder {
    /// The recipient's copy of it, received through the connection with `connectionID`: an ID of its
    /// own, the sender's content and no tags, accepted when it starts right away, or else waiting.
    func copy(through connectionID: UUID, startingRightAway: Bool) -> Reminder {
        Reminder(
            title: reminder.title,
            notes: reminder.notes,
            dueTime: reminder.dueTime,
            repeatRule: reminder.repeatRule,
            strength: reminder.strength,
            pace: reminder.pace,
            breakThroughFocus: reminder.breakThroughFocus,
            origin: .received(connectionID: connectionID, sendersReminderID: reminder.id, revision: revision, state: startingRightAway ? .accepted : .waiting)
        )
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
        if case .reminder(let sent) = change.content, change.kind == .send || change.kind == .revise {
            return try receive(sent, through: change.connectionID, isRevision: change.kind == .revise)
        }
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
            // Both people's choices start as the defaults (spec #127), so neither is sent until changed.
            let connection = SharingConnection(id: invite.connectionID, name: invite.senderName, state: .connected, connectedAt: clock.now)
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
        kept.connections[index].connectedAt = clock.now
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

    /// A reminder someone sent through the connection with `connectionID` (ticket 198): kept as a
    /// copy of this person's own, which starts right away or waits, as their Delivery mode for that
    /// connection says, and a receipt saying which goes back (#189's comment on #198). A send already
    /// kept is kept once. A revision of a copy not held yet creates it, since a person offline across
    /// a send and a revision hears of the revision first (#193); applying a revision to a copy held
    /// is #204's. Through a connection that isn't connected, it is ignored.
    ///
    /// The reminder store goes first, so a sharing store that then won't keep the receipt leaves a
    /// copy the next delivery finds, and keeps the receipt then. Throws, for the adapter to offer it
    /// again, if either store can't keep it, or the reminders haven't been read.
    private func receive(_ sent: SentReminder, through connectionID: UUID, isRevision: Bool) throws {
        var kept = try currentData()
        guard let connection = connection(connectionID) else {
            Self.logger.info("A reminder sent through a connection that isn't connected wasn't kept")
            return
        }
        guard let receivedCopies else { throw ReceivedCopiesNotReady() }
        let held = try receivedCopies.copy(of: sent.reminder.id, through: connectionID)
        if held != nil, isRevision { return }
        let copy: Reminder
        if let held {
            copy = held
        } else {
            copy = sent.copy(through: connectionID, startingRightAway: connection.mine.deliveryMode == .startRightAway)
            try receivedCopies.keep(copy)
        }
        guard !kept.receivedSyncStates.contains(where: { $0.reminderID == copy.id }) else { return }
        kept.receivedSyncStates.append(ReceivedSyncState(reminderID: copy.id, notSharingThisOne: false, waitingToSync: false))
        let receipt = SharingChange.receipt(copy.isWaiting ? .waitingForAcceptance : .started, for: sent.reminder.id, from: connectionID)
        kept.outbox.append(receipt.entry)
        try keep(kept)
        adapter.submit(receipt)
    }

    /// The app model hasn't been joined to sharing yet.
    struct ReceivedCopiesNotReady: Error {}

    /// Shows the connection with this ID if it is already connected, and returns whether it did.
    /// Opens the store first.
    private func showsConnection(_ connectionID: UUID) throws -> Bool {
        guard let known = try currentData().connections.first(where: { $0.id == connectionID && $0.state == .connected }) else { return false }
        acceptance = .connected(known)
        return true
    }
}
