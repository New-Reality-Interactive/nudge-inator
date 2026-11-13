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
    /// The iCloud account changed or came back. Read `accountState()` again.
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
    /// Takes a change to send, which the adapter keeps until it has gone through iCloud, however
    /// long that takes, and then reports with `sent(_:)`. The model keeps the change in the outbox
    /// until then.
    func submit(_ change: SharingChange)
    /// Whether the iPhone can reach iCloud now (ticket 211), read at launch, on App opened and when
    /// `connectivityChanged()` says so. A synchronous main-actor read, so it returns a value the
    /// adapter already holds (kept up to date by a path monitor, say) and never asks the system or
    /// iCloud: a synchronous system read froze the app for 69 s once (AlarmKit, ticket 22). Knowing
    /// it makes no iCloud request (spec #127, decision 4); the real adapter's way of knowing is #216's. While it is false, what the model submits waits
    /// with the adapter and in the outbox, and goes when it is back.
    var isOnline: Bool { get }
    /// The iCloud account now, read again at launch, on App opened and when `accountStateChanged()`
    /// says so. Async: asking iCloud may take a while, and it mustn't hold up the app.
    func accountState() async -> SharingAccountState
    /// Starts an invite to one person, for a new connection with this ID (ticket 194): the real
    /// adapter makes the connection's share and shows the system sharing sheet for it (#217).
    /// Returns who the sheet sent it to once it has, or `nil` if the person canceled the sheet.
    /// Throws if the invite couldn't be made, and then nothing was sent.
    func invite(_ connectionID: UUID) async throws -> InvitedPerson?
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

/// Who an invite went to, as the system sharing sheet named them (ticket 194).
struct InvitedPerson: Equatable {
    /// Their name, or their address when the sheet had no name for them.
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
        /// always from the app model: the CloudKit adapter can fill it in (#216). The other
        /// person's app keeps the name the sharing sheet or the invite gave (ticket 196).
        var name: String?
        /// Their Status sharing and Delivery mode for what the other person sends them.
        var choices: ConnectionChoices

        init(name: String? = nil, _ choices: ConnectionChoices) {
            self.name = name
            self.choices = choices
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
}
