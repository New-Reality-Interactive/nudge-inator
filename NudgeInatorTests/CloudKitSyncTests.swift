import CloudKit
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The CloudKit sync's seam (#216, seam 1): an inviter's sync and an invitee's, each over stand-ins
/// for its two engines' queues, joined by a stand-in for iCloud. A test submits a change on one
/// side, sends, fetches on the other, and checks what that side reads and what each reports sent.
@MainActor
struct CloudKitSyncTests {
    let icloud = FakeICloud()
    let connectionID = UUID()
    let reminderID = UUID()
    let alex: FakeSyncDevice
    let sam: FakeSyncDevice

    /// Alex invited Sam, and Sam accepted: the zone is in Alex's private database, shared with Sam.
    init() {
        alex = FakeSyncDevice(icloud: icloud, userRecordName: "_alex")
        sam = FakeSyncDevice(icloud: icloud, userRecordName: "_sam")
        alex.sync.makeZone(for: connectionID)
        alex.send()
        icloud.share(connectionID, with: sam)
        sam.sync.joinZone(sam.zoneID(connectionID, owner: alex))
    }

    func sent(revision: Int = 0, title: String = "Water the plants", notes: String = "Not the cactus") -> SentReminder {
        SentReminder(
            reminder: Reminder(
                id: reminderID,
                title: title,
                notes: notes,
                dueTime: Date(timeIntervalSinceReferenceDate: 815_000_000),
                strength: .firm,
                createdAt: Date(timeIntervalSinceReferenceDate: 814_900_000)
            ),
            revision: revision
        )
    }

    /// `change` as `reader` got it: the same kind and content, under the reader's own outbox ID.
    func expectReceived(_ change: SharingChange, by reader: FakeSyncDevice, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(reader.received.map(\.kind) == [change.kind], sourceLocation: sourceLocation)
        #expect(reader.received.map(\.content) == [change.content], sourceLocation: sourceLocation)
        #expect(reader.received.map(\.reminderID) == [change.reminderID], sourceLocation: sourceLocation)
        #expect(reader.received.map(\.connectionID) == [change.connectionID], sourceLocation: sourceLocation)
    }

    @Test func aReminderTheInviterSendsReachesTheInvitee() {
        let change = SharingChange.send(sent(), to: connectionID)

        alex.submit(change)
        #expect(alex.sentIDs.isEmpty)
        alex.send()
        sam.fetch()

        expectReceived(change, by: sam)
        #expect(alex.sentIDs == [change.entry.id])
    }
}

extension CloudKitSyncTests {
    func status(_ label: ReportedStatus = .nudging, days: Int = 2) -> SentCopy.StatusRecord {
        let occurrences = (0..<days).map { day in
            StatusReport.OccurrenceStatus(
                dueTime: Date(timeIntervalSinceReferenceDate: 815_000_000 + Double(day) * 86_400),
                day: CalendarDay(year: 2026, month: 10, day: 10 + day),
                label: .done
            )
        }
        return SentCopy.StatusRecord(report: StatusReport(label: label, occurrences: occurrences), notSharingThisOne: false)
    }

    // MARK: Every kind of change goes both ways

    @Test func theInviteesReceiptAndStatusReachTheInviter() {
        let receipt = SharingChange.receipt(.started, for: reminderID, from: connectionID)
        let report = SharingChange.status(status(), for: reminderID, from: connectionID)

        sam.submit(receipt)
        sam.submit(report)
        sam.send()
        alex.fetch()

        #expect(alex.received.map(\.content) == [receipt.content, report.content])
        #expect(sam.sentIDs == [receipt.entry.id, report.entry.id])
    }

    @Test func aStatusGoesAheadOfItsOccurrences() throws {
        sam.submit(.status(status(days: 3), for: reminderID, from: connectionID))

        let batch = sam.sync.ordered(sam.sharedQueue.pendingRecordZoneChanges)

        let saved = batch.compactMap { change -> String? in
            guard case .saveRecord(let id) = change else { return nil }
            return id.recordName
        }
        #expect(saved.first?.hasPrefix("Status.") == true)
        #expect(saved.dropFirst().allSatisfy { $0.hasPrefix("OccurrenceStatus.") })
        #expect(saved.count == 4)
    }

