import CloudKit
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The record mapping's seam (ticket 193, spec #127 seam 3): each side of a connection has a mapping
/// over the one record zone. A test writes a change to records through one side's mapping and reads
/// them through the other's, as iCloud would carry them. No network.
struct SharingRecordMappingTests {
    let connectionID = UUID()
    let reminderID = UUID()
    let owner: SharingRecordMapping
    let participant: SharingRecordMapping

    init() throws {
        owner = try #require(SharingRecordMapping(zoneID: CKRecordZone.ID(zoneName: connectionID.uuidString, ownerName: CKCurrentUserDefaultName)))
        participant = try #require(SharingRecordMapping(zoneID: CKRecordZone.ID(zoneName: connectionID.uuidString, ownerName: "_theOwnersUserRecord")))
    }

    /// What the other side makes of `change`, written by `writer` and read by `reader`.
    func carried(_ change: SharingChange, from writer: SharingRecordMapping, to reader: SharingRecordMapping) throws -> [SharingChange] {
        let writes = try writer.writes(for: change, statusSharingOn: true)
        return reader.changes(from: writes.save.map { .init(record: $0, writtenByOtherPerson: true) })
    }

    /// `change` as the reader gets it, the same but for the ID its own outbox would give it.
    func expectCarried(_ change: SharingChange, from writer: SharingRecordMapping, to reader: SharingRecordMapping, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let read = try #require(try carried(change, from: writer, to: reader).first, sourceLocation: sourceLocation)
        #expect(read.kind == change.kind, sourceLocation: sourceLocation)
        #expect(read.connectionID == change.connectionID, sourceLocation: sourceLocation)
        #expect(read.reminderID == change.reminderID, sourceLocation: sourceLocation)
        #expect(read.content == change.content, sourceLocation: sourceLocation)
    }

    func reminder(
        repeatRule: RepeatRule? = nil,
        strength: Strength = .firm,
        pace: Pace = .escalating
    ) -> Reminder {
        Reminder(
            id: reminderID,
            title: "Water the plants",
            notes: "Not the cactus",
            dueTime: Date(timeIntervalSinceReferenceDate: 815_000_000.123456),
            repeatRule: repeatRule,
            strength: strength,
            pace: pace,
            breakThroughFocus: false,
            createdAt: Date(timeIntervalSinceReferenceDate: 814_900_000.654321)
        )
    }

    @Test func aSentReminderReachesTheOtherSide() throws {
        try expectCarried(.send(SentReminder(reminder: reminder(), revision: 0), to: connectionID), from: owner, to: participant)
    }

    /// The participant's sent reminders travel too: one invite connects both ways.
    @Test func aSentReminderReachesTheOwnerFromTheParticipant() throws {
        try expectCarried(.send(SentReminder(reminder: reminder(), revision: 0), to: connectionID), from: participant, to: owner)
    }

    static let endingAtATime: RepeatRule = {
        var rule = RepeatRule.everyDay
        rule.end = .untilTime(Date(timeIntervalSinceReferenceDate: 816_000_000.5))
        return rule
    }()

    @Test(arguments: [RepeatRule.everyDay, .everyWeekday, .everyTwoWeeks, .everyMonth, .everyYear, endingAtATime])
    func everyRepeatReachesTheOtherSide(_ rule: RepeatRule) throws {
        try expectCarried(.send(SentReminder(reminder: reminder(repeatRule: rule), revision: 0), to: connectionID), from: owner, to: participant)
    }

    @Test(arguments: [Strength.gentle, .firm, .relentless])
    func everyStrengthReachesTheOtherSide(_ strength: Strength) throws {
        try expectCarried(.send(SentReminder(reminder: reminder(strength: strength), revision: 0), to: connectionID), from: owner, to: participant)
    }

    @Test(arguments: [Pace.escalating, .consistent(wait: 300)])
    func everyPaceReachesTheOtherSide(_ pace: Pace) throws {
        try expectCarried(.send(SentReminder(reminder: reminder(pace: pace), revision: 0), to: connectionID), from: owner, to: participant)
    }

    @Test func aRevisionReachesTheOtherSideWithItsChangeNote() throws {
        let sent = SentReminder(reminder: reminder(), revision: 2, changeNote: SharingChangeNotes.everyField)

        try expectCarried(.revise(sent, for: connectionID), from: owner, to: participant)
    }

