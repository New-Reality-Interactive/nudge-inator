import Foundation
import NudgeEngine

/// A person the person is connected with, or has invited (GLOSSARY.md, Connection, Invite).
struct SharingConnection: Equatable {
    var id: UUID
    /// The name the person sees them under.
    var name: String
    var state: State
    /// Whether they share status with the person (GLOSSARY.md, Status sharing).
    var sharesStatus: Bool

    enum State: Equatable {
        /// The invite is sent and not accepted yet.
        case invited
        case connected
    }
}

/// A reminder the person sent, as the sender keeps it. It has no tags and is no one's received
/// copy, so `reminder.tagIDs` is empty and its origin is mine.
struct SentReminder: Equatable {
    var reminder: Reminder
    /// How many times the sender has changed it.
    var revision: Int
}

/// What the sharing store keeps about one received reminder: the person's choice to keep this one's
/// status from its sender (GLOSSARY.md, Status sharing), and what hasn't gone through iCloud yet
/// (Waiting to sync). `reminderID` is the received reminder's ID in the reminder store.
struct ReceivedSyncState: Equatable {
    var reminderID: Reminder.ID
    var notSharingThisOne: Bool
    var waitingToSync: Bool
    /// What the sharing adapter keeps of the reminder's CloudKit records so it can update them: bytes
    /// the store doesn't read.
    var recordSystemFields: Data?
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

    enum Kind: Equatable {
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
}

extension SharingData {
    /// Applies what the other person's app sent to what this person keeps, as far as the store
    /// holds it today: their settings for a connection, and a recipient's receipt and status for a
    /// copy this person sent. Returns whether anything changed. A send, a revision, a cancel and a
    /// disconnect are the recipient's side, which the tickets that build received reminders and
    /// Disconnect (#198, #204, #205, #197) apply: they change nothing here yet.
    mutating func apply(incoming change: SharingChange) -> Bool {
        switch change.content {
        case .settings(let settings):
            guard let index = connections.firstIndex(where: { $0.id == change.connectionID }) else { return false }
            connections[index].name = settings.name
            connections[index].sharesStatus = settings.sharesStatus
            return true
        case .receipt(let receipt):
            guard let index = copyIndex(of: change) else { return false }
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

    private func copyIndex(of change: SharingChange) -> Int? {
        sentCopies.firstIndex { $0.connectionID == change.connectionID && $0.reminderID == change.reminderID }
    }
}