    @Test func aStatusSplitAcrossFetchesIsReadOnceWhole() {
        let report = SharingChange.status(status(days: 3), for: reminderID, from: connectionID)
        sam.submit(report)
        sam.batchLimit = 2

        sam.send()
        alex.fetch()
        #expect(alex.received.isEmpty)
        #expect(sam.sentIDs.isEmpty)

        sam.batchLimit = nil
        sam.send()
        alex.fetch()
        #expect(alex.received.map(\.content) == [report.content])
        #expect(sam.sentIDs == [report.entry.id])
    }

    /// A status write deletes the occurrence slots it doesn't use, most of which never existed.
    @Test func deletingARecordThatIsNotThereCountsAsDone() {
        let report = SharingChange.status(status(days: 1), for: reminderID, from: connectionID)

        sam.submit(report)
        sam.send()

        #expect(sam.lastFailures.contains(.unknownItem))
        #expect(sam.sentIDs == [report.entry.id])
    }

    @Test func aStatusTurnedOffIsDeletedForTheInviter() {
        sam.submit(.status(status(), for: reminderID, from: connectionID))
        sam.send()
        alex.fetch()

        sam.submit(.status(nil, for: reminderID, from: connectionID))
        sam.send()
        alex.fetch()

        #expect(alex.received.map(\.content).last == .status(nil))
        #expect(icloud.stored(connectionID, "Status.participant.\(reminderID.uuidString)") == nil)
    }

    @Test func withStatusSharingOffAStatusIsDeletedNotWritten() {
        sam.submit(.settings(.init(ConnectionChoices(sharesStatus: false)), for: connectionID))
        sam.submit(.status(status(), for: reminderID, from: connectionID))
        sam.send()

        #expect(icloud.stored(connectionID, "Status.participant.\(reminderID.uuidString)") == nil)
    }

    @Test func settingsGoBothWays() {
        let samsChoices = SharingChange.settings(.init(ConnectionChoices(sharesStatus: false, deliveryMode: .askMeFirst)), for: connectionID)
        let alexsChoices = SharingChange.settings(.init(ConnectionChoices(sharesStatus: true)), for: connectionID)

        sam.submit(samsChoices)
        alex.submit(alexsChoices)
        sam.send()
        alex.send()
        alex.fetch()
        sam.fetch()

        expectReceived(samsChoices, by: alex)
        expectReceived(alexsChoices, by: sam)
    }

    @Test func theInviteeSendsToTheInviterToo() {
        let change = SharingChange.send(sent(), to: connectionID)

        sam.submit(change)
        sam.send()
        alex.fetch()

        expectReceived(change, by: alex)
    }

    @Test func aRevisionClearsAFieldItNoLongerHas() throws {
        var first = sent()
        first.reminder.repeatRule = .everyDay
        alex.submit(.send(first, to: connectionID))
        alex.send()
        sam.fetch()

        let revision = SharingChange.revise(sent(revision: 1, title: "Water the ferns"), for: connectionID)
        alex.submit(revision)
        alex.send()
        sam.fetch()

        guard case .reminder(let read) = sam.received.last?.content else { Issue.record("No revision read"); return }
        #expect(read.reminder.repeatRule == nil)
        #expect(read.reminder.title == "Water the ferns")
        #expect(sam.received.last?.kind == .revise)
    }

    @Test func aCancelReachesTheInvitee() {
        alex.submit(.send(sent(), to: connectionID))
        alex.send()
        let cancel = SharingChange.cancel(reminderID, for: connectionID)

        alex.submit(cancel)
        alex.send()
        sam.fetch()

        // Offline across both, Sam hears of the reminder first as its cancel (#193).
        expectReceived(cancel, by: sam)
        #expect(alex.sentIDs.last == cancel.entry.id)
    }

    // MARK: When iCloud refuses

