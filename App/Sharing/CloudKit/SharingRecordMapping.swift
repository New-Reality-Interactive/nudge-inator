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
        /// When iCloud last saved the record: iCloud's own time, never a phone's clock (#435).
        let modifiedAt: Date?

        init(record: CKRecord, writtenByOtherPerson: Bool, modifiedAt: Date? = nil) {
            self.record = record
            self.writtenByOtherPerson = writtenByOtherPerson
            self.modifiedAt = modifiedAt ?? record.modificationDate
        }
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
            record.encryptedValues[Field.receipt.rawValue] = receipt.storedValue
            writes.save.append(record)
        case .settings(let settings):
            let record = record(RecordName(type: .connectionSettings, writer: side), existing: existing)
            record.encryptedValues[Field.name.rawValue] = settings.name
            record.encryptedValues[Field.sharesStatus.rawValue] = settings.choices.sharesStatus.recordValue
            record.encryptedValues[Field.deliveryMode.rawValue] = settings.choices.deliveryMode.storedValue
            // The heartbeat follows Status sharing: with it off the field is cleared, so the other
            // person has no Last synced (#435).
            record.encryptedValues[Field.heartbeat.rawValue] = settings.choices.sharesStatus ? Self.newHeartbeat : nil
            writes.save.append(record)
        case .status(let status):
            guard let reminderID = change.reminderID else { break }
            if let status, statusSharingOn {
                writes = statusWrites(status, reminderID: reminderID, existing: existing)
            } else {
                // The occurrences go with it: their references to it are `deleteSelf`.
                writes.delete.append(recordID(RecordName(type: .status, writer: side, reminderID: reminderID)))
            }
        case .none, .lost:
            guard change.kind == .cancel, let reminderID = change.reminderID else { break }
            // The sender's content is gone by now, so only the flag is written, onto the record
            // the adapter holds, whose change tag lets iCloud take the save.
            let record = record(RecordName(type: .sentReminder, writer: side, reminderID: reminderID), existing: existing)
            record.encryptedValues[Field.canceled.rawValue] = true.recordValue
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
        return named.compactMap { record, name, modifiedAt -> SharingChange? in
            guard name.type.isStatus else {
                return try? change(from: record, named: name, modifiedAt: modifiedAt)
            }
            guard let reminderID = name.reminderID, statusesRead.insert(reminderID).inserted else { return nil }
            return try? statusChange(of: reminderID) { wanted in
                fetchedByName[wanted.text] ?? held(recordID(wanted)).flatMap(accepted)?.record
            }
        }
    }

    /// This person's connection settings record with a new heartbeat on it, for a heartbeat that
    /// goes on its own (#435). `existing` is the record the sync holds, on iCloud's latest version:
    /// only the heartbeat is set on it, so what iCloud holds of it is left as it is. With none held,
    /// the record is new and carries the defaults a reader needs (`ConnectionChoices`).
    func heartbeat(existing: CKRecord?) -> CKRecord {
        let record = existing ?? self.record(RecordName(type: .connectionSettings, writer: side), existing: { _ in nil })
        if existing == nil {
            let defaults = ConnectionChoices()
            record.encryptedValues[Field.sharesStatus.rawValue] = defaults.sharesStatus.recordValue
            record.encryptedValues[Field.deliveryMode.rawValue] = defaults.deliveryMode.storedValue
        }
        record.encryptedValues[Field.heartbeat.rawValue] = Self.newHeartbeat
        return record
    }

    /// The heartbeat's field name, which a record this person wrote holds only while Status sharing is on.
    static let heartbeatField = Field.heartbeat.rawValue

    /// Whether the record named `recordName` is this person's connection settings record.
    func isOwnSettings(recordName: String) -> Bool {
        guard let name = RecordName(recordName) else { return false }
        return name.type == .connectionSettings && name.writer == side
    }

    /// The name of this person's connection settings record.
    var ownSettingsRecordName: String {
        RecordName(type: .connectionSettings, writer: side).text
    }

    /// A value no earlier heartbeat had, so a save always changes the record and iCloud stamps it.
    private static var newHeartbeat: Int64 { Int64.random(in: 1...Int64.max) }

    /// Whether this person's own app writes the record named `recordName`: it is named for their side.
    func isOwn(recordName: String) -> Bool {
        RecordName(recordName)?.writer == side
    }

    /// Whether the record named `recordName` is part of a status: the status or an occurrence.
    func isStatus(recordName: String) -> Bool {
        RecordName(recordName)?.type.isStatus ?? false
    }

    /// Where a save of the record named `recordName` goes in a batch, lowest first: a status ahead
    /// of its occurrences, which reference it. A name that isn't a record's goes last.
    static func sendRank(of recordName: String) -> Int {
        guard let type = RecordName(recordName)?.type else { return sendRanks }
        return RecordType.allCases.firstIndex(of: type) ?? sendRanks
    }

    /// How many ranks `sendRank(of:)` gives.
    static var sendRanks: Int { RecordType.allCases.count }

    /// The record and its name, if it is one the other person may write and did.
    private func accepted(_ item: FetchedRecord) -> (record: CKRecord, name: RecordName, modifiedAt: Date?)? {
        guard item.writtenByOtherPerson, let name = RecordName(item.record.recordID.recordName),
              name.writer != side, item.record.recordType == name.type.rawValue
        else { return nil }
        return (item.record, name, item.modifiedAt)
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
    private func change(from record: CKRecord, named name: RecordName, modifiedAt: Date?) throws -> SharingChange? {
        switch name.type {
        case .connectionSettings:
            let choices = ConnectionChoices(
                sharesStatus: try record.flag(Field.sharesStatus),
                deliveryMode: try DeliveryMode(storedValue: try record.required(Field.deliveryMode))
            )
            // The name is optional: the app model sends none (ticket 196).
            // Last synced is iCloud's time of a record that carries a heartbeat (#435).
            let lastSynced = record.encryptedValues[Field.heartbeat.rawValue] == nil ? nil : modifiedAt
            return .settings(.init(name: record.encryptedValues[Field.name.rawValue] as? String, choices, lastSynced: lastSynced), for: connectionID)
        case .sentReminder:
            let reminderID = try name.requiredReminderID()
            if (record.encryptedValues[Field.canceled.rawValue] as? Int64) == true.recordValue {
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
        record.encryptedValues[Field.label.rawValue] = status.notSharingThisOne ? nil : status.report.label.storedValue
        record.encryptedValues[Field.notSharingThisOne.rawValue] = status.notSharingThisOne.recordValue
        record.encryptedValues[Field.occurrenceCount.rawValue] = Int64(occurrences.count)
        let reportID = UUID().uuidString
        record.encryptedValues[Field.reportID.rawValue] = reportID
        var writes = Writes(save: [record])
        for (slot, occurrence) in occurrences.enumerated() {
            let occurrenceRecord = self.record(RecordName(type: .occurrenceStatus, writer: side, reminderID: reminderID, slot: slot), existing: existing)
            occurrenceRecord[Field.status.rawValue] = CKRecord.Reference(recordID: record.recordID, action: .deleteSelf)
            let values = occurrenceRecord.encryptedValues
            values[Field.dueTime.rawValue] = occurrence.dueTime.timeIntervalSinceReferenceDate
            values[Field.year.rawValue] = Int64(occurrence.day.year)
            values[Field.month.rawValue] = Int64(occurrence.day.month)
            values[Field.day.rawValue] = Int64(occurrence.day.day)
            values[Field.label.rawValue] = occurrence.label.storedValue
            values[Field.reportID.rawValue] = reportID
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
            guard let held = occurrence(slot), held.encryptedValues[Field.reportID.rawValue] as? String == reportID else { return nil }
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
        values[Field.title.rawValue] = reminder.title
        values[Field.notes.rawValue] = reminder.notes
        values[Field.dueTime.rawValue] = reminder.dueTime.timeIntervalSinceReferenceDate
        let repeating = reminder.repeatRule?.storedValue
        values[Field.repeatRule.rawValue] = repeating?.rrule
        values[Field.repeatMissingDay.rawValue] = repeating?.missingDay
        values[Field.repeatUntilTime.rawValue] = repeating?.untilTime?.timeIntervalSinceReferenceDate
        values[Field.strength.rawValue] = reminder.strength.storedValue
        let pace = reminder.pace.storedValue
        values[Field.paceKind.rawValue] = pace.kind
        values[Field.paceWait.rawValue] = pace.wait
        values[Field.breakThroughFocus.rawValue] = reminder.breakThroughFocus.recordValue
        values[Field.createdAt.rawValue] = reminder.createdAt.timeIntervalSinceReferenceDate
        values[Field.revision.rawValue] = Int64(sent.revision)
        values[Field.changeNote.rawValue] = try sent.changeNote.storedData()
        values[Field.canceled.rawValue] = false.recordValue
        return record
    }

    private func sentReminder(from record: CKRecord, id: Reminder.ID) throws -> SentReminder {
        let values = record.encryptedValues
        let untilTime = (values[Field.repeatUntilTime.rawValue] as? Double).map(Date.init(timeIntervalSinceReferenceDate:))
        let repeatRule = try (values[Field.repeatRule.rawValue] as? String).map {
            try RepeatRule(storedRRULE: $0, missingDay: values[Field.repeatMissingDay.rawValue] as? String, untilTime: untilTime)
        }
        let reminder = Reminder(
            id: id,
            title: try record.required(Field.title),
            notes: try record.required(Field.notes),
            dueTime: try record.date(Field.dueTime),
            repeatRule: repeatRule,
            strength: try Strength(storedValue: try record.required(Field.strength)),
            pace: try Pace(storedKind: try record.required(Field.paceKind), wait: values[Field.paceWait.rawValue] as? Double),
            breakThroughFocus: try record.flag(Field.breakThroughFocus),
            createdAt: try record.date(Field.createdAt)
        )
        let revision: Int64 = try record.required(Field.revision)
        return SentReminder(reminder: reminder, revision: Int(revision), changeNote: try [ReceivedChange](storedData: values[Field.changeNote.rawValue] as? Data))
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
/// In the order a batch saves them (`SharingRecordMapping.sendRank`).
private enum RecordType: String, CaseIterable {
    case connectionSettings = "ConnectionSettings"
    case sentReminder = "SentReminder"
    case receipt = "Receipt"
    case status = "Status"
    case occurrenceStatus = "OccurrenceStatus"

    var isStatus: Bool { self == .status || self == .occurrenceStatus }
}

/// The record fields, as permanent as the types: each name is its field's key in iCloud.
private enum Field: String, CaseIterable {
    case name
    case sharesStatus
    case deliveryMode
    case heartbeat
    case title
    case notes
    case dueTime
    case repeatRule
    case repeatMissingDay
    case repeatUntilTime
    case strength
    case paceKind
    case paceWait
    case breakThroughFocus
    case createdAt
    case revision
    case changeNote
    case canceled
    case receipt
    case label
    case notSharingThisOne
    case occurrenceCount
    case reportID
    case status
    case year
    case month
    case day
}

#if DEBUG
extension SharingRecordMapping {
    /// The names of every record type, for the schema device check (#327).
    static var recordTypeNames: [String] { RecordType.allCases.map(\.rawValue) }

    /// The names of every field the records use, for the schema device check (#327): the
    /// development schema gets only the fields a save has used.
    static var fieldNames: [String] { Field.allCases.map(\.rawValue) }
}
#endif

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
    func required<Value>(_ field: Field) throws -> Value {
        guard let value = encryptedValues[field.rawValue] as? Value else { throw UnreadableRecord() }
        return value
    }

    func flag(_ field: Field) throws -> Bool {
        let value: Int64 = try required(field)
        return value == true.recordValue
    }

    func date(_ field: Field) throws -> Date {
        Date(timeIntervalSinceReferenceDate: try required(field))
    }
}
