import Foundation
import Testing
import NudgeEngine
import SwiftData
@testable import NudgeInator

/// The sharing store keeps what sharing needs, beside the reminder store (ticket 191). Each test
/// saves to a temporary file, drops the store, and reads it back through a new one, as a relaunch
/// would.
@MainActor
struct SharingStoreTests {
    let storeFile = TemporaryStoreFile()

    func store() throws -> SharingStore {
        try SharingStore(location: .file(storeFile.url))
    }

    @Test func aSentReminderKeepsItsChangeNoteAfterARelaunch() throws {
        let reminder = Reminder(title: "Water the plants", dueTime: Date(timeIntervalSince1970: 1_791_000_000), strength: .firm)
        let saved = SharingData(sentReminders: [SentReminder(reminder: reminder, revision: 1, changeNote: SharingChangeNotes.everyField)])

        try store().save(saved)

        #expect(try store().load() == saved)
    }

    @Test func aConnectionReadsBackEqualAfterARelaunch() throws {
        let saved = SharingData(connections: [
            SharingConnection(id: UUID(), name: "Sam", state: .connected, connectedAt: Date(timeIntervalSince1970: 1_790_900_000)),
            SharingConnection(id: UUID(), name: "Alex (invited)", state: .invited, theirs: ConnectionChoices(sharesStatus: false)),
            // Each person's two choices are kept apart (ticket 196).
            SharingConnection(
                id: UUID(),
                name: "Riley",
                state: .connected,
                mine: ConnectionChoices(sharesStatus: false, deliveryMode: .startRightAway),
                theirs: ConnectionChoices(sharesStatus: true, deliveryMode: .askMeFirst)
            ),
            SharingConnection(id: UUID(), name: "Jordan", state: .connected, mine: ConnectionChoices(sharesStatus: true, deliveryMode: .askMeFirst)),
            // The other person disconnected, and this person hasn't chosen yet (ticket 197).
            SharingConnection(id: UUID(), name: "Priya", state: .ended, connectedAt: Date(timeIntervalSince1970: 1_790_000_000)),
        ])

        try store().save(saved)

        #expect(try store().load() == saved)
    }

    /// A sent reminder keeps what the sender's own reminder does, bar the tags it never has.
    @Test func aSentReminderReadsBackEqualAfterARelaunch() throws {
        let weekly = Reminder(
            title: "Water the plants",
            notes: "Not the cactus",
            dueTime: Date(timeIntervalSince1970: 1_791_000_000),
            repeatRule: .everyDay,
            strength: .relentless,
            pace: .consistent(wait: 300),
            breakThroughFocus: false,
            createdAt: Date(timeIntervalSince1970: 1_790_900_000)
        )
        let once = Reminder(
            title: "Call the plumber",
            dueTime: Date(timeIntervalSince1970: 1_791_100_000),
            strength: .gentle,
            createdAt: Date(timeIntervalSince1970: 1_790_950_000)
        )
        let saved = SharingData(sentReminders: [SentReminder(reminder: weekly, revision: 3), SentReminder(reminder: once, revision: 0)])

        try store().save(saved)

        #expect(try store().load() == saved)
    }

    nonisolated private static let allLabels: [ReportedStatus] = [.nudging, .comingUp, .paused, .done, .missed, .skipped, .removed]

    @Test func everyKindOfSentCopyReadsBackEqualAfterARelaunch() throws {
        let connection = UUID()
        let reminder = UUID()
        let made = Date(timeIntervalSince1970: 1_790_900_000)
        let history = Self.allLabels.enumerated().map { index, label in
            StatusReport.OccurrenceStatus(
                dueTime: Date(timeIntervalSince1970: 1_791_000_000 + Double(index) * 86_400),
                day: CalendarDay(year: 2026, month: 10, day: 3 + index),
                label: label
            )
        }
        let receipts: [SentCopy.Receipt] = [.notDelivered, .waitingForAcceptance, .started]
        var copies = receipts.map { receipt in
            SentCopy(connectionID: connection, reminderID: UUID(), createdAt: made, receipt: receipt, statusRecord: nil, waitingToSync: false)
        }
        copies.append(SentCopy(
            connectionID: connection,
            reminderID: reminder,
            createdAt: made,
            receipt: .started,
            statusRecord: SentCopy.StatusRecord(report: StatusReport(label: .nudging, occurrences: history), notSharingThisOne: false),
            waitingToSync: true
        ))
        copies.append(SentCopy(
            connectionID: connection,
            reminderID: UUID(),
            createdAt: made,
            receipt: .started,
            statusRecord: SentCopy.StatusRecord(report: StatusReport(label: .comingUp, occurrences: []), notSharingThisOne: true),
            waitingToSync: false
        ))
        let saved = SharingData(sentCopies: copies)

        try store().save(saved)

        #expect(try store().load() == saved)
    }

