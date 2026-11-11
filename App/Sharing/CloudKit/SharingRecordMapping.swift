import CloudKit
import Foundation
import NudgeEngine

/// Maps what crosses between two people's apps to `CKRecord` fields and back, for one connection's
/// record zone. A `CKRecord` is a local value, so nothing here talks to iCloud: the adapter does
/// that (#216), and `scripts/test.sh` fails if this file names anything that could.
struct SharingRecordMapping {
    /// Which end of the connection's zone a person is on.
    enum Side: String {
        /// Invited the other person, and holds the zone in their private database.
        case owner = "owner"
        /// Accepted the invite, and sees the zone in their shared database.
        case participant = "participant"

        var other: Side { self == .owner ? .participant : .owner }
    }

    /// A record as it came from iCloud, and whether the other person's app last wrote it.
    struct FetchedRecord {
        let record: CKRecord
        let writtenByOtherPerson: Bool
    }

    /// What a change does to the zone's records.
    struct Writes {
        var save: [CKRecord] = []
        var delete: [CKRecord.ID] = []
    }

    let connectionID: UUID
    let zoneID: CKRecordZone.ID
    let side: Side

    /// `nil` for a zone that isn't a connection's: its name is the connection's ID.
    init?(zoneID: CKRecordZone.ID) {
        guard let connectionID = UUID(uuidString: zoneID.zoneName) else { return nil }
        self.connectionID = connectionID
        self.zoneID = zoneID
        side = zoneID.ownerName == CKCurrentUserDefaultName ? .owner : .participant
    }

    /// What `change` does to the zone's records. `statusSharingOn` is this person's own Status
    /// sharing for the connection: while it is off, a status is deleted, never written.
    /// `existing` gives a record the adapter already holds, which has iCloud's change tag; the
    /// fields go onto it, and a value now `nil` clears its field. A disconnect writes nothing: it
    /// ends the share itself, which is the adapter's to do.
    func writes(
        for change: SharingChange,
        statusSharingOn: Bool,
        existing: (CKRecord.ID) -> CKRecord? = { _ in nil }
    ) throws -> Writes {
        var writes = Writes()
        switch change.content {
        case .reminder(let sent):
            writes.save.append(try sentReminderRecord(sent, existing: existing))
        case .receipt(let receipt):
            guard let reminderID = change.reminderID else { break }
            let record = record(RecordName(type: .receipt, writer: side, reminderID: reminderID), existing: existing)
            record.encryptedValues[Field.receipt] = receipt.storedValue
            writes.save.append(record)
        case .settings(let settings):
            let record = record(RecordName(type: .connectionSettings, writer: side), existing: existing)
            record.encryptedValues[Field.name] = settings.name
            record.encryptedValues[Field.sharesStatus] = settings.sharesStatus.recordValue
            writes.save.append(record)
        case .status(let status):
            guard let reminderID = change.reminderID else { break }
            if let status, statusSharingOn {
                writes = statusWrites(status, reminderID: reminderID, existing: existing)
            } else {
                // The occurrences go with it: their references to it are `deleteSelf`.
                writes.delete.append(recordID(RecordName(type: .status, writer: side, reminderID: reminderID)))
            }
        case .none:
            guard change.kind == .cancel, let reminderID = change.reminderID else { break }
            // The sender's content is gone by now, so only the flag is written, onto the record
            // the adapter holds, whose change tag lets iCloud take the save.
            let record = record(RecordName(type: .sentReminder, writer: side, reminderID: reminderID), existing: existing)
            record.encryptedValues[Field.canceled] = true.recordValue
            writes.save.append(record)
        }
        return writes
    }

    /// The changes the other person made, read from records just fetched. CloudKit can't stop a
    /// read-write participant changing any record in the zone, so who may write what is the app's
    /// rule, kept here: a record counts only if it is named for the other person's side and they
    /// wrote it. One that breaks the rule, or can't be read, is left out, never thrown: throwing
    /// would make the adapter offer it again for good.
    ///
    /// A fetch can split a status from its occurrences. `held` gives a record fetched earlier, so
    /// the adapter keeps a status's records and a status reads as soon as they are all there.
    ///
    /// One record stands for a sent reminder, so someone who was offline across a send and a
    /// revision, or a cancel, first hears of it as that revision or cancel.
    func changes(from fetched: [FetchedRecord], held: (CKRecord.ID) -> FetchedRecord? = { _ in nil }) -> [SharingChange] {
        let named = fetched.compactMap(accepted)
        let fetchedByName = Dictionary(named.map { ($0.name.text, $0.record) }) { _, latest in latest }
        var statusesRead: Set<Reminder.ID> = []
        return named.compactMap { record, name -> SharingChange? in
            guard name.type == .status || name.type == .occurrenceStatus else {
                return try? change(from: record, named: name)
            }
            guard let reminderID = name.reminderID, statusesRead.insert(reminderID).inserted else { return nil }
            return try? statusChange(of: reminderID) { wanted in
                fetchedByName[wanted.text] ?? held(recordID(wanted)).flatMap(accepted)?.record
            }
        }
    }

