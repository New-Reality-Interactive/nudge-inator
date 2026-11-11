import Foundation
import Testing
@testable import NudgeEngine

/// What the sender's side shows for each reminder it sent, from what its app knows (spec #127,
/// Status and the Reminders tab's Sent view).
struct SentReadOutTests {
    let sam = SentConnection(id: UUID(), name: "Sam", sharesStatus: true)
    let alex = SentConnection(id: UUID(), name: "Alex", sharesStatus: true)

    /// A status record for a copy that is Nudging, with no history.
    func nudging(history: [StatusReport.OccurrenceStatus] = [], notSharingThisOne: Bool = false) -> SentCopy.StatusRecord {
        SentCopy.StatusRecord(
            report: StatusReport(label: .nudging, occurrences: history),
            notSharingThisOne: notSharingThisOne
        )
    }

    /// A status record for a copy that reads `label`, with no history.
    func record(_ label: ReportedStatus) -> SentCopy.StatusRecord {
        SentCopy.StatusRecord(report: StatusReport(label: label, occurrences: []), notSharingThisOne: false)
    }

    /// `sam`, whose status sharing is off.
    var quietSam: SentConnection {
        SentConnection(id: sam.id, name: sam.name, sharesStatus: false)
    }

    /// A copy of a sent reminder that reached `connection` and started right away.
    func copy(
        of reminderID: UUID = UUID(),
        to connection: SentConnection,
        createdAt: Date = Date(timeIntervalSince1970: 1_000),
        receipt: SentCopy.Receipt = .started,
        statusRecord: SentCopy.StatusRecord? = nil,
        waitingToSync: Bool = false
    ) -> SentCopy {
        SentCopy(
            connectionID: connection.id,
            reminderID: reminderID,
            createdAt: createdAt,
            receipt: receipt,
            statusRecord: statusRecord,
            waitingToSync: waitingToSync
        )
    }

    // MARK: Delivered, and the status

    @Test func aDeliveredCopyWithStatusSharingOnShowsDeliveredAndItsStatus() throws {
        let readOut = SentReadOut(connections: [sam], copies: [copy(to: sam, statusRecord: nudging())])
        let row = try #require(readOut.people.first?.rows.first)
        #expect(row.delivery == .delivered)
        #expect(row.status == .reported(.nudging, history: []))
    }

    @Test func aCopyNotYetOnTheirPhoneIsNotDelivered() {
        let readOut = SentReadOut(connections: [sam], copies: [copy(to: sam, receipt: .notDelivered)])
        #expect(readOut.people.first?.rows.first?.delivery == .notDelivered)
    }

    @Test func aCopyWaitingForThemToAcceptIsNotShownAsDeliveredOrWithAStatus() throws {
        // The recipient's engine reads Coming up for a waiting copy (#188); the sender says Waiting.
        let waitingReport = record(.comingUp)
        let readOut = SentReadOut(
            connections: [sam],
            copies: [copy(to: sam, receipt: .waitingForAcceptance, statusRecord: waitingReport)]
        )
        let row = try #require(readOut.people.first?.rows.first)
        #expect(row.delivery == .waitingForAcceptance)
        #expect(row.status == .notReportedYet)
    }

    // MARK: Waiting to sync, Removed and the history

    @Test func aCopyNotYetSyncedIsWaitingToSyncAndTheRestAreNot() {
        let readOut = SentReadOut(
            connections: [sam],
            copies: [
                copy(of: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, to: sam, waitingToSync: true),
                copy(of: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, to: sam)
            ]
        )
        #expect(readOut.people.first?.rows.map(\.waitingToSync) == [true, false])
    }

    @Test func aCopyTheyRemovedReadsRemovedWhenTheyShareStatus() {
        let removed = record(.removed)
        let readOut = SentReadOut(connections: [sam], copies: [copy(to: sam, statusRecord: removed)])
        #expect(readOut.people.first?.rows.first?.status == .reported(.removed, history: []))
    }