    @Test(arguments: SharingStoreTests.allLabels)
    func everyReportedStatusReadsBackTheSame(_ label: ReportedStatus) throws {
        let record = SentCopy.StatusRecord(
            report: StatusReport(
                label: label,
                occurrences: [StatusReport.OccurrenceStatus(dueTime: Date(timeIntervalSince1970: 1_791_000_000), day: CalendarDay(year: 2026, month: 10, day: 3), label: label)]
            ),
            notSharingThisOne: false
        )
        let copy = SentCopy(connectionID: UUID(), reminderID: UUID(), createdAt: .distantPast, receipt: .started, statusRecord: record, waitingToSync: false)
        let saved = SharingData(sentCopies: [copy])

        try store().save(saved)

        #expect(try store().load() == saved)
    }

    @Test func aReceivedRemindersSyncStateReadsBackEqualAfterARelaunch() throws {
        let saved = SharingData(receivedSyncStates: [
            ReceivedSyncState(reminderID: UUID(), notSharingThisOne: false, waitingToSync: false, recordSystemFields: nil),
            ReceivedSyncState(reminderID: UUID(), notSharingThisOne: true, waitingToSync: true, recordSystemFields: Data([0, 1, 2, 255])),
        ])

        try store().save(saved)

        #expect(try store().load() == saved)
    }

    @Test func theSyncEnginesSavedStateReadsBackForEachDatabase() throws {
        let saved = SharingData(engineStates: [
            SyncEngineState(database: .private, data: Data("private state".utf8)),
            SyncEngineState(database: .shared, data: Data("shared state".utf8)),
        ])

        try store().save(saved)

        #expect(try store().load() == saved)
    }

    /// The outbox is a queue, so it reads back in the order its changes were saved.
    @Test func theOutboxReadsBackInOrderAfterARelaunch() throws {
        let connection = UUID()
        let reminder = UUID()
        let kinds: [OutboxChange.Kind] = [.send, .revise, .cancel, .receipt, .status, .settings, .disconnect]
        let saved = SharingData(outbox: kinds.enumerated().map { index, kind in
            OutboxChange(id: UUID(), kind: kind, connectionID: connection, reminderID: index.isMultiple(of: 2) ? reminder : nil)
        }.reversed())

        try store().save(saved)

        #expect(try store().load() == saved)
    }

    /// Every kind of record at once, so none is read back as another's.
    @Test func everyKindOfRecordTogetherReadsBackEqual() throws {
        let connection = SharingConnection(id: UUID(), name: "Sam", state: .connected)
        let reminder = Reminder(title: "Call the plumber", dueTime: Date(timeIntervalSince1970: 1_791_000_000), strength: .firm, createdAt: Date(timeIntervalSince1970: 1_790_900_000))
        let saved = SharingData(
            connections: [connection],
            sentReminders: [SentReminder(reminder: reminder, revision: 1)],
            sentCopies: [SentCopy(connectionID: connection.id, reminderID: reminder.id, createdAt: reminder.createdAt, receipt: .started, statusRecord: nil, waitingToSync: false)],
            receivedSyncStates: [ReceivedSyncState(reminderID: UUID(), notSharingThisOne: true, waitingToSync: false, recordSystemFields: Data([7]))],
            engineStates: [SyncEngineState(database: .shared, data: Data([9]))],
            outbox: [OutboxChange(id: UUID(), kind: .send, connectionID: connection.id, reminderID: reminder.id)]
        )

        try store().save(saved)

        #expect(try store().load() == saved)
    }

    /// Sharing syncs through `CKSyncEngine`, never SwiftData. The default, `.automatic`, would sync
    /// as soon as a CloudKit entitlement appeared.
    @Test(arguments: [StoreLocation.appGroup, .inMemory, .file(URL(filePath: "/tmp/test.store"))])
    func noLocationSyncsWithCloudKit(_ location: StoreLocation) throws {
        // `CloudKitDatabase` isn't Equatable, so compare descriptions, after checking that they
        // tell `.none` from the default.
        let none = String(describing: ModelConfiguration.CloudKitDatabase.none)
        try #require(none != String(describing: ModelConfiguration.CloudKitDatabase.automatic))

        #expect(String(describing: SharingStore.configuration(for: location).cloudKitDatabase) == none)
    }

    /// Both stores live in the App Group, so a shared file name would open the reminder store's file.
    @Test func theAppGroupStoreHasItsOwnFileNextToTheReminderStore() {
        let sharing = SharingStore.configuration(for: .appGroup).url
        let reminders = ReminderStore.configuration(for: .appGroup).url

        #expect(sharing != reminders)
        #expect(sharing.deletingLastPathComponent() == reminders.deletingLastPathComponent())
    }

