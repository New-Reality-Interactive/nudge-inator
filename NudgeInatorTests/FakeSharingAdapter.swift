import Foundation
import NudgeEngine
@testable import NudgeInator

/// Stands in for iCloud between two people's apps (ticket 192, spec #127 seam 1): joins two
/// `FakeSharingAdapter`s, one on each person's iPhone. A change a person's app submits is uploaded
/// when that iPhone is online, which is when the adapter says it was sent; it then travels to the
/// other iPhone, where it is delivered when that one is online. In between it can be held, delayed,
/// reordered or dropped, as the test says.
///
/// Nothing moves on its own while `holdsDeliveries` is set. Tests call `settle()` after each action
/// so everything that is going to happen has.
@MainActor
final class FakeSharingNetwork {
    /// A change uploaded and on its way to `recipient`'s iPhone.
    struct Delivery {
        let change: SharingChange
        let recipient: FakeSharingAdapter
    }

    /// What travels, oldest first: the order it was uploaded in, until a test reorders it.
    private(set) var inFlight: [Delivery] = []
    /// While set, an uploaded change waits in `inFlight` until a test delivers it.
    var holdsDeliveries = false {
        didSet { if !holdsDeliveries { deliverAll() } }
    }
    /// The latest report. Each waits for the one before, so reports finish in the order they were
    /// made: unstructured tasks don't promise to start in order.
    private var latest: Task<Void, Never>?

    func join(_ first: FakeSharingAdapter, _ second: FakeSharingAdapter) {
        first.network = self
        second.network = self
        first.peer = second
        second.peer = first
    }

    /// Joins two iPhones through the connection with `connectionID` alone, so one iPhone can be
    /// joined to several people, each through their own connection (ticket 198: one send to two).
    /// A change for that connection goes to the other; any other change goes to the `peer` `join`
    /// gave, if any.
    func join(_ first: FakeSharingAdapter, _ second: FakeSharingAdapter, through connectionID: UUID) {
        first.network = self
        second.network = self
        first.peers[connectionID] = second
        second.peers[connectionID] = first
    }

    /// Puts an iPhone on the network with no one to send to yet: accepting an invite joins it to
    /// the sender's.
    func add(_ adapter: FakeSharingAdapter) {
        adapter.network = self
    }

    /// One connection's share, as iCloud holds it (ticket 195).
    private final class Share {
        let owner: FakeSharingAdapter
        let ownerName: String
        /// Everyone the share still includes: the people the sheet named, until they're taken off.
        var participants: [FakeSharingAdapter]
        /// The participants who have accepted, in the order they did.
        var accepted: [FakeSharingAdapter] = []

        func includes(_ recipient: FakeSharingAdapter) -> Bool { participants.contains { $0 === recipient } }
        func hasAccepted(_ recipient: FakeSharingAdapter) -> Bool { accepted.contains { $0 === recipient } }

        init(owner: FakeSharingAdapter, ownerName: String, participants: [FakeSharingAdapter]) {
            self.owner = owner
            self.ownerName = ownerName
            self.participants = participants
        }
    }

    private var shares: [UUID: Share] = [:]

    /// The sender's sheet sent the invite to the connection with `connectionID` to `recipients`,
    /// from the sender as iCloud names them (`senderName`). Nobody has tapped it yet.
    func share(_ connectionID: UUID, from sender: FakeSharingAdapter, senderName: String, with recipients: [FakeSharingAdapter]) {
        shares[connectionID] = Share(owner: sender, ownerName: senderName, participants: recipients)
    }

    /// The recipient taps the invite, and iCloud hands it to their app, as the system hand-off does.
    /// Only someone the sheet named gets it: iCloud refuses anyone else before the app opens.
    func tapInvite(_ connectionID: UUID, on recipient: FakeSharingAdapter) {
        guard let share = shares[connectionID], share.includes(recipient) || share.hasAccepted(recipient) else { return }
        let invite = IncomingInvite(connectionID: connectionID, senderName: share.ownerName)
        let events = recipient.events
        run { await events?.invited(invite) }
    }

