import Foundation
import NudgeEngine

/// What the sharing code reports to the app model, which owns what sharing keeps (ticket 192). The
/// adapter holds it weakly.
@MainActor
protocol SharingAdapterEvents: AnyObject {
    /// A change the other person made reached this iPhone. Returns once it is kept, and the adapter
    /// may then forget it. Throws if it couldn't be kept (the sharing store won't open or save), and
    /// the adapter then holds the change and offers it again.
    func received(_ change: SharingChange) async throws
    /// A change went through iCloud, so it is no longer Waiting to sync (GLOSSARY.md). Names the
    /// outbox entry (`OutboxChange.id`). Throws if the store couldn't keep that, and the adapter
    /// then reports it again.
    func sent(_ changeID: OutboxChange.ID) async throws
    /// iCloud refused a change for good, so it never goes and counts as gone (#396): the model
    /// takes it out of the outbox as `sent(_:)` does, and records it in the Share Activity record.
    /// Names the outbox entry. Throws if the store couldn't keep that, and the adapter then reports
    /// it again.
    func gaveUp(_ changeID: OutboxChange.ID) async throws
    /// The iCloud account changed or came back. Read `signedInAccount()` again.
    func accountStateChanged()
    /// The iPhone went offline or came back (ticket 211). Read `isOnline` again.
    func connectivityChanged()
    /// The person tapped an invite to them and iCloud opened the app with it: the system hand-off,
    /// which the real adapter has from the scene delegate (#217). The model accepts it with
    /// `accept(_:)` and says what came of it, so this never throws.
    func invited(_ invite: IncomingInvite) async
    /// Someone accepted this person's invite to the connection with this ID (ticket 195). Throws if
    /// the store couldn't keep that, and the adapter then reports it again.
    func inviteAccepted(_ connectionID: UUID, by participant: SharingParticipant) async throws
    /// This person was taken off a connection's share they had accepted, because someone else
    /// accepted that invite first or it was canceled (spec #127, A6), so it no longer works for
    /// them. Throws if the store couldn't keep that, and the adapter then reports it again.
    func inviteWithdrawn(_ connectionID: UUID) async throws
    /// What the adapter last asked the sharing store to keep for it, empty if nothing, or `nil`
    /// while the store won't open.
    func savedSyncState() -> SharingSyncState?
    /// Keeps the adapter's own state (#216) in the sharing store, so a relaunch carries on where
    /// it left off. Throws if the store couldn't keep it, and the adapter then asks again on its
    /// next change.
    func keepSyncState(_ state: SharingSyncState) throws
    /// The ID of every connection the sharing store lists, in any state, or `nil` while the store
    /// won't open. An invite of this person's that isn't among them was left over (#400).
    func listedConnectionIDs() -> Set<UUID>?
}

