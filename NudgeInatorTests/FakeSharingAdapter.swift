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

    /// Every change the app model submitted, in order.
    private(set) var submitted: [SharingChange] = []
    /// Submitted while this iPhone was offline: kept, and uploaded when it comes back.
    private(set) var unsent: [SharingChange] = []

    /// Whether this iPhone can reach iCloud. Coming back online uploads what was kept, in order, and
    /// lets in what waited for this iPhone.
    var isOnline = true {
        didSet {
            guard isOnline, !oldValue else { return }
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

    func accountState() async -> SharingAccountState {
        account
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
    }

    private func upload(_ change: SharingChange) {
        guard let network, let peer else { return }
        let events = events
        network.run { try? await events?.sent(change.entry.id) }
        network.travel(change, to: peer)
    }
}