    fileprivate func accept(_ connectionID: UUID, by recipient: FakeSharingAdapter) throws {
        guard let share = shares[connectionID], share.includes(recipient) else {
            throw InviteUnavailable()
        }
        guard !share.hasAccepted(recipient) else { return }
        share.accepted.append(recipient)
        let events = share.owner.events
        let participant = recipient.participant
        run { try? await events?.inviteAccepted(connectionID, by: participant) }
    }

    fileprivate func keepOnly(_ participant: SharingParticipant, in connectionID: UUID) {
        guard let share = shares[connectionID] else { return }
        let removed = share.participants.filter { $0.participant != participant }
        share.participants.removeAll { $0.participant != participant }
        withdraw(removed, from: share, connectionID)
        if let kept = share.participants.first {
            join(share.owner, kept)
        }
    }

    fileprivate func revoke(_ connectionID: UUID) {
        guard let share = shares.removeValue(forKey: connectionID) else { return }
        withdraw(share.participants, from: share, connectionID)
    }

    /// Tells each of `removed` who had accepted that the invite no longer works for them.
    private func withdraw(_ removed: [FakeSharingAdapter], from share: Share, _ connectionID: UUID) {
        for recipient in removed where share.hasAccepted(recipient) {
            let events = recipient.events
            run { try? await events?.inviteWithdrawn(connectionID) }
        }
        share.accepted.removeAll { recipient in removed.contains { $0 === recipient } }
    }

    /// Waits until every report made so far has finished.
    func settle() async {
        while let task = latest {
            await task.value
            if latest == task { latest = nil }
        }
    }

    fileprivate func run(_ work: @escaping @MainActor () async -> Void) {
        let previous = latest
        latest = Task {
            await previous?.value
            await work()
        }
    }

    fileprivate func travel(_ change: SharingChange, to recipient: FakeSharingAdapter) {
        inFlight.append(Delivery(change: change, recipient: recipient))
        if !holdsDeliveries { deliverAll() }
    }

    /// Delivers everything that can be: what is in flight to an iPhone that is online, in order.
    func deliverAll() {
        for delivery in inFlight where delivery.recipient.isOnline {
            deliver(delivery)
        }
    }

    /// Delivers the change at `index` alone, ahead of the ones before it.
    func deliver(at index: Int) {
        guard inFlight.indices.contains(index), inFlight[index].recipient.isOnline else { return }
        deliver(inFlight[index])
    }

    /// Loses the change at `index`: it is never delivered, though its sender was told it went through.
    func drop(at index: Int) {
        guard inFlight.indices.contains(index) else { return }
        inFlight.remove(at: index)
    }

    /// Moves a change in flight, so it arrives in a different order.
    func move(from source: Int, to destination: Int) {
        guard inFlight.indices.contains(source), inFlight.indices.contains(destination) else { return }
        inFlight.insert(inFlight.remove(at: source), at: destination)
    }

    private func deliver(_ delivery: Delivery) {
        inFlight.removeAll { $0.change.entry.id == delivery.change.entry.id }
        let events = delivery.recipient.events
        // A change the app couldn't keep isn't offered again by this fake: a test that cares calls
        // the model's `received` itself.
        run { try? await events?.received(delivery.change) }
    }
}

/// One person's end of the fake: what the app model talks to in place of the CloudKit adapter.
@MainActor
final class FakeSharingAdapter: SharingAdapter {
    weak var events: (any SharingAdapterEvents)?
    fileprivate var network: FakeSharingNetwork?
    fileprivate var peer: FakeSharingAdapter?
    /// The other iPhone of each connection `join(_:_:through:)` joined, ahead of `peer`.
    fileprivate var peers: [UUID: FakeSharingAdapter] = [:]

    /// Every change the app model submitted, in order.
    private(set) var submitted: [SharingChange] = []
    /// Submitted while this iPhone was offline: kept, and uploaded when it comes back.
    private(set) var unsent: [SharingChange] = []