/// The one door to sharing, in the shape of the alarm and notification adapters: the app model
/// hands it changes and hears of incoming ones and of the iCloud account, and nothing else touches
/// the code behind it, which is the only place that talks to iCloud (#216). The model never asks
/// the system about iCloud itself.
///
/// `@MainActor`, like the app model that owns it.
@MainActor
protocol SharingAdapter: AnyObject {
    /// Held weakly by the adapter.
    var events: (any SharingAdapterEvents)? { get set }
    /// Starts syncing: the real adapter asks iCloud from here on (#216). The app model calls it only
    /// once the person opens Connections or an invite reaches them, or the sharing store holds
    /// sharing already (spec #127, decision 4). Calling it again does nothing.
    func start()
    /// Stops syncing for good, as Settings' Sharing switch turning off does (#387): the real adapter
    /// lets its engines go and stops watching the network. The model lets the adapter go after it.
    func stop()
    /// Whether a disconnect or a revoked invite is still waiting to reach iCloud, however long ago
    /// it was submitted, a relaunch included: a model winding down after Settings' Sharing switch
    /// turned off (#388) stops the adapter only once there's none. A synchronous read of what the
    /// adapter already holds, asking iCloud nothing.
    var hasUnsentDisconnects: Bool { get }
    /// Whether the adapter holds an invite whose share is in iCloud with the person on it, though
    /// the app model doesn't list it: the app was closed while its compose screen was up, so the
    /// link was never sent (#400). `start()` revokes it, so the model starts the adapter at launch
    /// while there's one. A synchronous read of what the sharing store kept, asking iCloud nothing.
    /// An invite made after the start is one under way, never a leftover.
    var holdsLeftoverInvite: Bool { get }
    /// Takes a change to send, which the adapter keeps until it has gone through iCloud, however
    /// long that takes, and then reports with `sent(_:)`. The model keeps the change in the outbox
    /// until then.
    func submit(_ change: SharingChange)
    /// The app is syncing: sends the other person's app a Heartbeat (GLOSSARY.md) for each of
    /// `choices`' connections, the connected ones this person's Status sharing is on for (#435),
    /// each with this person's choices for it, which the adapter uses only to make the settings
    /// record when it holds none, so a Heartbeat never writes defaults over real choices. The
    /// adapter makes it at most once a day, by iCloud's stamp of the last one rather than a phone's
    /// clock, and it is no change of the outbox. `now` is the app's clock. Called at launch and on
    /// App opened, once the account is available and the app may ask iCloud.
    func heartbeat(for choices: [UUID: ConnectionChoices], at now: Date)
    /// Whether the iPhone can reach iCloud now (ticket 211), read at launch, on App opened and when
    /// `connectivityChanged()` says so. A synchronous main-actor read, so it returns a value the
    /// adapter already holds (kept up to date by a path monitor, say) and never asks the system or
    /// iCloud: a synchronous system read froze the app for 69 s once (AlarmKit, ticket 22). Knowing
    /// it makes no iCloud request (spec #127, decision 4): the real adapter watches the network path.
    /// While it is false, what the model submits waits with the adapter and in the outbox, and goes
    /// when it is back.
    var isOnline: Bool { get }
    /// The iCloud account now, read again at launch, on App opened and when `accountStateChanged()`
    /// says so. Async: asking iCloud may take a while, and it mustn't hold up the app.
    func signedInAccount() async -> SharingAccount
    /// Makes the invite to `person`, for a new connection with this ID (ticket 194), and delivers it
    /// by `route` (#217): the real adapter makes the connection's private share, adds the person to
    /// it and hands the share's link to iOS's compose screen or the clipboard. Returns `true` once
    /// the invite is delivered, or `false` if the person canceled the delivery, and then nothing was
    /// sent and the adapter has revoked the invite. Throws if the invite couldn't be made, and then
    /// nothing was sent either.
    func invite(_ connectionID: UUID, to person: InvitedPerson, via route: InviteRoute) async throws -> Bool
    /// Stops the connection's invite working, even for someone who already has it. The adapter
    /// keeps the revoke until it has gone through iCloud, as it keeps a change.
    func revokeInvite(_ connectionID: UUID)
    /// Accepts the invite to the connection with this ID, which `invited(_:)` reported (ticket 195).
    /// Throws `InviteUnavailable` when the invite no longer includes this person (canceled, or
    /// someone else accepted it first), or another error when it couldn't be accepted now.
    /// Accepting an invite already accepted does no harm.
    func accept(_ connectionID: UUID) async throws
    /// Takes everyone but `participant` off the connection's share, whether they accepted or not,
    /// so the invite is unavailable to them (spec #127, A6: one person per invite, the first to
    /// accept). The adapter keeps it until it has gone through iCloud, as it keeps a revoke.
    func keepOnly(_ participant: SharingParticipant, in connectionID: UUID)
}

/// The iCloud account as the adapter reports it (tickets 210 and 212): its state, and which Apple
/// Account it is, so a different one signing in can be told from the same one signing in again.
struct SharingAccount: Equatable {
    var state: SharingAccountState
    /// iCloud's ID for the signed-in Apple Account (the real adapter's user record name), or `nil`
    /// when the adapter doesn't know it: no account is available, or it hasn't asked iCloud yet,
    /// which it doesn't before the app may make a request (spec #127, decision 4). `nil` changes
    /// nothing.
    var id: AppleAccountID?

    init(state: SharingAccountState, id: AppleAccountID?) {
        self.state = state
        self.id = id
    }

    /// The account in `state`, with `id` only while it is available: no other state has an account
    /// to name.
    init(state: SharingAccountState, idWhenAvailable id: AppleAccountID) {
        self.init(state: state, id: state == .available ? id : nil)
    }
}

/// iCloud's ID for one Apple Account (for the real adapter, its user record's name), which the app
/// only compares: a different one means a different person's iCloud.
struct AppleAccountID: Hashable {
    var rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

/// An invite that reached this person (ticket 195), as the system hand-off names it.
struct IncomingInvite: Equatable {
    /// The connection the invite is for: the same ID on both people's iPhones.
    var connectionID: UUID
    /// The sender, as iCloud names them to this person.
    var senderName: String
}

/// Who accepted an invite: iCloud's ID for their account, which the app only hands back.
struct SharingParticipant: Hashable {
    var id: String
}

/// The invite no longer includes this person: canceled, or someone else accepted it first.
struct InviteUnavailable: Error {}

/// Who an invite is for (ticket 194): a contact the person chose, or an address they typed.
struct InvitedPerson: Equatable {
    /// Their name, or their address when the app has no name for them.
    var name: String
    /// The email address or phone number of the Apple Account the invite was sent to.
    var address: String
}

/// A change that crosses between the two people's apps, whichever way. Its `entry` is what the
/// sharing store's outbox keeps of it (the seven kinds are the outbox's); the content is what the
/// other app needs to apply it. Made only by the functions below, so the content always fits the kind.
struct SharingChange: Equatable {
    /// Its ID, kind, connection and, for a change to one reminder, the reminder.
    let entry: OutboxChange
    let content: Content

