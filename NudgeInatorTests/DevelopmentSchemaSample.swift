import CloudKit
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// One record of every sharing record type, with every field set, built by the app's own record
/// mapping. CloudKit adds a type or field to the development schema only when a save uses it, and
/// production schemas only add, so the schema device check saves these before the deploy (#327).
enum DevelopmentSchemaSample {
    static func records(in zoneID: CKRecordZone.ID) throws -> [CKRecord] {
        let mapping = try #require(SharingRecordMapping(zoneID: zoneID))
        let connectionID = mapping.connectionID
        let reminderID = UUID()
        var repeating = RepeatRule.everyMonth
        repeating.end = .untilTime(Date(timeIntervalSinceReferenceDate: 816_000_000))
        let reminder = Reminder(
            id: reminderID,
            title: "Schema check",
            notes: "Written by the development schema check, then deleted",
            dueTime: Date(timeIntervalSinceReferenceDate: 815_000_000),
            repeatRule: repeating,
            strength: .firm,
            pace: .consistent(wait: 300),
            breakThroughFocus: true,
            createdAt: Date(timeIntervalSinceReferenceDate: 814_900_000)
        )
        let occurrences = (0..<2).map { day in
            StatusReport.OccurrenceStatus(
                dueTime: Date(timeIntervalSinceReferenceDate: 815_000_000 + Double(day) * 86_400),
                day: CalendarDay(year: 2026, month: 10, day: 8 + day),
                label: .done
            )
        }
        let changes: [SharingChange] = [
            .settings(.init(name: "Schema Check", ConnectionChoices(sharesStatus: true, deliveryMode: .askMeFirst)), for: connectionID),
            .send(SentReminder(reminder: reminder, revision: 1, changeNote: SharingChangeNotes.everyField), to: connectionID),
            .receipt(.started, for: reminderID, from: connectionID),
            .status(SentCopy.StatusRecord(report: StatusReport(label: .done, occurrences: occurrences), notSharingThisOne: false), for: reminderID, from: connectionID),
        ]
        return try changes.flatMap { try mapping.writes(for: $0, statusSharingOn: true).save }
    }

    /// Every field set on `record`, plain or encrypted.
    static func fields(of record: CKRecord) -> Set<String> {
        Set(record.allKeys()).union(record.encryptedValues.allKeys())
    }
}