    /// Whether this iPhone can reach iCloud. A change tells the app model, as the real adapter's
    /// does (ticket 211). Coming back online uploads what was kept, in order, and lets in what
    /// waited for this iPhone.
    var isOnline = true {
        didSet {
            guard isOnline != oldValue else { return }
            events?.connectivityChanged()
            guard isOnline else { return }
            let kept = unsent
            unsent = []
            kept.forEach(upload)
            network?.deliverAll()
        }
    }

    /// The iCloud account the adapter reports. A change tells the app model, as the real one does.
    var account = SharingAccountState.available {
        didSet {
            guard account != oldValue, tellsTheApp else { return }
            events?.accountStateChanged()
        }
    }
    private var tellsTheApp = true

    /// iCloud's ID for the Apple Account signed in on this iPhone, reported while `account` is available.
    private(set) var accountID = AppleAccountID(UUID().uuidString)

    /// A different Apple Account signs in on this iPhone (ticket 212), and the app is told unless
    /// `tellingTheApp` is false, as for a change made in Settings while the app was suspended. What
    /// waited to upload under the old account is dropped, as `CKSyncEngine` drops its pending
    /// changes when the account changes: the new account never sends it.
    func signIn(as id: String, tellingTheApp: Bool = true) {
        unsent = []
        accountID = AppleAccountID(id)
        self.tellsTheApp = false
        account = .available
        self.tellsTheApp = true
        if tellingTheApp { events?.accountStateChanged() }
    }

    /// A change of account the app is not told of, as one made in Settings while the app was suspended.
    func setAccountWithoutTellingTheApp(_ state: SharingAccountState) {
        tellsTheApp = false
        account = state
        tellsTheApp = true
    }

    func submit(_ change: SharingChange) {
        submitted.append(change)
        if isOnline {
            upload(change)
        } else {
            unsent.append(change)
        }
    }

    func signedInAccount() async -> SharingAccount {
        SharingAccount(state: account, idWhenAvailable: accountID)
    }

    /// What the system sharing sheet does when the app starts an invite.
    enum InviteAnswer {
        /// The person sent the invite to someone.
        case names(InvitedPerson)
        /// The person closed the sheet.
        case canceled
        /// The invite couldn't be made.
        case fails
    }

    struct InviteFailed: Error {}

    /// How the next invites are answered.
    var inviteAnswer = InviteAnswer.canceled
    /// The connection of every invite the app started, in order.
    private(set) var invites: [UUID] = []
    /// The connection of every invite the app revoked, in order.
    private(set) var revoked: [UUID] = []

    func invite(_ connectionID: UUID) async throws -> InvitedPerson? {
        invites.append(connectionID)
        switch inviteAnswer {
        case .names(let person): return person
        case .canceled: return nil
        case .fails: throw InviteFailed()
        }
    }

    func revokeInvite(_ connectionID: UUID) {
        revoked.append(connectionID)
        network?.revoke(connectionID)
    }

    /// iCloud's ID for this iPhone's account.
    let participant = SharingParticipant(id: UUID().uuidString)
    /// While set, accepting fails as if iCloud couldn't be reached.
    var acceptFails = false
    struct AcceptFailed: Error {}
    /// Every participant the app kept on a connection's share, in order.
    private(set) var keptOnly: [(participant: SharingParticipant, connectionID: UUID)] = []

    /// Runs once iCloud has taken the accept and before it returns: what a real adapter reports
    /// meanwhile can arrive then.
    var duringAccept: (() async -> Void)?

    func accept(_ connectionID: UUID) async throws {
        guard !acceptFails else { throw AcceptFailed() }
        guard let network else { throw InviteUnavailable() }
        try network.accept(connectionID, by: self)
        await duringAccept?()
    }

    func keepOnly(_ participant: SharingParticipant, in connectionID: UUID) {
        keptOnly.append((participant, connectionID))
        network?.keepOnly(participant, in: connectionID)
    }

    private func upload(_ change: SharingChange) {
        guard let network, let peer = peers[change.connectionID] ?? peer else { return }
        let events = events
        network.run { try? await events?.sent(change.entry.id) }
        network.travel(change, to: peer)
    }
}
