import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Status on the Sent view (ticket 206, spec #127 seam 1): Alex sends Riley a reminder, Riley's app
/// reports how the copy is going through the fake network, and the tests read Alex's Sent screen and
/// the sent reminder's details as Alex's app model builds them. Layout and VoiceOver's reading
/// aloud are the phone check.
@MainActor
struct StatusOnSentRowsTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let connectionID = UUID()

    /// Due at 8:30 every day, Firm: the phones' clocks say 8:00 on 15 October.
    let pills = Reminder(
        title: "Take the pills",
        notes: "Two with water",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .firm,
        pace: .consistent(wait: 10 * 60)
    )

    /// Alex and Riley, connected, launched and joined by the network. `sharesStatus` is Riley's
    /// Status sharing with Alex, and `deliveryMode` Riley's Delivery mode.
    func phones(sharesStatus: Bool = true, deliveryMode: DeliveryMode = .startRightAway) async throws -> (alex: Phone, riley: Phone) {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Riley Park", state: .connected, theirs: ConnectionChoices(sharesStatus: sharesStatus, deliveryMode: deliveryMode)),
        ]))
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Alex Morgan", state: .connected, mine: ConnectionChoices(sharesStatus: sharesStatus, deliveryMode: deliveryMode)),
        ]))
        network.join(alex.adapter, riley.adapter, through: connectionID)
        for phone in [alex, riley] { await phone.launch() }
        return (alex, riley)
    }

    func settle(_ phones: Phone...) async {
        for phone in phones { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in phones { await phone.model.waitUntilApplied() }
    }

    func send(_ reminder: Reminder, from alex: Phone, to riley: Phone) async throws {
        try alex.model.send(reminder, to: [connectionID])
        await settle(alex, riley)
    }

    /// Riley's phone at `hour`:`minute` on 15 October, the app opened there.
    func open(_ riley: Phone, at hour: Int, _ minute: Int, alex: Phone) async {
        riley.clock.now = NewYork.local(2026, 10, 15, hour, minute)
        await riley.model.appOpened()
        await settle(alex, riley)
    }

    func row(on alex: Phone) throws -> SentScreen.Row {
        let screen = SentScreen(engine: alex.model.engine, sharing: alex.sharing.data)
        return try #require(screen.people.first?.rows.first)
    }

    func copy(on riley: Phone) throws -> Reminder {
        try #require(riley.model.engine.reminders.first { $0.isReceived })
    }

    // MARK: The status label

    @Test func theSenderSeesComingUpOnceTheCopyArrives() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        let row = try row(on: alex)

        #expect(row.trailing == .status(.comingUp))
        #expect(row.detailLine == nil ? false : String(localized: row.detailLine!) == "Delivered")
        #expect(String(localized: row.voiceOverLabel) == "Riley Park, Take the pills, Coming up, Today, 8:30\u{202F}AM")
    }

    /// Due at 9:00 today, once, Gentle.
    let call = Reminder(title: "Call the clinic", dueTime: NewYork.local(2026, 10, 15, 9, 0), strength: .gentle)

    func statusReports(from riley: Phone) -> [SharingChange] {
        riley.adapter.submitted.filter { $0.kind == .status }
    }

    @Test func theLabelFollowsTheCopyAsItIsPausedResumedAndComesDue() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        riley.model.pause(try copy(on: riley).id)
        await settle(alex, riley)
        #expect(try row(on: alex).trailing == .status(.paused))

        try riley.model.resume(try copy(on: riley).id)
        await open(riley, at: 8, 35, alex: alex)
        #expect(try row(on: alex).trailing == .status(.nudging))
    }

    @Test func aOneOffMarkedDoneReadsDone() async throws {
        let (alex, riley) = try await phones()
        try await send(call, from: alex, to: riley)
        await open(riley, at: 9, 5, alex: alex)
        #expect(try row(on: alex).trailing == .status(.nudging))

        riley.model.markDone(try copy(on: riley).id)
        await settle(alex, riley)

        #expect(try row(on: alex).trailing == .status(.done))
    }

    @Test func aCopyNobodyMarkedDoneIsMissedOnceItsGiveUpLimitHasPassed() async throws {
        let (alex, riley) = try await phones()
        try await send(call, from: alex, to: riley)

        riley.clock.now = NewYork.local(2026, 10, 16, 8)
        await riley.model.appOpened()
        await settle(alex, riley)

        #expect(try row(on: alex).trailing == .status(.missed))
    }

    @Test func aStatusThatHasntChangedIsNotSentAgain() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        let sent = statusReports(from: riley).count

        await open(riley, at: 8, 5, alex: alex)
        await open(riley, at: 8, 10, alex: alex)

        #expect(sent == 1)
        #expect(statusReports(from: riley).count == sent)
    }

    @Test func aRelaunchSendsEachCopysCurrentStatusOnce() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        let before = statusReports(from: riley).count

        riley.relaunch()
        await riley.launch()
        await open(riley, at: 8, 5, alex: alex)
        await open(riley, at: 8, 6, alex: alex)

        #expect(statusReports(from: riley).count == before + 1)
        #expect(try row(on: alex).trailing == .status(.comingUp))
    }

    // MARK: Status sharing off

    @Test func withStatusSharingOffTheSenderSeesDeliveredAndNotSharingStatusAndNoStatusIsSent() async throws {
        let (alex, riley) = try await phones(sharesStatus: false)
        try await send(pills, from: alex, to: riley)
        await open(riley, at: 8, 35, alex: alex)

        let row = try row(on: alex)

        #expect(statusReports(from: riley).isEmpty)
        #expect(row.trailing == .delivered)
        #expect(String(localized: try #require(row.detailLine)) == "Not sharing status")
        #expect(String(localized: row.voiceOverLabel) == "Riley Park, Take the pills, Delivered, Not sharing status, Today, 8:30\u{202F}AM")
    }

    @Test func turningStatusSharingOffHidesWhatTheSenderSawAndOnShowsTheCurrentStatus() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        #expect(try row(on: alex).trailing == .status(.comingUp))

        try riley.sharing.change(ConnectionChoices(sharesStatus: false), for: connectionID)
        await settle(alex, riley)
        #expect(try row(on: alex).trailing == .delivered)
        #expect(alex.sharing.data.sentCopies.first?.statusRecord == nil)

        await open(riley, at: 8, 35, alex: alex)
        try riley.sharing.change(ConnectionChoices(sharesStatus: true), for: connectionID)
        await settle(alex, riley)
        #expect(try row(on: alex).trailing == .status(.nudging))
    }

    @Test func turningStatusSharingOffAfterARelaunchStillDeletesWhatTheSenderSaw() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        riley.relaunch()
        await riley.launch()

        try riley.sharing.change(ConnectionChoices(sharesStatus: false), for: connectionID)
        await settle(alex, riley)

        #expect(alex.sharing.data.sentCopies.first?.statusRecord == nil)
        #expect(try row(on: alex).trailing == .delivered)
    }

    // MARK: Don't share this one

    @Test func dontShareThisOneHoldsTheStatusBackAndSharingItAgainShowsIt() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        try riley.model.setNotSharing(true, for: try copy(on: riley).id)
        await open(riley, at: 8, 35, alex: alex)

        let held = try row(on: alex)
        #expect(held.trailing == .delivered)
        #expect(String(localized: try #require(held.detailLine)) == "Not sharing this one")
        // Only the flag left Riley's iPhone: no status went with it.
        let record = try #require(alex.sharing.data.sentCopies.first?.statusRecord)
        #expect(record.notSharingThisOne)
        #expect(record.report.occurrences.isEmpty)

        try riley.model.setNotSharing(false, for: try copy(on: riley).id)
        await settle(alex, riley)
        #expect(try row(on: alex).trailing == .status(.nudging))
    }

    @Test func dontShareThisOneChangesNothingWhileStatusSharingIsOff() async throws {
        let (alex, riley) = try await phones(sharesStatus: false)
        try await send(pills, from: alex, to: riley)

        try riley.model.setNotSharing(true, for: try copy(on: riley).id)
        await settle(alex, riley)

        #expect(statusReports(from: riley).isEmpty)
        #expect(String(localized: try #require(try row(on: alex).detailLine)) == "Not sharing status")
    }

    // MARK: Remove

    @Test func removingACopyWithStatusSharingOnShowsTheSenderRemoved() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        riley.model.delete(try copy(on: riley).id)
        await settle(alex, riley)

        let row = try row(on: alex)
        #expect(row.trailing == .status(.removed))
        #expect(String(localized: try #require(row.detailLine)) == "Delivered")
        #expect(String(localized: row.voiceOverLabel) == "Riley Park, Take the pills, Removed, Today, 8:30\u{202F}AM")
    }

    @Test func removingAWaitingCopyShowsTheSenderRemovedNotWaiting() async throws {
        let (alex, riley) = try await phones(deliveryMode: .askMeFirst)
        try await send(pills, from: alex, to: riley)
        #expect(try row(on: alex).trailing == .delivered)
        #expect(String(localized: try #require(try row(on: alex).detailLine)) == "Waiting for them to accept")

        riley.model.delete(try copy(on: riley).id)
        await settle(alex, riley)

        #expect(try row(on: alex).trailing == .status(.removed))
    }

    @Test func removingACopyWithStatusSharingOffTellsTheSenderNothing() async throws {
        let (alex, riley) = try await phones(sharesStatus: false)
        try await send(pills, from: alex, to: riley)

        riley.model.delete(try copy(on: riley).id)
        await settle(alex, riley)

        #expect(statusReports(from: riley).isEmpty)
        #expect(try row(on: alex).trailing == .delivered)
    }

    @Test func removingACopyKeptFromTheSenderStillReadsNotSharingThisOne() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        try riley.model.setNotSharing(true, for: try copy(on: riley).id)

        riley.model.delete(try copy(on: riley).id)
        await settle(alex, riley)

        let row = try row(on: alex)
        #expect(row.trailing == .delivered)
        #expect(String(localized: try #require(row.detailLine)) == "Not sharing this one")
    }

    @Test func removingACopyTheSenderCanceledSendsNoReport() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        try alex.model.deleteSent(pills.id)
        await settle(alex, riley)
        let before = statusReports(from: riley).count

        riley.model.delete(try copy(on: riley).id)
        await settle(alex, riley)

        #expect(statusReports(from: riley).count == before)
    }

    @Test func aCanceledCopyReportsNothingNew() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        let before = statusReports(from: riley).count

        try alex.model.deleteSent(pills.id)
        await open(riley, at: 8, 35, alex: alex)

        #expect(statusReports(from: riley).count == before)
    }

    // MARK: Accepting

    @Test func acceptingACopyThatWaitedShowsTheSenderItsStatus() async throws {
        let (alex, riley) = try await phones(deliveryMode: .askMeFirst)
        try await send(pills, from: alex, to: riley)

        riley.model.accept(try copy(on: riley).id)
        await settle(alex, riley)

        #expect(try row(on: alex).trailing == .status(.comingUp))
    }

    // MARK: Sent reminder's details

    @Test func theDetailsListEachRecipientsStatusAsTheRowDoes() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        await open(riley, at: 8, 35, alex: alex)

        let details = try #require(SentReminderDetails(engine: alex.model.engine, sharing: alex.sharing.data, id: pills.id))
        let recipient = try #require(details.recipients.first)

        #expect(recipient.trailing == .status(.nudging))
        #expect(String(localized: try #require(recipient.detailLine)) == "Delivered")

        try riley.sharing.change(ConnectionChoices(sharesStatus: false), for: connectionID)
        await settle(alex, riley)
        let hidden = try #require(SentReminderDetails(engine: alex.model.engine, sharing: alex.sharing.data, id: pills.id)?.recipients.first)
        #expect(hidden.trailing == .delivered)
        #expect(String(localized: try #require(hidden.detailLine)) == "Not sharing status")
    }
}
