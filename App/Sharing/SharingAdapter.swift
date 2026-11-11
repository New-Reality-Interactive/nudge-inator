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
}

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
        /// The name the other person sees them under.
        var name: String
        /// Whether they share status with the other person (GLOSSARY.md, Status sharing).
        var sharesStatus: Bool
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