    @Test func aSaveOnAnOlderVersionGoesAgainOnICloudsOwn() {
        alex.submit(.send(sent(), to: connectionID))
        alex.send()
        sam.fetch()
        icloud.changeElsewhere(connectionID, "SentReminder.owner.\(reminderID.uuidString)")
        let revision = SharingChange.revise(sent(revision: 1, title: "Water the ferns"), for: connectionID)

        alex.submit(revision)
        alex.send()
        #expect(alex.lastFailures == [.serverRecordChanged])
        #expect(!alex.sentIDs.contains(revision.entry.id))

        alex.send()
        sam.fetch()
        #expect(alex.sentIDs.last == revision.entry.id)
        #expect(sam.received.last?.kind == .revise)
    }

    /// iCloud took a save while a later change to the same record was waiting: that one still goes.
    @Test func aLaterChangeToARecordInFlightStillGoes() throws {
        let first = SharingChange.send(sent(), to: connectionID)
        alex.submit(first)
        let recordID = CKRecord.ID(recordName: "SentReminder.owner.\(reminderID.uuidString)", zoneID: alex.zoneID(connectionID, owner: alex))
        let inFlight = try #require(alex.sync.record(for: recordID))
        let second = SharingChange.revise(sent(revision: 1), for: connectionID)
        alex.submit(second)

        let done = alex.sync.sent(saved: [inFlight], failedSaves: [], deleted: [], failedDeletes: [:])

        #expect(done == CloudKitSync.Outcome())
        #expect(alex.privateQueue.pendingRecordZoneChanges == [.saveRecord(recordID)])
    }

    /// The share went with the zone, so the connection is over: the inviter invites again.
    @Test func aZoneICloudLostEndsTheConnection() {
        alex.submit(.send(sent(), to: connectionID))
        alex.send()
        icloud.loseZone(connectionID)
        icloud.resetsEncryptedData.insert(connectionID.uuidString)
        let revision = SharingChange.revise(sent(revision: 1), for: connectionID)

        alex.submit(revision)
        alex.send()

        #expect(alex.lastFailures == [.zoneNotFound])
        expectReceived(.disconnect(connectionID), by: alex)
        #expect(alex.sentIDs.last == revision.entry.id)
        #expect(alex.sync.cache.zones[connectionID] == nil)
        #expect(icloud.stored(connectionID, "SentReminder.owner.\(reminderID.uuidString)") == nil)
    }

    @Test func aChangeICloudRefusesForGoodCountsAsGone() {
        let change = SharingChange.send(sent(), to: connectionID)
        icloud.refusals["SentReminder.owner.\(reminderID.uuidString)"] = .permissionFailure

        alex.submit(change)
        alex.send()

        #expect(alex.sentIDs == [change.entry.id])
        #expect(alex.sync.cache.records.isEmpty)
    }

    /// Waiting to sync is true while iCloud is full; the next launch tries again.
    @Test func aChangeRefusedForAFullICloudWaitsForTheNextLaunch() {
        let change = SharingChange.send(sent(), to: connectionID)
        icloud.refusals["SentReminder.owner.\(reminderID.uuidString)"] = .quotaExceeded

        alex.submit(change)
        alex.send()
        #expect(alex.sentIDs.isEmpty)

        alex.relaunch()
        alex.send()
        sam.fetch()
        #expect(alex.sentIDs == [change.entry.id])
        expectReceived(change, by: sam)
    }

    @Test func aChangeTheEngineRetriesWaitsAndThenGoes() {
        let change = SharingChange.send(sent(), to: connectionID)
        icloud.refusals["SentReminder.owner.\(reminderID.uuidString)"] = .networkFailure

        alex.submit(change)
        alex.send()
        #expect(alex.sentIDs.isEmpty)

        alex.send()
        #expect(alex.sentIDs == [change.entry.id])
    }

    // MARK: Unsent changes are kept

    @Test func anUnsentChangeGoesAfterARelaunch() {
        let change = SharingChange.send(sent(), to: connectionID)
        alex.submit(change)

        alex.relaunch()
        alex.send()
        sam.fetch()

        expectReceived(change, by: sam)
        #expect(alex.sentIDs == [change.entry.id])
    }