    /// The record and its name, if it is one the other person may write and did.
    private func accepted(_ item: FetchedRecord) -> (record: CKRecord, name: RecordName)? {
        guard item.writtenByOtherPerson, let name = RecordName(item.record.recordID.recordName),
              name.writer != side, item.record.recordType == name.type.rawValue
        else { return nil }
        return (item.record, name)
    }

    /// The change a deleted record means. Only a status means one: its recipient's app deleted it
    /// because Status sharing went off. iCloud doesn't say who deleted a record, so the deletion
    /// of one of this person's own records is ignored.
    func change(fromDeleted recordID: CKRecord.ID) -> SharingChange? {
        guard let name = RecordName(recordID.recordName), name.type == .status, name.writer != side,
              let reminderID = name.reminderID
        else { return nil }
        return .status(nil, for: reminderID, from: connectionID)
    }

    /// The change one record means by itself; a status needs its occurrences, so isn't read here.
    private func change(from record: CKRecord, named name: RecordName) throws -> SharingChange? {
        switch name.type {
        case .connectionSettings:
            let settings = SharingChange.ConnectionSettings(name: try record.required(Field.name), sharesStatus: try record.flag(Field.sharesStatus))
            return .settings(settings, for: connectionID)
        case .sentReminder:
            let reminderID = try name.requiredReminderID()
            if (record.encryptedValues[Field.canceled] as? Int64) == true.recordValue {
                return .cancel(reminderID, for: connectionID)
            }
            let sent = try sentReminder(from: record, id: reminderID)
            return sent.revision == 0 ? .send(sent, to: connectionID) : .revise(sent, for: connectionID)
        case .receipt:
            let receipt = try SentCopy.Receipt(storedValue: try record.required(Field.receipt))
            return .receipt(receipt, for: try name.requiredReminderID(), from: connectionID)
        case .status, .occurrenceStatus:
            return nil
        }
    }

    /// The other person's status for a reminder, or `nil` until all its records are there.
    private func statusChange(of reminderID: Reminder.ID, record lookUp: (RecordName) -> CKRecord?) throws -> SharingChange? {
        guard let record = lookUp(RecordName(type: .status, writer: side.other, reminderID: reminderID)),
              let status = try status(from: record, occurrence: { slot in
                  lookUp(RecordName(type: .occurrenceStatus, writer: side.other, reminderID: reminderID, slot: slot))
              })
        else { return nil }
        return .status(status, for: reminderID, from: connectionID)
    }

    private func recordID(_ name: RecordName) -> CKRecord.ID {
        CKRecord.ID(recordName: name.text, zoneID: zoneID)
    }

    private func record(_ name: RecordName, existing: (CKRecord.ID) -> CKRecord?) -> CKRecord {
        let id = recordID(name)
        return existing(id) ?? CKRecord(recordType: name.type.rawValue, recordID: id)
    }

    /// A status and its occurrences, each in the slot of its place in the report, so a later report
    /// writes over the same records, and all marked with one report ID, so a reader can't join days
    /// from two reports. Slots the report doesn't use are deleted. "Don't share this one" writes
    /// only the flag: none of the status may reach iCloud.
    private func statusWrites(_ status: SentCopy.StatusRecord, reminderID: Reminder.ID, existing: (CKRecord.ID) -> CKRecord?) -> Writes {
        let record = record(RecordName(type: .status, writer: side, reminderID: reminderID), existing: existing)
        let occurrences = status.notSharingThisOne ? [] : status.report.occurrences
        record.encryptedValues[Field.label] = status.notSharingThisOne ? nil : status.report.label.storedValue
        record.encryptedValues[Field.notSharingThisOne] = status.notSharingThisOne.recordValue
        record.encryptedValues[Field.occurrenceCount] = Int64(occurrences.count)
        let reportID = UUID().uuidString
        record.encryptedValues[Field.reportID] = reportID
        var writes = Writes(save: [record])
        for (slot, occurrence) in occurrences.enumerated() {
            let occurrenceRecord = self.record(RecordName(type: .occurrenceStatus, writer: side, reminderID: reminderID, slot: slot), existing: existing)
            occurrenceRecord[Field.status] = CKRecord.Reference(recordID: record.recordID, action: .deleteSelf)
            let values = occurrenceRecord.encryptedValues
            values[Field.dueTime] = occurrence.dueTime.timeIntervalSinceReferenceDate
            values[Field.year] = Int64(occurrence.day.year)
            values[Field.month] = Int64(occurrence.day.month)
            values[Field.day] = Int64(occurrence.day.day)
            values[Field.label] = occurrence.label.storedValue
            values[Field.reportID] = reportID
            writes.save.append(occurrenceRecord)
        }
        for slot in occurrences.count..<max(occurrences.count, Self.occurrenceSlots) {
            writes.delete.append(recordID(RecordName(type: .occurrenceStatus, writer: side, reminderID: reminderID, slot: slot)))
        }
        return writes
    }

