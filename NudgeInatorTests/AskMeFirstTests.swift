import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Ask me first (ticket 203, spec #127 seam 1): Riley's Delivery mode with Alex is Ask me first, so
/// what Alex sends waits on Riley's phone until Riley accepts or removes it. The tests read both
/// sides as their app models and sharing stores build them. Layout and VoiceOver are the phone check.
@MainActor
struct AskMeFirstTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let connectionID = UUID()

    /// Due at 8:30 every day, Firm: the phones' clocks say 8:00.
    let pills = Reminder(
        title: "Take the pills",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .firm
    )
    /// Due at 9:00 today, once, Gentle.
    let call = Reminder(title: "Call the clinic", dueTime: NewYork.local(2026, 10, 15, 9, 0), strength: .gentle)
    /// Riley's own, due at 8:15 every day.
    let walk = Reminder(title: "Walk the dog", dueTime: NewYork.local(2026, 10, 15, 8, 15), repeatRule: .everyDay, strength: .gentle)

    /// Alex and Riley, connected, Riley's Delivery mode `rileysMode`, at 8:00 on 15 October.
    func phones(rileysMode: DeliveryMode = .askMeFirst) async throws -> (alex: Phone, riley: Phone) {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Riley Park", state: .connected, theirs: ConnectionChoices(deliveryMode: rileysMode)),
        ]))
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Alex Morgan", state: .connected, mine: ConnectionChoices(deliveryMode: rileysMode)),
        ]))
        network.join(alex.adapter, riley.adapter, through: connectionID)
        for phone in [alex, riley] { await phone.launch() }
        riley.model.add(walk)
        return (alex, riley)
    }

    /// Alex sends `reminder` to Riley, and it arrives.
    func send(_ reminder: Reminder, from alex: Phone, to riley: Phone) async throws {
        try alex.model.send(reminder, to: [connectionID])
        await settle(alex, riley)
    }

    func settle(_ phones: Phone...) async {
        for phone in phones { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in phones { await phone.model.waitUntilApplied() }
    }

    /// Riley's phone at `hour`:`minute` on 15 October.
    func open(_ riley: Phone, at hour: Int, _ minute: Int) async {
        riley.clock.now = NewYork.local(2026, 10, 15, hour, minute)
        await riley.model.appOpened()
        await riley.model.waitUntilApplied()
    }

    func copy(on riley: Phone) throws -> Reminder {
        try #require(riley.model.engine.reminders.first { $0.isReceived })
    }

    func now(on riley: Phone) -> NowScreen {
        NowScreen(engine: riley.model.engine, senders: riley.model.senders)
    }

    // MARK: Waiting for You on Now

    @Test func aWaitingReminderIsUnderWaitingForYouAndNudgesForNothing() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        await open(riley, at: 8, 40)

        let screen = now(on: riley)

        let row = try #require(screen.waiting.first)
        #expect(screen.waiting.count == 1)
        #expect(row.title == "Take the pills")
        #expect(row.from.map { String(localized: $0.label) } == "From Alex Morgan")
        #expect(row.day == "Tomorrow")
        #expect(row.time == "8:30\u{202F}AM")
        #expect(screen.nudging.map(\.title) == ["Walk the dog"])
        #expect(!screen.comingUp.contains { $0.title == "Take the pills" })
        #expect(NowScreen.badgeCount(of: riley.model.engine) == 1)
        #expect(riley.center.badgeCounts.last == 1)
    }

    @Test func aReminderThatStartedRightAwayIsNeverWaiting() async throws {
        let (alex, riley) = try await phones(rileysMode: .startRightAway)
        try await send(pills, from: alex, to: riley)
        await open(riley, at: 8, 40)

        let screen = now(on: riley)

        #expect(screen.waiting.isEmpty)
        #expect(Set(screen.nudging.map(\.title)) == ["Take the pills", "Walk the dog"])
    }

    // MARK: Accept

    /// Accepted at 9:10, after its 9:00 due time: it starts nudging at once (spec #127, A9).
    @Test func aOneOffAcceptedAfterItsDueTimeStartsNudgingAtOnce() async throws {
        let (alex, riley) = try await phones()
        try await send(call, from: alex, to: riley)
        await open(riley, at: 9, 10)

        riley.model.accept(try copy(on: riley).id)
        await riley.model.waitUntilApplied()

        let screen = now(on: riley)
        #expect(screen.waiting.isEmpty)
        #expect(screen.nudging.map(\.title).contains("Call the clinic"))
        #expect(NowScreen.badgeCount(of: riley.model.engine) == 2)
    }

    /// Accepted at 8:40: this morning's 8:30 fell due while it waited, so it stays Skipped and it
    /// starts tomorrow at 8:30.
    @Test func aRepeatingReminderAcceptedStartsAtItsNextDueTime() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        await open(riley, at: 8, 40)
        let copy = try copy(on: riley)

        riley.model.accept(copy.id)
        await riley.model.waitUntilApplied()

        let engine = riley.model.engine
        #expect(engine.status(of: copy.id) == .comingUp)
        #expect(engine.occurrence(of: copy.id, dueAt: NewYork.local(2026, 10, 15, 8, 30))?.state == .skipped(reason: .paused))
        #expect(now(on: riley).comingUp.first { $0.title == "Take the pills" }?.day == "Tomorrow")
    }

    @Test func acceptingTellsTheSenderItStarted() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        #expect(sentRow(on: alex)?.delivery == .waitingForAcceptance)

        riley.model.accept(try copy(on: riley).id)
        await settle(alex, riley)

        #expect(sentRow(on: alex)?.delivery == .delivered)
    }

    /// Accept on a reminder of Riley's own, or one already accepted, sends nothing.
    @Test func acceptingWhatIsntWaitingSendsNothing() async throws {
        let (alex, riley) = try await phones(rileysMode: .startRightAway)
        try await send(pills, from: alex, to: riley)
        let sentBefore = riley.adapter.submitted.count

        riley.model.accept(try copy(on: riley).id)
        riley.model.accept(walk.id)
        await settle(alex, riley)

        #expect(riley.adapter.submitted.count == sentBefore)
    }

    // MARK: Remove

    /// The same Remove as a started copy's (#200), so the sender learns of it as of that one (#189's
    /// comment on this ticket).
    @Test func removingAWaitingReminderRemovesItAndItsSyncState() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        let copy = try copy(on: riley)

        riley.model.delete(copy.id)
        await riley.model.waitUntilApplied()

        #expect(now(on: riley).waiting.isEmpty)
        #expect(!riley.model.engine.reminders.contains { $0.id == copy.id })
        #expect(riley.sharing.data.receivedSyncStates.isEmpty)
    }

    // MARK: The details

    @Test func aWaitingReminderDetailsOfferAcceptAndRemoveButNotPause() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        await open(riley, at: 8, 10)
        let copy = try copy(on: riley)

        let details = try #require(ReminderDetails(engine: riley.model.engine, id: copy.id, sharing: riley.sharing.data))

        #expect(details.status == .waiting)
        #expect(details.isWaiting)
        #expect(details.pauseAction == nil)
        #expect(details.next == .at(day: "Today", time: "8:30\u{202F}AM"))
    }

    @Test func anAcceptedReminderDetailsOfferPauseAndNoAccept() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        let copy = try copy(on: riley)
        riley.model.accept(copy.id)
        await riley.model.waitUntilApplied()

        let details = try #require(ReminderDetails(engine: riley.model.engine, id: copy.id, sharing: riley.sharing.data))

        #expect(!details.isWaiting)
        #expect(details.pauseAction == .pause)
    }

    // MARK: VoiceOver

    @Test func theWaitingRowsButtonsNameTheReminder() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        let row = try #require(now(on: riley).waiting.first)

        #expect(String(localized: row.acceptVoiceOverLabel) == "Accept: Take the pills")
        #expect(String(localized: row.removeVoiceOverLabel) == "Remove: Take the pills")
    }

    // MARK: The sender's Sent

    func sentScreen(on alex: Phone) -> SentScreen {
        SentScreen(engine: alex.model.engine, sharing: alex.sharing.data)
    }

    func sentRow(on alex: Phone) -> SentScreen.Row? {
        sentScreen(on: alex).people.first?.rows.first
    }

    @Test func theSenderSeesWaitingForThemToAccept() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)

        let row = try #require(sentRow(on: alex))
        let details = try #require(SentReminderDetails(engine: alex.model.engine, sharing: alex.sharing.data, id: row.reminderID))

        #expect(row.delivery == .waitingForAcceptance)
        #expect(row.detailLine.map { String(localized: $0) } == "Waiting for them to accept")
        #expect(row.isDelivered)
        #expect(String(localized: row.voiceOverLabel).contains("Waiting for them to accept"))
        #expect(details.recipients.first?.detailLine.map { String(localized: $0) } == "Waiting for them to accept")
    }

    /// Its status shows beside "Delivered" (ticket 206): a started copy never reads waiting.
    @Test func aStartedCopyReadsDeliveredAndNeverWaiting() async throws {
        let (alex, riley) = try await phones(rileysMode: .startRightAway)
        try await send(pills, from: alex, to: riley)

        let row = try #require(sentRow(on: alex))

        #expect(row.delivery == .delivered)
        #expect(row.detailLine.map { String(localized: $0) } == "Delivered")
    }

    /// Receipts can come out of order: a waiting receipt late after the started one doesn't put the
    /// row back to waiting.
    @Test func aLateWaitingReceiptDoesntUndoTheStartedOne() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        let reminderID = try #require(sentRow(on: alex)).reminderID

        try await alex.sharing.received(.receipt(.started, for: reminderID, from: connectionID))
        try await alex.sharing.received(.receipt(.waitingForAcceptance, for: reminderID, from: connectionID))

        #expect(sentRow(on: alex)?.delivery == .delivered)
    }
}
