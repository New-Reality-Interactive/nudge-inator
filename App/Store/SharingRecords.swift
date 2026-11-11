import Foundation
import SwiftData

/// A connection as SwiftData saves it in the sharing store.
@Model
final class ConnectionRecord: IdentifiedRecord {
    @Attribute(.unique) var id: UUID
    /// Its place in the list, which a fetch doesn't keep.
    var position: Int
    var name: String
    /// `SharingConnection.State` as the store spells it.
    var state: String
    var sharesStatus: Bool

    init(id: UUID, position: Int) {
        self.id = id
        self.position = position
        name = ""
        state = ""
        sharesStatus = false
    }
}

/// A sent reminder as SwiftData saves it: the content a reminder's record keeps, bar tags and
/// origin (a sent reminder has neither), and the sender's revision count.
@Model
final class SentReminderRecord: IdentifiedRecord {
    @Attribute(.unique) var id: UUID
    var position: Int
    var title: String
    var notes: String
    var dueTime: Date
    /// The repeat, spelled as `ReminderRecord` spells it.
    var repeatRule: String?
    var repeatMissingDay: String?
    var repeatUntilTime: Date?
    var strength: String
    var paceKind: String
    var paceWait: Double?
    var breakThroughFocus: Bool
    var createdAt: Date
    /// How many times the sender has changed it.
    var revision: Int

    init(id: UUID, position: Int) {
        self.id = id
        self.position = position
        title = ""
        notes = ""
        dueTime = .distantPast
        strength = ""
        paceKind = ""
        breakThroughFocus = true
        createdAt = .distantPast
        revision = 0
    }
}

/// A recipient's copy of a sent reminder as SwiftData saves it, with what its recipient's app last
/// reported. The connection and reminder IDs together name it.
@Model
final class SentCopyRecord {
    var position: Int
    var connectionID: UUID
    var reminderID: UUID
    var createdAt: Date
    /// `SentCopy.Receipt` as the store spells it.
    var receipt: String
    /// Whether a status record has arrived. The rest of the status is `nil` or empty when not.
    var hasStatusRecord: Bool
    var notSharingThisOne: Bool
    /// `ReportedStatus` as the store spells it, for the status record's label.
    var statusLabel: String?
    @Relationship(deleteRule: .cascade, inverse: \SentCopyOccurrenceRecord.copy)
    var occurrences: [SentCopyOccurrenceRecord] = []
    var waitingToSync: Bool

    init(position: Int, connectionID: UUID, reminderID: UUID) {
        self.position = position
        self.connectionID = connectionID
        self.reminderID = reminderID
        createdAt = .distantPast
        receipt = ""
        hasStatusRecord = false
        notSharingThisOne = false
        waitingToSync = false
    }
}

/// One occurrence in a sent copy's reported history.
@Model
final class SentCopyOccurrenceRecord {
    var copy: SentCopyRecord?
    /// Its place in the report, which a relationship doesn't keep.
    var position: Int
    var dueTime: Date
    var year: Int
    var month: Int
    var day: Int
    /// `ReportedStatus` as the store spells it.
    var label: String

    init(position: Int, dueTime: Date, year: Int, month: Int, day: Int, label: String) {
        self.position = position
        self.dueTime = dueTime
        self.year = year
        self.month = month
        self.day = day
        self.label = label
    }
}

/// What the sharing store keeps about one received reminder, beside the reminder in the reminder
/// store (whose origin and history stay there). The reminder's ID names it.
@Model
final class ReceivedSyncRecord {
    var reminderID: UUID
    var position: Int
    var notSharingThisOne: Bool
    var waitingToSync: Bool
    var recordSystemFields: Data?

    init(position: Int, reminderID: UUID) {
        self.position = position
        self.reminderID = reminderID
        notSharingThisOne = false
        waitingToSync = false
    }
}

/// `CKSyncEngine`'s saved state for one database, as bytes the store doesn't read.
@Model
final class SyncEngineStateRecord {
    var position: Int
    /// `SyncEngineState.Database` as the store spells it.
    var database: String
    var data: Data

    init(position: Int, database: String, data: Data) {
        self.position = position
        self.database = database
        self.data = data
    }
}

/// A change that hasn't gone to iCloud yet.
@Model
final class OutboxRecord {
    var id: UUID
    /// Its place in the queue, oldest first.
    var position: Int
    /// `OutboxChange.Kind` as the store spells it.
    var kind: String
    var connectionID: UUID
    var reminderID: UUID?

    init(id: UUID, position: Int, kind: String, connectionID: UUID, reminderID: UUID?) {
        self.id = id
        self.position = position
        self.kind = kind
        self.connectionID = connectionID
        self.reminderID = reminderID
    }
}
