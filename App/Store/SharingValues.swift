import Foundation
import NudgeEngine

/// A person the person is connected with, or has invited (GLOSSARY.md, Connection, Invite).
struct SharingConnection: Equatable, Identifiable {
    var id: UUID
    /// The name the person sees them under.
    var name: String
    var state: State
    /// This person's own choices for what they receive from the other person, which the other
    /// person's app shows as theirs.
    var mine = ConnectionChoices()
    /// The other person's choices for what they receive from this person, as they last arrived.
    /// Their Status sharing is what the Sent read-out reads (`SentConnection.sharesStatus`).
    var theirs = ConnectionChoices()
    /// The email address or phone number of the Apple Account this person's invite went to, as the
    /// sharing sheet named it, or `nil` when the other person did the inviting.
    var address: String? = nil
    /// When this person sent the invite, or `nil` when the other person did the inviting.
    var invitedAt: Date? = nil
    /// When the connection was made on this iPhone, or `nil` while it is an invite.
    var connectedAt: Date? = nil

    enum State: Equatable {
        /// The invite is sent and not accepted yet.
        case invited
        case connected
        /// The other person disconnected (ticket 197). It stays until this person has chosen what
        /// happens to what they received from them, on the Connection Ended sheet.
        case ended
    }
}

/// One person's settings for a connection, set by the recipient for what they receive (spec #127,
/// Per-connection settings): Status sharing, on by default, and Delivery mode, Start right away by
/// default (GLOSSARY.md).
struct ConnectionChoices: Equatable {
    var sharesStatus = true
    var deliveryMode = DeliveryMode.startRightAway
}

/// A reminder the person sent, as the sender keeps it. It has no tags and is no one's received
/// copy, so `reminder.tagIDs` is empty and its origin is mine.
struct SentReminder: Equatable {
    var reminder: Reminder
    /// How many times the sender has changed it.
    var revision: Int
    /// What the sender's latest change did (GLOSSARY.md, Change note). Empty before any change.
    var changeNote: [ReceivedChange] = []
}

/// What the sharing store keeps about one received reminder: the person's choice to keep this one's
/// status from its sender (GLOSSARY.md, Status sharing). Whether it is Waiting to sync is the
/// outbox's (ticket 211). `reminderID` is the received reminder's ID in the reminder store.
struct ReceivedSyncState: Equatable {
    var reminderID: Reminder.ID
    var notSharingThisOne: Bool
    /// What the sharing adapter keeps of the reminder's CloudKit records so it can update them: bytes
    /// the store doesn't read.
    var recordSystemFields: Data?
    /// What the sender's latest change did to this copy, or `nil` while nobody has changed it.
    var changeNote: ReceivedChangeNote?
}

/// What a received reminder shows after a sender's revision (GLOSSARY.md, Change note): the fields
/// that changed with their old and new values, and when the copy took the change. The latest change
/// only: a later one replaces it.
struct ReceivedChangeNote: Equatable {
    var changes: [ReceivedChange]
    var at: Date
}

/// `CKSyncEngine`'s saved state for one database, as the adapter serialized it: bytes the store
/// doesn't read.
struct SyncEngineState: Equatable {
    var database: Database
    var data: Data

    /// The two databases the app syncs: its own, and the one other people's shared zones appear in.
    enum Database: Equatable {
        case `private`
        case shared
    }
}

/// A change that has not gone to iCloud yet, in the queue of them. A change names its connection and,
/// for a change to one reminder, the reminder.
struct OutboxChange: Equatable, Identifiable {
    var id: UUID
    var kind: Kind
    var connectionID: UUID
    var reminderID: Reminder.ID?

    enum Kind: Hashable {
        case send
        case revise
        case cancel
        case receipt
        case status
        case settings
        case disconnect
    }
}

/// Everything the sharing store keeps.
struct SharingData: Equatable {
    var connections: [SharingConnection] = []
    var sentReminders: [SentReminder] = []
    var sentCopies: [SentCopy] = []
    var receivedSyncStates: [ReceivedSyncState] = []
    var engineStates: [SyncEngineState] = []
    /// Oldest first.
    var outbox: [OutboxChange] = []
    /// iCloud's ID for the Apple Account all of the above belongs to (ticket 212), or `nil` before
    /// the adapter has reported one.
    var accountID: AppleAccountID?
    /// What a different Apple Account signing in removed from this iPhone, kept until the person has
    /// seen the note, or `nil` when there's nothing to tell them.
    var accountChangeNote: AccountChangeNote?
}

/// What the Apple Account Changed note says was removed from this iPhone when a different account
/// signed in (ticket 212, spec #127 decision A13): the old account's sharing, all of it.
struct AccountChangeNote: Hashable, Codable {
    /// How many received reminders were removed, with their nudges and alarms.
    var receivedCount: Int
    /// The names of the people they were from, in the order Connections listed them.
    var senders: [String]
    /// The names of the connections removed, invites among them, in the order Connections listed them.
    var connections: [String]
    /// How many reminders this person had sent.
    var sentCount: Int
}