    /// The sender's content is gone by then, so a cancel writes only the flag: saved over the record
    /// iCloud already holds, it leaves the rest as it was.
    @Test func aCancelReachesTheOtherSide() throws {
        try expectCarried(.cancel(reminderID, for: connectionID), from: owner, to: participant)
    }

    @Test(arguments: [SentCopy.Receipt.notDelivered, .waitingForAcceptance, .started])
    func everyReceiptReachesTheSender(_ receipt: SentCopy.Receipt) throws {
        try expectCarried(.receipt(receipt, for: reminderID, from: connectionID), from: participant, to: owner)
    }

    @Test(arguments: [true, false])
    func aPersonsSettingsReachTheOtherSide(sharesStatus: Bool) throws {
        let settings = SharingChange.ConnectionSettings(name: "Sam", sharesStatus: sharesStatus)

        try expectCarried(.settings(settings, for: connectionID), from: owner, to: participant)
        try expectCarried(.settings(settings, for: connectionID), from: participant, to: owner)
    }

    /// Each person's settings have their own record, so one can't overwrite the other's.
    @Test func eachSideWritesItsOwnSettingsRecord() throws {
        let change = SharingChange.settings(.init(name: "Sam", sharesStatus: true), for: connectionID)

        let ownersRecord = try #require(try owner.writes(for: change, statusSharingOn: true).save.first)
        let participantsRecord = try #require(try participant.writes(for: change, statusSharingOn: true).save.first)

        #expect(ownersRecord.recordID.recordName != participantsRecord.recordID.recordName)
    }

    /// A status with a day in each of the last 7 days and today, oldest first.
    func weekOfStatus(label: ReportedStatus = .nudging, notSharingThisOne: Bool = false) -> SentCopy.StatusRecord {
        let occurrences = (0..<8).map { day in
            StatusReport.OccurrenceStatus(
                dueTime: Date(timeIntervalSinceReferenceDate: 815_000_000.5 + Double(day) * 86_400),
                day: CalendarDay(year: 2026, month: 10, day: 8 + day),
                label: day.isMultiple(of: 2) ? .done : .missed
            )
        }
        return SentCopy.StatusRecord(report: StatusReport(label: label, occurrences: occurrences), notSharingThisOne: notSharingThisOne)
    }

    func statusChange(_ status: SentCopy.StatusRecord?) -> SharingChange {
        .status(status, for: reminderID, from: connectionID)
    }

    @Test func aStatusReachesTheSenderWithItsSevenDays() throws {
        try expectCarried(statusChange(weekOfStatus()), from: participant, to: owner)
    }

    @Test func aStatusWithNoOccurrencesReachesTheSender() throws {
        let status = SentCopy.StatusRecord(report: StatusReport(label: .comingUp, occurrences: []), notSharingThisOne: false)

        try expectCarried(statusChange(status), from: participant, to: owner)
    }

    @Test(arguments: [ReportedStatus.nudging, .comingUp, .paused, .done, .missed, .skipped, .removed])
    func everyStatusLabelReachesTheSender(_ label: ReportedStatus) throws {
        let occurrence = StatusReport.OccurrenceStatus(dueTime: Date(timeIntervalSinceReferenceDate: 815_000_000), day: CalendarDay(year: 2026, month: 10, day: 8), label: label)
        let status = SentCopy.StatusRecord(report: StatusReport(label: label, occurrences: [occurrence]), notSharingThisOne: false)

        try expectCarried(statusChange(status), from: participant, to: owner)
    }

    /// Part of a status may arrive before the rest: reading half a week would show days as missing.
    @Test func aStatusWaitsForAllItsOccurrences() throws {
        let saved = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: true).save

        let read = owner.changes(from: saved.dropLast().map { .init(record: $0, writtenByOtherPerson: true) })