    /// The most occurrences a report holds: today and the 7 days before.
    private static let occurrenceSlots = 8

    /// `nil` until every occurrence of this report is here: they may arrive after it.
    private func status(from record: CKRecord, occurrence: (Int) -> CKRecord?) throws -> SentCopy.StatusRecord? {
        if try record.flag(Field.notSharingThisOne) {
            // The label isn't sent, and the sender's side doesn't read one for a copy kept from it.
            return SentCopy.StatusRecord(report: StatusReport(label: .comingUp, occurrences: []), notSharingThisOne: true)
        }
        let count: Int64 = try record.required(Field.occurrenceCount)
        guard count >= 0 else { throw UnreadableRecord() }
        let reportID: String = try record.required(Field.reportID)
        var records: [CKRecord] = []
        for slot in 0..<Int(count) {
            guard let held = occurrence(slot), held.encryptedValues[Field.reportID] as? String == reportID else { return nil }
            records.append(held)
        }
        let report = StatusReport(
            label: try ReportedStatus(storedValue: try record.required(Field.label)),
            occurrences: try records.map(occurrenceStatus)
        )
        return SentCopy.StatusRecord(report: report, notSharingThisOne: false)
    }

    private func occurrenceStatus(from record: CKRecord) throws -> StatusReport.OccurrenceStatus {
        let year: Int64 = try record.required(Field.year)
        let month: Int64 = try record.required(Field.month)
        let day: Int64 = try record.required(Field.day)
        return StatusReport.OccurrenceStatus(
            dueTime: try record.date(Field.dueTime),
            day: CalendarDay(year: Int(year), month: Int(month), day: Int(day)),
            label: try ReportedStatus(storedValue: try record.required(Field.label))
        )
    }

    private func sentReminderRecord(_ sent: SentReminder, existing: (CKRecord.ID) -> CKRecord?) throws -> CKRecord {
        let record = record(RecordName(type: .sentReminder, writer: side, reminderID: sent.reminder.id), existing: existing)
        let reminder = sent.reminder
        let values = record.encryptedValues
        values[Field.title] = reminder.title
        values[Field.notes] = reminder.notes
        values[Field.dueTime] = reminder.dueTime.timeIntervalSinceReferenceDate
        let repeating = reminder.repeatRule?.storedValue
        values[Field.repeatRule] = repeating?.rrule
        values[Field.repeatMissingDay] = repeating?.missingDay
        values[Field.repeatUntilTime] = repeating?.untilTime?.timeIntervalSinceReferenceDate
        values[Field.strength] = reminder.strength.storedValue
        let pace = reminder.pace.storedValue
        values[Field.paceKind] = pace.kind
        values[Field.paceWait] = pace.wait
        values[Field.breakThroughFocus] = reminder.breakThroughFocus.recordValue
        values[Field.createdAt] = reminder.createdAt.timeIntervalSinceReferenceDate
        values[Field.revision] = Int64(sent.revision)
        values[Field.changeNote] = try sent.changeNote.storedData()
        values[Field.canceled] = false.recordValue
        return record
    }

    private func sentReminder(from record: CKRecord, id: Reminder.ID) throws -> SentReminder {
        let values = record.encryptedValues
        let untilTime = (values[Field.repeatUntilTime] as? Double).map(Date.init(timeIntervalSinceReferenceDate:))
        let repeatRule = try (values[Field.repeatRule] as? String).map {
            try RepeatRule(storedRRULE: $0, missingDay: values[Field.repeatMissingDay] as? String, untilTime: untilTime)
        }
        let reminder = Reminder(
            id: id,
            title: try record.required(Field.title),
            notes: try record.required(Field.notes),
            dueTime: try record.date(Field.dueTime),
            repeatRule: repeatRule,
            strength: try Strength(storedValue: try record.required(Field.strength)),
            pace: try Pace(storedKind: try record.required(Field.paceKind), wait: values[Field.paceWait] as? Double),
            breakThroughFocus: try record.flag(Field.breakThroughFocus),
            createdAt: try record.date(Field.createdAt)
        )
        let revision: Int64 = try record.required(Field.revision)
        return SentReminder(reminder: reminder, revision: Int(revision), changeNote: try [ReceivedChange](storedData: values[Field.changeNote] as? Data))
    }
}