extension SharingData {
    /// Applies what the other person's app sent to what this person keeps, as far as the store
    /// holds it today: their settings for a connection, a recipient's receipt and status for a
    /// copy this person sent, and their disconnect, which leaves the connection ended until this
    /// person chooses what happens to what they received (ticket 197). Returns whether anything
    /// changed. A send, a revision and a cancel are the recipient's side: `SharingModel` keeps a
    /// send's copy among the person's reminders, and applies a revision to it with its change note,
    /// and cancels it on a cancel, before it gets here (tickets 198, 204 and 205).
    ///
    /// The other person's settings set their choices, never the name: the name a person sees stays
    /// the one the sharing sheet or the invite gave (ticket 196).
    mutating func apply(incoming change: SharingChange) -> Bool {
        // Ahead of the content: a disconnect carries none, nor does a cancel, so only its kind
        // tells them apart.
        if change.kind == .disconnect {
            guard let index = connections.firstIndex(where: { $0.id == change.connectionID && $0.state == .connected }) else { return false }
            connections[index].state = .ended
            return true
        }
        switch change.content {
        case .settings(let settings):
            guard let index = connections.firstIndex(where: { $0.id == change.connectionID }) else { return false }
            connections[index].theirs = settings.choices
            return true
        case .receipt(let receipt):
            guard let index = copyIndex(of: change) else { return false }
            // A copy that started never waits again: a waiting receipt after it came late (ticket 203).
            if receipt == .waitingForAcceptance, sentCopies[index].receipt == .started { return false }
            sentCopies[index].receipt = receipt
            return true
        case .status(let record):
            guard let index = copyIndex(of: change) else { return false }
            sentCopies[index].statusRecord = record
            return true
        case .none, .reminder:
            return false
        }
    }

    /// Takes off the connection with `connectionID`, connected or ended by the other person, with
    /// what this person sent through it: its sent copies, and a sent reminder left with no one to go
    /// to. The received reminders' sync states in `receivedIDs` go too: Remove deletes those
    /// reminders and Keep makes them personal, so none is received any more. Returns the connection
    /// as it was, or `nil` when there's no such connection, or it's an invite (Cancel Invite's).
    mutating func removeConnection(_ connectionID: UUID, received receivedIDs: Set<Reminder.ID>) -> SharingConnection? {
        guard let removed = connections.first(where: { $0.id == connectionID && $0.state != .invited }) else { return nil }
        connections.removeAll { $0.id == connectionID }
        let sentThrough = Set(sentCopies.filter { $0.connectionID == connectionID }.map(\.reminderID))
        sentCopies.removeAll { $0.connectionID == connectionID }
        let stillSent = Set(sentCopies.map(\.reminderID))
        sentReminders.removeAll { sentThrough.contains($0.reminder.id) && !stillSent.contains($0.reminder.id) }
        receivedSyncStates.removeAll { receivedIDs.contains($0.reminderID) }
        return removed
    }

    /// Changes the received reminder's sync state with `reminderID`, adding one first if the store
    /// holds none.
    mutating func updateReceivedState(of reminderID: Reminder.ID, _ update: (inout ReceivedSyncState) -> Void) {
        if let index = receivedSyncStates.firstIndex(where: { $0.reminderID == reminderID }) {
            update(&receivedSyncStates[index])
        } else {
            var state = ReceivedSyncState(reminderID: reminderID, notSharingThisOne: false)
            update(&state)
            receivedSyncStates.append(state)
        }
    }

    /// Whether the sent `copy` is Waiting to sync (ticket 211): its send or a revision of it is still
    /// in the outbox.
    func waitsToSync(_ copy: SentCopy) -> Bool {
        hasInOutbox([.send, .revise], for: copy.reminderID, through: copy.connectionID)
    }

    /// Whether the received `copy` is Waiting to sync (ticket 211): its receipt or a status this
    /// person's app sends its sender is still in the outbox. Never for the person's own.
    func waitsToSync(received copy: Reminder) -> Bool {
        guard let connectionID = copy.receivedThrough, let sendersReminderID = copy.sendersReminderID else { return false }
        return hasInOutbox([.receipt, .status], for: sendersReminderID, through: connectionID)
    }

    /// Whether the outbox holds a change of one of `kinds` to the sender's reminder with
    /// `reminderID`, through the connection with `connectionID`.
    private func hasInOutbox(_ kinds: Set<OutboxChange.Kind>, for reminderID: Reminder.ID, through connectionID: UUID) -> Bool {
        outbox.contains { kinds.contains($0.kind) && $0.connectionID == connectionID && $0.reminderID == reminderID }
    }

    private func copyIndex(of change: SharingChange) -> Int? {
        sentCopies.firstIndex { $0.connectionID == change.connectionID && $0.reminderID == change.reminderID }
    }
}