    enum Content: Equatable {
        /// A cancel or a disconnect: the entry says it all.
        case none
        /// A disconnect that is not the other person's doing: the connection's zone is gone from
        /// iCloud, which lost it (#396). Only ever incoming.
        case lost
        /// A send or a revision: the sender's reminder as it now stands.
        case reminder(SentReminder)
        /// The recipient's receipt for the copy.
        case receipt(SentCopy.Receipt)
        /// The recipient's status for the copy, or `nil` when it is deleted (status sharing turned off).
        case status(SentCopy.StatusRecord?)
        /// A person's settings for the connection.
        case settings(ConnectionSettings)
    }

    /// A person's own choices for one connection, which the other person's app shows.
    struct ConnectionSettings: Equatable {
        /// The person's name as iCloud gives it, or `nil` when the app doesn't know it, which is
        /// always from the app model. The other person's app keeps the name the sharing sheet or
        /// the invite gave (ticket 196).
        var name: String?
        /// Their Status sharing and Delivery mode for what the other person sends them.
        var choices: ConnectionChoices
        /// When iCloud last received the person's app, from the heartbeat on their settings record
        /// (#435), or `nil` when it carries none: their Status sharing is off. Only on settings that
        /// arrive; the model sends none.
        var lastSynced: Date?

        init(name: String? = nil, _ choices: ConnectionChoices, lastSynced: Date? = nil) {
            self.name = name
            self.choices = choices
            self.lastSynced = lastSynced
        }
    }

    var kind: OutboxChange.Kind { entry.kind }
    var connectionID: UUID { entry.connectionID }
    var reminderID: Reminder.ID? { entry.reminderID }

    private init(id: UUID, kind: OutboxChange.Kind, connectionID: UUID, reminderID: Reminder.ID? = nil, content: Content = .none) {
        entry = OutboxChange(id: id, kind: kind, connectionID: connectionID, reminderID: reminderID)
        self.content = content
    }

    /// The sender's reminder, sent to the person the connection is with.
    static func send(_ sent: SentReminder, to connectionID: UUID, id: UUID = UUID()) -> SharingChange {
        SharingChange(id: id, kind: .send, connectionID: connectionID, reminderID: sent.reminder.id, content: .reminder(sent))
    }

    /// The sender's change to a reminder already sent.
    static func revise(_ sent: SentReminder, for connectionID: UUID, id: UUID = UUID()) -> SharingChange {
        SharingChange(id: id, kind: .revise, connectionID: connectionID, reminderID: sent.reminder.id, content: .reminder(sent))
    }

    /// The sender deleted the reminder, so the person's copy is canceled.
    static func cancel(_ reminderID: Reminder.ID, for connectionID: UUID, id: UUID = UUID()) -> SharingChange {
        SharingChange(id: id, kind: .cancel, connectionID: connectionID, reminderID: reminderID)
    }

    static func receipt(_ receipt: SentCopy.Receipt, for reminderID: Reminder.ID, from connectionID: UUID, id: UUID = UUID()) -> SharingChange {
        SharingChange(id: id, kind: .receipt, connectionID: connectionID, reminderID: reminderID, content: .receipt(receipt))
    }

    static func status(_ status: SentCopy.StatusRecord?, for reminderID: Reminder.ID, from connectionID: UUID, id: UUID = UUID()) -> SharingChange {
        SharingChange(id: id, kind: .status, connectionID: connectionID, reminderID: reminderID, content: .status(status))
    }

    static func settings(_ settings: ConnectionSettings, for connectionID: UUID, id: UUID = UUID()) -> SharingChange {
        SharingChange(id: id, kind: .settings, connectionID: connectionID, content: .settings(settings))
    }

    static func disconnect(_ connectionID: UUID, id: UUID = UUID()) -> SharingChange {
        SharingChange(id: id, kind: .disconnect, connectionID: connectionID)
    }

    /// The connection ended because iCloud lost it, not because the other person disconnected
    /// (#396). Only the adapter makes it, for the model to apply as a disconnect and say so.
    static func connectionLost(_ connectionID: UUID, id: UUID = UUID()) -> SharingChange {
        SharingChange(id: id, kind: .disconnect, connectionID: connectionID, content: .lost)
    }
}