extension SharingRecordMapping.FetchedRecord {
    /// What the adapter calls for a fetched record. iCloud sets who last modified it; a record
    /// with no one named can't be shown to be the other person's.
    init(fetched record: CKRecord) {
        self.init(record: record, writtenByOtherPerson: Self.isOtherPerson(lastModifiedBy: record.lastModifiedUserRecordID))
    }

    static func isOtherPerson(lastModifiedBy userRecordID: CKRecord.ID?) -> Bool {
        guard let userRecordID else { return false }
        return userRecordID.recordName != CKCurrentUserDefaultName
    }
}

/// The record types. Their names go into the CloudKit production schema, which can only be added to.
private enum RecordType: String {
    case connectionSettings = "ConnectionSettings"
    case sentReminder = "SentReminder"
    case receipt = "Receipt"
    case status = "Status"
    case occurrenceStatus = "OccurrenceStatus"
}

/// The record fields, as permanent as the types.
private enum Field {
    static let name = "name"
    static let sharesStatus = "sharesStatus"
    static let title = "title"
    static let notes = "notes"
    static let dueTime = "dueTime"
    static let repeatRule = "repeatRule"
    static let repeatMissingDay = "repeatMissingDay"
    static let repeatUntilTime = "repeatUntilTime"
    static let strength = "strength"
    static let paceKind = "paceKind"
    static let paceWait = "paceWait"
    static let breakThroughFocus = "breakThroughFocus"
    static let createdAt = "createdAt"
    static let revision = "revision"
    static let changeNote = "changeNote"
    static let canceled = "canceled"
    static let receipt = "receipt"
    static let label = "label"
    static let notSharingThisOne = "notSharingThisOne"
    static let occurrenceCount = "occurrenceCount"
    static let reportID = "reportID"
    static let status = "status"
    static let year = "year"
    static let month = "month"
    static let day = "day"
}

/// A record's name says what it is, whose app may write it, and which reminder it is about:
/// `SentReminder.owner.<reminder ID>`, or `ConnectionSettings.owner`, which is about no reminder.
/// An occurrence status adds its slot: `OccurrenceStatus.participant.<reminder ID>.0`.
private struct RecordName {
    var type: RecordType
    var writer: SharingRecordMapping.Side
    var reminderID: Reminder.ID?
    var slot: Int?

    init(type: RecordType, writer: SharingRecordMapping.Side, reminderID: Reminder.ID? = nil, slot: Int? = nil) {
        self.type = type
        self.writer = writer
        self.reminderID = reminderID
        self.slot = slot
    }

    init?(_ text: String) {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2, let type = RecordType(rawValue: parts[0]), let writer = SharingRecordMapping.Side(rawValue: parts[1]) else { return nil }
        self.type = type
        self.writer = writer
        switch (type, parts.count) {
        case (.connectionSettings, 2):
            break
        case (.sentReminder, 3), (.receipt, 3), (.status, 3):
            guard let reminderID = UUID(uuidString: parts[2]) else { return nil }
            self.reminderID = reminderID
        case (.occurrenceStatus, 4):
            guard let reminderID = UUID(uuidString: parts[2]), let slot = Int(parts[3]) else { return nil }
            self.reminderID = reminderID
            self.slot = slot
        default:
            return nil
        }
    }

    var text: String {
        [type.rawValue, writer.rawValue, reminderID?.uuidString, slot.map(String.init)].compactMap(\.self).joined(separator: ".")
    }

    func requiredReminderID() throws -> Reminder.ID {
        guard let reminderID else { throw UnreadableRecord() }
        return reminderID
    }
}

/// A field is missing or isn't the type it should be.
private struct UnreadableRecord: Error {}

private extension Bool {
    /// CloudKit has no Boolean field, so a flag is an `Int64` of 1 or 0.
    var recordValue: Int64 { self ? 1 : 0 }
}

/// Every field but a reference is encrypted (`encryptedValues`), since what these records hold is
/// private and a field can't be made encrypted after it is in the schema. A time is a `Double` of
/// seconds, not a date field, so it reads back exactly.
private extension CKRecord {
    func required<Value>(_ field: String) throws -> Value {
        guard let value = encryptedValues[field] as? Value else { throw UnreadableRecord() }
        return value
    }

    func flag(_ field: String) throws -> Bool {
        let value: Int64 = try required(field)
        return value == true.recordValue
    }

    func date(_ field: String) throws -> Date {
        Date(timeIntervalSinceReferenceDate: try required(field))
    }
}