        #expect(read.isEmpty)
    }

    @Test func occurrencesWithoutTheirStatusAreNoChange() throws {
        let saved = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: true).save
        let occurrences = saved.filter { $0.recordType == "OccurrenceStatus" }

        try #require(occurrences.count == 8)
        #expect(owner.changes(from: occurrences.map { .init(record: $0, writtenByOtherPerson: true) }).isEmpty)
    }

    /// Deleting a status takes its occurrences with it: CloudKit cascades a `deleteSelf` reference.
    @Test func everyOccurrenceBelongsToItsStatus() throws {
        let saved = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: true).save
        let status = try #require(saved.first { $0.recordType == "Status" })

        for occurrence in saved where occurrence.recordType == "OccurrenceStatus" {
            let reference = try #require(occurrence["status"] as? CKRecord.Reference)
            #expect(reference.recordID == status.recordID)
            #expect(reference.action == .deleteSelf)
        }
    }

    /// A shorter report leaves no older day behind in iCloud.
    @Test func aShorterStatusDeletesTheOccurrencesItNoLongerHas() throws {
        var status = weekOfStatus()
        status.report.occurrences.removeLast(5)

        let writes = try participant.writes(for: statusChange(status), statusSharingOn: true)

        #expect(writes.save.filter { $0.recordType == "OccurrenceStatus" }.count == 3)
        #expect(writes.delete.count == 5)
    }

    @Test func noStatusIsWrittenWhileStatusSharingIsOff() throws {
        let writes = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: false)

        #expect(writes.save.isEmpty)
    }

    @Test(arguments: [true, false])
    func aStatusIsDeletedWhenSharingTurnsOff(statusSharingOn: Bool) throws {
        // Off with a status in hand, or a change that says there is no status: the same delete.
        let change = statusChange(statusSharingOn ? nil : weekOfStatus())
        let saved = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: true).save
        let status = try #require(saved.first { $0.recordType == "Status" })

        let writes = try participant.writes(for: change, statusSharingOn: statusSharingOn)

        #expect(writes.save.isEmpty)
        #expect(writes.delete == [status.recordID])
    }

    @Test func aDeletedStatusReachesTheSenderAsNoStatus() throws {
        let deleted = try #require(try participant.writes(for: statusChange(nil), statusSharingOn: true).delete.first)

        let read = try #require(owner.change(fromDeleted: deleted))

        #expect(read.kind == .status)
        #expect(read.reminderID == reminderID)
        #expect(read.content == .status(nil))
    }

    /// "Don't share this one": the sender learns only that, so none of the status goes to iCloud.
    @Test func aStatusKeptFromItsSenderHoldsOnlyTheFlag() throws {
        let change = statusChange(weekOfStatus(label: .done, notSharingThisOne: true))

        let writes = try participant.writes(for: change, statusSharingOn: true)

        let status = try #require(writes.save.first)
        #expect(writes.save.count == 1)
        #expect(status.encryptedValues["label"] == nil)
        #expect(writes.delete.count == 8)
    }

    @Test func aStatusKeptFromItsSenderReadsAsNotSharingThisOne() throws {
        let change = statusChange(weekOfStatus(label: .done, notSharingThisOne: true))
        let read = try #require(try carried(change, from: participant, to: owner).first)
        guard case .status(let status?) = read.content else {
            Issue.record("Expected a status, got \(read.content)")
            return
        }
        let copy = SentCopy(connectionID: connectionID, reminderID: reminderID, createdAt: .distantPast, receipt: .started, statusRecord: status, waitingToSync: false)

        let readOut = SentReadOut(connections: [SentConnection(id: connectionID, name: "Sam", sharesStatus: true)], copies: [copy])

        #expect(readOut.people.first?.rows.first?.status == .notSharingThisOne)
        #expect(status.report.occurrences.isEmpty)
    }

    /// Everything a side can write, for the tests of who may write what.
    enum Written: CaseIterable {
        case sentReminder, cancel, receipt, status, settings
    }

    func change(_ written: Written) -> SharingChange {
        switch written {
        case .sentReminder: .send(SentReminder(reminder: reminder(), revision: 0), to: connectionID)
        case .cancel: .cancel(reminderID, for: connectionID)
        case .receipt: .receipt(.started, for: reminderID, from: connectionID)
        case .status: statusChange(weekOfStatus())
        case .settings: .settings(.init(name: "Sam", sharesStatus: true), for: connectionID)
        }
    }

    func fetched(_ records: [CKRecord], writtenByOtherPerson: Bool) -> [SharingRecordMapping.FetchedRecord] {
        records.map { .init(record: $0, writtenByOtherPerson: writtenByOtherPerson) }
    }

    /// The other person changed a record that is this person's to write: a recipient editing a
    /// sent reminder, or a sender editing a receipt or status.
    @Test(arguments: Written.allCases)
    func theOtherPersonsWriteToThisPersonsRecordIsIgnored(_ written: Written) throws {
        let mine = try owner.writes(for: change(written), statusSharingOn: true).save

        #expect(owner.changes(from: fetched(mine, writtenByOtherPerson: true)).isEmpty)
    }

    /// A record named for the other side, last written from this iPhone, isn't news from them.
    @Test(arguments: Written.allCases)
    func thisPersonsOwnWriteIsNoChange(_ written: Written) throws {
        let theirs = try participant.writes(for: change(written), statusSharingOn: true).save

        #expect(owner.changes(from: fetched(theirs, writtenByOtherPerson: false)).isEmpty)
    }

    /// One overwritten day must not show: the status waits for the recipient's own write.
    @Test func aStatusWithAnOccurrenceTheSenderOverwroteIsIgnored() throws {
        let saved = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: true).save
        let tampered = fetched(Array(saved.dropLast()), writtenByOtherPerson: true) + fetched(Array(saved.suffix(1)), writtenByOtherPerson: false)

        #expect(owner.changes(from: tampered).isEmpty)
    }

    /// iCloud doesn't say who deleted a record, so only the other person's own records count.
    @Test func aDeletionOfThisPersonsStatusIsIgnored() throws {
        let mine = try #require(try participant.writes(for: statusChange(nil), statusSharingOn: true).delete.first)

        #expect(participant.change(fromDeleted: mine) == nil)
    }

    @Test func deletingAnythingButAStatusIsNoChange() throws {
        let saved = try owner.writes(for: change(.sentReminder), statusSharingOn: true).save
        let sentReminder = try #require(saved.first)

        #expect(participant.change(fromDeleted: sentReminder.recordID) == nil)
    }

    @Test(arguments: ["nonsense", "SentReminder.owner", "SentReminder.owner.not-a-uuid", "SentReminder.nobody.8A5E6A7C-3C45-4E39-9D6B-5F5E2F2B6C11", "Elsewhere.owner.8A5E6A7C-3C45-4E39-9D6B-5F5E2F2B6C11"])
    func aMalformedRecordNameIsIgnored(_ name: String) {
        let record = CKRecord(recordType: "SentReminder", recordID: CKRecord.ID(recordName: name, zoneID: owner.zoneID))

        #expect(participant.changes(from: fetched([record], writtenByOtherPerson: true)).isEmpty)
    }

    @Test func aRecordWhoseTypeDisagreesWithItsNameIsIgnored() throws {
        let saved = try owner.writes(for: change(.sentReminder), statusSharingOn: true).save
        let record = try #require(saved.first)
        let mislabeled = CKRecord(recordType: "Receipt", recordID: record.recordID)
        mislabeled.encryptedValues["receipt"] = "started"

        #expect(participant.changes(from: fetched([mislabeled], writtenByOtherPerson: true)).isEmpty)
    }

    @Test(arguments: ["title", "dueTime", "strength", "paceKind", "breakThroughFocus", "createdAt", "revision"])
    func aSentReminderMissingAFieldIsIgnored(_ field: String) throws {
        let record = try #require(try owner.writes(for: change(.sentReminder), statusSharingOn: true).save.first)
        record.encryptedValues[field] = nil

        #expect(participant.changes(from: fetched([record], writtenByOtherPerson: true)).isEmpty)
    }

    @Test func aValueThatCannotBeReadIsIgnored() throws {
        let record = try #require(try owner.writes(for: change(.sentReminder), statusSharingOn: true).save.first)
        record.encryptedValues["strength"] = "tremendous"

        #expect(participant.changes(from: fetched([record], writtenByOtherPerson: true)).isEmpty)
    }

    @Test func aFieldOfTheWrongTypeIsIgnored() throws {
        let record = try #require(try owner.writes(for: change(.sentReminder), statusSharingOn: true).save.first)
        record.encryptedValues["revision"] = "three"

        #expect(participant.changes(from: fetched([record], writtenByOtherPerson: true)).isEmpty)
    }

    @Test(arguments: [Int64(-1), Int64.min])
    func aNegativeOccurrenceCountIsIgnored(_ count: Int64) throws {
        let saved = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: true).save
        let status = try #require(saved.first { $0.recordType == "Status" })
        status.encryptedValues["occurrenceCount"] = count

        #expect(owner.changes(from: fetched(saved, writtenByOtherPerson: true)).isEmpty)
    }

    /// One bad record doesn't cost the good ones fetched with it.
    @Test func aBadRecordLeavesTheRestOfTheBatch() throws {
        let good = try #require(try owner.writes(for: change(.settings), statusSharingOn: true).save.first)
        let bad = CKRecord(recordType: "SentReminder", recordID: CKRecord.ID(recordName: "nonsense", zoneID: owner.zoneID))

        let read = participant.changes(from: fetched([bad, good], writtenByOtherPerson: true))

        #expect(read.map(\.kind) == [.settings])
    }

    @Test func aZoneNotNamedForAConnectionHasNoMapping() {
        #expect(SharingRecordMapping(zoneID: CKRecordZone.ID(zoneName: "Elsewhere", ownerName: CKCurrentUserDefaultName)) == nil)
    }

    /// CloudKit names the current user this way, and anyone else by their own user record.
    @Test func whoWroteARecordComesFromItsLastModifier() {
        #expect(SharingRecordMapping.FetchedRecord.isOtherPerson(lastModifiedBy: CKRecord.ID(recordName: "_theOtherPerson")))
        #expect(!SharingRecordMapping.FetchedRecord.isOtherPerson(lastModifiedBy: CKRecord.ID(recordName: CKCurrentUserDefaultName)))
        #expect(!SharingRecordMapping.FetchedRecord.isOtherPerson(lastModifiedBy: nil))
    }

    /// A record the adapter already holds has iCloud's change tag, so the fields go onto it.
    @Test func aChangeIsWrittenOntoTheRecordAlreadyHeld() throws {
        let change = SharingChange.send(SentReminder(reminder: reminder(), revision: 0), to: connectionID)
        let held = try #require(try owner.writes(for: change, statusSharingOn: true).save.first)

        let saved = try #require(try owner.writes(for: change, statusSharingOn: true, existing: { _ in held }).save.first)

        #expect(saved === held)
    }

    @Test func aRepeatTakenOffClearsItsFields() throws {
        let repeating = SentReminder(reminder: reminder(repeatRule: Self.endingAtATime, pace: .consistent(wait: 300)), revision: 0)
        let held = try #require(try owner.writes(for: .send(repeating, to: connectionID), statusSharingOn: true).save.first)
        let oneOff = SentReminder(reminder: reminder(), revision: 1)

        _ = try owner.writes(for: .revise(oneOff, for: connectionID), statusSharingOn: true, existing: { _ in held })

        #expect(held.encryptedValues["repeatRule"] == nil)
        #expect(held.encryptedValues["repeatMissingDay"] == nil)
        #expect(held.encryptedValues["repeatUntilTime"] == nil)
        #expect(held.encryptedValues["paceWait"] == nil)
    }

    @Test func aCancelLeavesTheRestOfTheRecordAlone() throws {
        let sent = SentReminder(reminder: reminder(), revision: 0)
        let held = try #require(try owner.writes(for: .send(sent, to: connectionID), statusSharingOn: true).save.first)

        _ = try owner.writes(for: .cancel(reminderID, for: connectionID), statusSharingOn: true, existing: { _ in held })

        #expect(held.encryptedValues["title"] as? String == "Water the plants")
        #expect(held.encryptedValues["canceled"] as? Int64 == 1)
    }

    /// Turning "Don't share this one" on must take the label already in iCloud off it.
    @Test func keepingAStatusFromItsSenderClearsTheLabelAlreadyHeld() throws {
        let saved = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: true).save
        let held = try #require(saved.first { $0.recordType == "Status" })

        _ = try participant.writes(for: statusChange(weekOfStatus(notSharingThisOne: true)), statusSharingOn: true, existing: { $0 == held.recordID ? held : nil })

        #expect(held.encryptedValues["label"] == nil)
        #expect(held.encryptedValues["notSharingThisOne"] as? Int64 == 1)
    }

    /// The production schema can only be added to, and a field can't become encrypted later, so
    /// the names and the encryption are pinned. A change here needs a look at spec #127 first.
    @Test func theRecordsHoldExactlyTheFieldsInTheSchema() throws {
        let sent = SentReminder(reminder: reminder(repeatRule: Self.endingAtATime, pace: .consistent(wait: 300)), revision: 1, changeNote: SharingChangeNotes.everyField)
        let sentRecord = try #require(try owner.writes(for: .revise(sent, for: connectionID), statusSharingOn: true).save.first)
        let settings = try #require(try owner.writes(for: change(.settings), statusSharingOn: true).save.first)
        let receipt = try #require(try participant.writes(for: change(.receipt), statusSharingOn: true).save.first)
        let statusRecords = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: true).save
        let status = try #require(statusRecords.first { $0.recordType == "Status" })
        let occurrence = try #require(statusRecords.first { $0.recordType == "OccurrenceStatus" })

        #expect(sentRecord.recordType == "SentReminder")
        #expect(Set(sentRecord.encryptedValues.allKeys()) == ["title", "notes", "dueTime", "repeatRule", "repeatMissingDay", "repeatUntilTime", "strength", "paceKind", "paceWait", "breakThroughFocus", "createdAt", "revision", "changeNote", "canceled"])
        #expect(settings.recordType == "ConnectionSettings")
        #expect(Set(settings.encryptedValues.allKeys()) == ["name", "sharesStatus"])
        #expect(receipt.recordType == "Receipt")
        #expect(Set(receipt.encryptedValues.allKeys()) == ["receipt"])
        #expect(Set(status.encryptedValues.allKeys()) == ["label", "notSharingThisOne", "occurrenceCount", "reportID"])
        #expect(Set(occurrence.encryptedValues.allKeys()) == ["dueTime", "year", "month", "day", "label", "reportID"])
        // A reference can't be encrypted, and is the only field out in the open.
        #expect(occurrence["status"] is CKRecord.Reference)
    }

    @Test(arguments: Written.allCases)
    func everyFieldIsEncrypted(_ written: Written) throws {
        let saved = try participant.writes(for: change(written), statusSharingOn: true).save

        for record in saved {
            for field in record.encryptedValues.allKeys() {
                #expect(record[field] == nil, "\(record.recordType).\(field) is not encrypted")
            }
        }
    }

    /// A record's name goes into iCloud for good.
    @Test func recordNamesAreSpelledAsInTheSchema() throws {
        let id = reminderID.uuidString
        let sent = try #require(try owner.writes(for: change(.sentReminder), statusSharingOn: true).save.first)
        let settings = try #require(try participant.writes(for: change(.settings), statusSharingOn: true).save.first)
        let receipt = try #require(try participant.writes(for: change(.receipt), statusSharingOn: true).save.first)
        let statusRecords = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: true).save

        #expect(sent.recordID.recordName == "SentReminder.owner.\(id)")
        #expect(settings.recordID.recordName == "ConnectionSettings.participant")
        #expect(receipt.recordID.recordName == "Receipt.participant.\(id)")
        #expect(statusRecords.first?.recordID.recordName == "Status.participant.\(id)")
        #expect(statusRecords.last?.recordID.recordName == "OccurrenceStatus.participant.\(id).7")
    }

    /// A fetch can split a status from its occurrences, so records already fetched are looked up.
    /// By name: each side has its own view of the zone's ID, and these were made on the writer's.
    func held(_ records: [CKRecord], writtenByOtherPerson: Bool = true) -> (CKRecord.ID) -> SharingRecordMapping.FetchedRecord? {
        { id in records.first { $0.recordID.recordName == id.recordName }.map { .init(record: $0, writtenByOtherPerson: writtenByOtherPerson) } }
    }

    @Test func aStatusCompletesFromOccurrencesAlreadyFetched() throws {
        let saved = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: true).save
        let status = try #require(saved.first { $0.recordType == "Status" })

        let read = owner.changes(from: fetched([status], writtenByOtherPerson: true), held: held(saved))

        #expect(read.map(\.content) == [.status(weekOfStatus())])
    }

    @Test func aStatusCompletesWhenItsOccurrencesArriveAfterIt() throws {
        let saved = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: true).save
        let occurrences = saved.filter { $0.recordType == "OccurrenceStatus" }

        let read = owner.changes(from: fetched(occurrences, writtenByOtherPerson: true), held: held(saved))

        #expect(read.map(\.content) == [.status(weekOfStatus())])
    }

    @Test func aRecordHeldFromThisPersonsOwnWriteDoesNotCompleteAStatus() throws {
        let saved = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: true).save
        let status = try #require(saved.first { $0.recordType == "Status" })

        let read = owner.changes(from: fetched([status], writtenByOtherPerson: true), held: held(saved, writtenByOtherPerson: false))

        #expect(read.isEmpty)
    }

    /// Slots are reused, so a day still held from the last report mustn't join the new one.
    @Test func aStatusWithADayFromAnEarlierReportWaits() throws {
        let earlier = try participant.writes(for: statusChange(weekOfStatus(label: .paused)), statusSharingOn: true).save
        let later = try participant.writes(for: statusChange(weekOfStatus(label: .done)), statusSharingOn: true).save
        let laterStatus = try #require(later.first { $0.recordType == "Status" })

        let read = owner.changes(from: fetched([laterStatus], writtenByOtherPerson: true), held: held(earlier))

        #expect(read.isEmpty)
    }

    @Test(arguments: ["FREQ=DAILY;COUNT=5", "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=5", "FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=-1;UNTIL=20270301", "FREQ=YEARLY;INTERVAL=2;BYMONTH=10;BYMONTHDAY=28;COUNT=30"])
    func aCustomRepeatReachesTheOtherSide(_ rrule: String) throws {
        let rule = try RepeatRule(rrule: rrule)

        try expectCarried(.send(SentReminder(reminder: reminder(repeatRule: rule), revision: 0), to: connectionID), from: owner, to: participant)
    }

    @Test(arguments: [(Written.settings, "name"), (.settings, "sharesStatus"), (.receipt, "receipt")])
    func aRecordMissingAFieldIsIgnored(_ written: Written, field: String) throws {
        let record = try #require(try participant.writes(for: change(written), statusSharingOn: true).save.first)
        record.encryptedValues[field] = nil

        #expect(owner.changes(from: fetched([record], writtenByOtherPerson: true)).isEmpty)
    }

    @Test(arguments: [("Status", "label"), ("Status", "notSharingThisOne"), ("Status", "occurrenceCount"), ("Status", "reportID"), ("OccurrenceStatus", "dueTime"), ("OccurrenceStatus", "year"), ("OccurrenceStatus", "month"), ("OccurrenceStatus", "day"), ("OccurrenceStatus", "label"), ("OccurrenceStatus", "reportID")])
    func aStatusMissingAFieldIsIgnored(recordType: String, field: String) throws {
        let saved = try participant.writes(for: statusChange(weekOfStatus()), statusSharingOn: true).save
        let record = try #require(saved.first { $0.recordType == recordType })
        record.encryptedValues[field] = nil

        #expect(owner.changes(from: fetched(saved, writtenByOtherPerson: true)).isEmpty)
    }

    /// A record never saved has no last modifier, so it can't count as the other person's.
    @Test func aRecordNoOneIsNamedAsWritingIsNotTheOtherPersons() throws {
        let record = try #require(try owner.writes(for: change(.settings), statusSharingOn: true).save.first)

        #expect(!SharingRecordMapping.FetchedRecord(fetched: record).writtenByOtherPerson)
    }

    /// A disconnect ends the share itself, which is the adapter's to do, so it writes no record.
    @Test func aDisconnectWritesNoRecords() throws {
        let writes = try owner.writes(for: .disconnect(connectionID), statusSharingOn: true)

        #expect(writes.save.isEmpty)
        #expect(writes.delete.isEmpty)
    }
}

/// A change note with every field in it, and both ways a repeat can come and go.
enum SharingChangeNotes {
    static let everyField: [ReceivedChange] = [
        .title(from: "Water", to: "Water the plants"),
        .notes(from: "", to: "Not the cactus"),
        .dueTime(from: Date(timeIntervalSinceReferenceDate: 815_000_000.25), to: Date(timeIntervalSinceReferenceDate: 815_003_600.75)),
        .repeatRule(from: nil, to: .everyDay),
        .repeatRule(from: .everyMonth, to: nil),
        .strength(from: .gentle, to: .relentless),
        .pace(from: .escalating, to: .consistent(wait: 300)),
        .breakThroughFocus(from: true, to: false),
    ]
}