    @Test func anUnsentChangeGoesWhenTheSameAccountSignsInAgain() {
        let change = SharingChange.send(sent(), to: connectionID)
        alex.submit(change)

        alex.accountChanged(.signOut)
        alex.send()
        #expect(alex.sentIDs.isEmpty)
        alex.accountChanged(.signIn)
        alex.send()
        sam.fetch()

        expectReceived(change, by: sam)
    }

    @Test func aSwitchOfAccountsForgetsTheOldAccountsSharing() {
        alex.submit(.send(sent(), to: connectionID))

        alex.accountChanged(.switchAccounts)
        alex.send()

        #expect(alex.sync.cache == CloudKitSyncCache())
        #expect(icloud.stored(connectionID, "SentReminder.owner.\(reminderID.uuidString)") == nil)
    }

    // MARK: Disconnect

    @Test func theInviterDisconnectingEndsTheConnectionForTheInvitee() {
        let settings = SharingChange.settings(.init(ConnectionChoices()), for: connectionID)
        alex.submit(settings)
        alex.send()
        let waiting = SharingChange.send(sent(), to: connectionID)
        alex.submit(waiting)
        let disconnect = SharingChange.disconnect(connectionID)

        alex.submit(disconnect)
        // Only what still has to go is kept: the zone's delete, as after Delete All Data.
        #expect(alex.sync.cache.records.isEmpty)
        #expect(alex.sync.cache.zoneDeletes == [connectionID: [disconnect.entry.id]])
        alex.send()
        sam.fetch()

        expectReceived(.disconnect(connectionID), by: sam)
        // What was still to go never will: it counts as gone, with the disconnect.
        #expect(Set(alex.sentIDs) == [settings.entry.id, waiting.entry.id, disconnect.entry.id])
        #expect(sam.sync.cache.zones[connectionID] == nil)
    }

    /// A save that finds the zone gone may come before the fetch that says why.
    @Test func theInviteeHearsTheConnectionEndedWhenASaveFindsTheZoneGone() {
        alex.submit(.disconnect(connectionID))
        alex.send()
        let moot = SharingChange.receipt(.started, for: reminderID, from: connectionID)

        sam.submit(moot)
        sam.send()
        sam.fetch()

        #expect(sam.lastFailures == [.zoneNotFound])
        #expect(sam.sentIDs == [moot.entry.id])
        expectReceived(.disconnect(connectionID), by: sam)
    }

    @Test func aChangeStillToGoWhenTheInviterEndsItCountsAsGone() {
        let moot = SharingChange.receipt(.started, for: reminderID, from: connectionID)
        sam.submit(moot)
        alex.submit(.disconnect(connectionID))
        alex.send()

        sam.fetch()

        #expect(sam.sentIDs == [moot.entry.id])
        expectReceived(.disconnect(connectionID), by: sam)
    }

    @Test func theInviteeDisconnectingLeavesTheShareAndTheInviterHearsIt() {
        _ = alex.sync.fetchedShare(in: connectionID, hasAcceptedParticipant: true)
        let moot = SharingChange.send(sent(), to: connectionID)
        alex.submit(moot)
        let disconnect = SharingChange.disconnect(connectionID)

        sam.submit(disconnect)
        sam.send()
        let heard = alex.sync.fetchedShare(in: connectionID, hasAcceptedParticipant: false)

        #expect(sam.sentIDs == [disconnect.entry.id])
        #expect(sam.sync.cache.zones[connectionID] == nil)
        #expect(heard.received.map(\.kind) == [.disconnect])
        #expect(heard.gone == [moot.entry.id])
        // The zone is of no more use to the inviter.
        alex.send()
        #expect(alex.sync.cache.zones[connectionID] == nil)
    }

    @Test func aShareNoOneHasAcceptedYetIsNoDisconnect() {
        #expect(alex.sync.fetchedShare(in: connectionID, hasAcceptedParticipant: false).received.isEmpty)
    }

    @Test func theShareIsPrivate() {
        let share = CloudKitSync.share(for: alex.zoneID(connectionID, owner: alex))
        #expect(share.publicPermission == .none)
    }
}