    @Test func theInMemoryStoreWritesNothingToDisk() {
        #expect(SharingStore.configuration(for: .inMemory).isStoredInMemoryOnly)
    }

    /// 1.4.0's first launch: nothing moves into the store.
    @Test func aStoreOpenedForTheFirstTimeIsEmpty() throws {
        #expect(try store().load() == SharingData())
    }

    /// A 1.3.0 phone's reminders, tags and histories read back as they were after the sharing store
    /// opened and saved beside them.
    @Test func openingAndFillingTheSharingStoreLeavesTheReminderStoreAsItWas() throws {
        let reminderFile = TemporaryStoreFile()
        let tag = Tag(name: "home")
        let pills = Reminder(title: "Take the pills", tagIDs: [tag.id], dueTime: Date(timeIntervalSince1970: 1_791_000_000), repeatRule: .everyDay, strength: .firm, createdAt: Date(timeIntervalSince1970: 1_790_900_000))
        let history = ReminderHistory(closedOccurrences: [Date(timeIntervalSince1970: 1_791_000_000): Closing(state: .done, closedAt: Date(timeIntervalSince1970: 1_791_000_100), nudgesSent: 1)])
        let personal = StoredData(reminders: [pills], tags: [tag], histories: [pills.id: history])
        try ReminderStore(location: .file(reminderFile.url), now: .distantPast).save(personal)

        try store().save(SharingData(connections: [SharingConnection(id: UUID(), name: "Sam", state: .connected, theirs: ConnectionChoices(sharesStatus: false))]))

        #expect(try ReminderStore(location: .file(reminderFile.url), now: .distantPast).load() == personal)
        #expect(try store().load().connections.count == 1)
    }

    @Test func savingReplacesWhatTheStoreHeld() throws {
        let connection = UUID()
        let first = SharingData(
            connections: [SharingConnection(id: connection, name: "Sam", state: .invited, theirs: ConnectionChoices(sharesStatus: false))],
            sentCopies: [SentCopy(connectionID: connection, reminderID: UUID(), createdAt: .distantPast, receipt: .notDelivered, statusRecord: nil, waitingToSync: true)],
            outbox: [OutboxChange(id: UUID(), kind: .send, connectionID: connection, reminderID: nil)]
        )
        try store().save(first)

        try store().save(SharingData(connections: [SharingConnection(id: connection, name: "Sam T.", state: .connected)]))

        #expect(try store().load() == SharingData(connections: [SharingConnection(id: connection, name: "Sam T.", state: .connected)]))
    }

    @Test func aSaveWithAConnectionIDTwiceIsTurnedDownAndChangesNothing() throws {
        let kept = SharingData(connections: [SharingConnection(id: UUID(), name: "Sam", state: .connected, theirs: ConnectionChoices(sharesStatus: false))])
        try store().save(kept)
        let id = UUID()
        let twice = SharingData(connections: [
            SharingConnection(id: id, name: "A", state: .connected, theirs: ConnectionChoices(sharesStatus: false)),
            SharingConnection(id: id, name: "B", state: .connected, theirs: ConnectionChoices(sharesStatus: false)),
        ])

        #expect(throws: StoreError.duplicateID(id)) { try store().save(twice) }

        #expect(try store().load() == kept)
    }

    /// A copy's reported history goes with it when a save replaces the copy: the batch delete would
    /// not have to apply the cascade rule.
    @Test func replacingACopyLeavesNoOccurrencesBehind() throws {
        let occurrence = StatusReport.OccurrenceStatus(dueTime: Date(timeIntervalSince1970: 1_791_000_000), day: CalendarDay(year: 2026, month: 10, day: 3), label: .done)
        let withHistory = SentCopy(
            connectionID: UUID(),
            reminderID: UUID(),
            createdAt: .distantPast,
            receipt: .started,
            statusRecord: SentCopy.StatusRecord(report: StatusReport(label: .done, occurrences: [occurrence, occurrence]), notSharingThisOne: false),
            waitingToSync: false
        )
        let sharing = try store()
        try sharing.save(SharingData(sentCopies: [withHistory]))
        try #require(try sharing.container.mainContext.fetchCount(FetchDescriptor<SentCopyOccurrenceRecord>()) == 2)

        try sharing.save(SharingData())

        #expect(try sharing.container.mainContext.fetchCount(FetchDescriptor<SentCopyOccurrenceRecord>()) == 0)
    }

    @Test func theSyncEnginesStatesReadBackInTheOrderSaved() throws {
        let saved = SharingData(engineStates: [
            SyncEngineState(database: .shared, data: Data([1])),
            SyncEngineState(database: .private, data: Data([2])),
        ])

        try store().save(saved)

        #expect(try store().load() == saved)
    }
}