    @Test func aHistoryIsOldestFirstAndKeepsTheRecipientsDays() {
        // The days are the recipient's; the read-out passes them on as reported, whatever order the
        // records arrived in.
        func occurrence(_ day: Int, _ label: ReportedStatus) -> StatusReport.OccurrenceStatus {
            StatusReport.OccurrenceStatus(
                dueTime: NewYork.local(2026, 10, day, 9),
                day: CalendarDay(year: 2026, month: 10, day: day),
                label: label
            )
        }
        let shuffled = [occurrence(16, .nudging), occurrence(14, .done), occurrence(15, .missed)]
        let readOut = SentReadOut(connections: [sam], copies: [copy(to: sam, statusRecord: nudging(history: shuffled))])
        #expect(
            readOut.people.first?.rows.first?.status
                == .reported(.nudging, history: [occurrence(14, .done), occurrence(15, .missed), occurrence(16, .nudging)])
        )
    }

    // MARK: Grouped by person

    @Test func aReminderSentToSeveralPeopleHasARowUnderEachWithItsOwnStatus() {
        let reminderID = UUID()
        let done = record(.done)
        let missed = record(.missed)
        let readOut = SentReadOut(
            connections: [sam, alex],
            copies: [copy(of: reminderID, to: sam, statusRecord: done), copy(of: reminderID, to: alex, statusRecord: missed)]
        )
        #expect(readOut.people.map(\.name) == ["Alex", "Sam"])
        #expect(readOut.people.map { $0.rows.map(\.reminderID) } == [[reminderID], [reminderID]])
        #expect(readOut.people.map { $0.rows.map(\.status) } == [
            [.reported(.missed, history: [])],
            [.reported(.done, history: [])]
        ])
    }

    @Test func peopleAreOrderedByNameThenByConnectionID() {
        let low = SentConnection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "sam", sharesStatus: true)
        let high = SentConnection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Sam", sharesStatus: true)
        let ana = SentConnection(id: UUID(), name: "Ana", sharesStatus: true)
        let last = SentConnection(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "SAM", sharesStatus: true)
        let copies = [high, low, last, ana].map { copy(to: $0) }
        let readOut = SentReadOut(connections: [high, low, last, ana], copies: copies)
        // Names compare without regard to case; equal names fall back to the connection's ID.
        #expect(readOut.people.map(\.connectionID) == [ana.id, low.id, high.id, last.id])
    }

    @Test func rowsAreOrderedByCreationDateThenByReminderID() {
        let first = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
        let second = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
        let newest = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let readOut = SentReadOut(
            connections: [sam],
            copies: [
                copy(of: newest, to: sam, createdAt: Date(timeIntervalSince1970: 3_000)),
                copy(of: second, to: sam, createdAt: Date(timeIntervalSince1970: 2_000)),
                copy(of: first, to: sam, createdAt: Date(timeIntervalSince1970: 2_000))
            ]
        )
        #expect(readOut.people.first?.rows.map(\.reminderID) == [first, second, newest])
    }

    @Test func theOrderDoesNotDependOnTheOrderTheCopiesAndConnectionsCameIn() {
        let copies = [copy(to: sam, createdAt: Date(timeIntervalSince1970: 1)), copy(to: alex), copy(to: sam)]
        let forward = SentReadOut(connections: [sam, alex], copies: copies)
        let backward = SentReadOut(connections: [alex, sam], copies: copies.reversed())
        #expect(forward == backward)
    }

    @Test func aPersonWithNothingSentHasNoGroup() {
        let readOut = SentReadOut(connections: [sam, alex], copies: [copy(to: sam)])
        #expect(readOut.people.map(\.name) == ["Sam"])
    }

    @Test func nothingSentAtAllIsAnEmptyReadOut() {
        #expect(SentReadOut(connections: [sam], copies: []).people.isEmpty)
        #expect(SentReadOut(connections: [], copies: []).people.isEmpty)
    }

    @Test func aCopyOfAConnectionTheSenderNoLongerHoldsIsLeftOut() {
        let readOut = SentReadOut(connections: [sam], copies: [copy(to: sam), copy(to: alex)])
        #expect(readOut.people.map(\.name) == ["Sam"])
        #expect(readOut.people.first?.rows.count == 1)
    }

    // MARK: Status sharing

    @Test func withStatusSharingOffARowIsDeliveredAndNotSharingStatusWhateverItHolds() throws {
        // A status the sender already holds is hidden when sharing goes off.
        let readOut = SentReadOut(connections: [quietSam], copies: [copy(to: quietSam, statusRecord: nudging())])
        let row = try #require(readOut.people.first?.rows.first)
        #expect(row.delivery == .delivered)
        #expect(row.status == .notSharingStatus)
    }

    @Test func turningStatusSharingBackOnShowsTheCurrentStatusAndTheLast7Days() {
        let yesterday = StatusReport.OccurrenceStatus(
            dueTime: NewYork.local(2026, 10, 14, 9),
            day: CalendarDay(year: 2026, month: 10, day: 14),
            label: .done
        )
        let held = copy(to: sam, statusRecord: nudging(history: [yesterday]))
        #expect(SentReadOut(connections: [quietSam], copies: [held]).people.first?.rows.first?.status == .notSharingStatus)
        #expect(
            SentReadOut(connections: [sam], copies: [held]).people.first?.rows.first?.status
                == .reported(.nudging, history: [yesterday])
        )
    }

    @Test func withStatusSharingOffACopyNotYetDeliveredStillShowsNoStatus() throws {
        let readOut = SentReadOut(connections: [quietSam], copies: [copy(to: quietSam, receipt: .notDelivered)])
        let row = try #require(readOut.people.first?.rows.first)
        #expect(row.delivery == .notDelivered)
        #expect(row.status == .notSharingStatus)
    }

    @Test func aReminderTheyKeepPrivateReadsNotSharingThisOneWithNoStatus() throws {
        let readOut = SentReadOut(
            connections: [sam],
            copies: [copy(to: sam, statusRecord: nudging(notSharingThisOne: true))]
        )
        let row = try #require(readOut.people.first?.rows.first)
        #expect(row.delivery == .delivered)
        #expect(row.status == .notSharingThisOne)
    }

    @Test func statusSharingOffReadsNotSharingStatusEvenForAReminderTheyKeepPrivate() {
        let readOut = SentReadOut(
            connections: [quietSam],
            copies: [copy(to: quietSam, statusRecord: nudging(notSharingThisOne: true))]
        )
        #expect(readOut.people.first?.rows.first?.status == .notSharingStatus)
    }

    @Test func aWaitingCopyTheyRemovedReadsRemovedAndNoLongerWaiting() throws {
        // Remove is open to a copy that still waits (spec #127, Receiving), and the sender sees it.
        let removed = record(.removed)
        let readOut = SentReadOut(
            connections: [sam],
            copies: [copy(to: sam, receipt: .waitingForAcceptance, statusRecord: removed)]
        )
        let row = try #require(readOut.people.first?.rows.first)
        #expect(row.delivery == .delivered)
        #expect(row.status == .reported(.removed, history: []))
    }

    @Test func aWaitingCopyTheyRemovedStaysWaitingToTheSenderWhileStatusSharingIsOff() throws {
        let removed = record(.removed)
        let readOut = SentReadOut(
            connections: [quietSam],
            copies: [copy(to: quietSam, receipt: .waitingForAcceptance, statusRecord: removed)]
        )
        let row = try #require(readOut.people.first?.rows.first)
        #expect(row.delivery == .waitingForAcceptance)
        #expect(row.status == .notSharingStatus)
    }

    @Test func aDeliveredCopyWhoseStatusHasNotArrivedHasNoStatusYet() throws {
        let readOut = SentReadOut(connections: [sam], copies: [copy(to: sam, statusRecord: nil)])
        let row = try #require(readOut.people.first?.rows.first)
        #expect(row.delivery == .delivered)
        #expect(row.status == .notReportedYet)
    }
}
