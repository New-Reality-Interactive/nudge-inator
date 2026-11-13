import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Offline and Waiting to sync (ticket 211, spec #127 seam 1): Alex and Riley, connected through the
/// fake network, one of them offline and then back. What a test asserts is what each person sees
/// (Sent's rows, a received copy's From line, the reminders that nudge) and what each app model and
/// sharing store keeps. Layout, landscape, the largest text size and VoiceOver are the phone check.
@MainActor
struct OfflineTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let connectionID = UUID()

    /// Due at 8:30 every day, Firm: the phones' clocks say 8:00 on 15 October.
    let pills = Reminder(
        title: "Take the pills",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .firm
    )

    /// Alex and Riley, connected, launched and joined by the network, Riley sharing status.
    func phones() async throws -> (alex: Phone, riley: Phone) {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Riley Park", state: .connected),
        ]))
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Alex Morgan", state: .connected),
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

    func setOnline(_ isOnline: Bool, _ phone: Phone, settling phones: Phone...) async {
        phone.adapter.isOnline = isOnline
        for phone in phones { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in phones { await phone.model.waitUntilApplied() }
    }

    func row(on alex: Phone) throws -> SentScreen.Row {
        let screen = SentScreen(engine: alex.model.engine, sharing: alex.sharing.data)
        return try #require(screen.people.first?.rows.first)
    }

    // MARK: Waiting to sync on Sent

    @Test func aSendMadeOfflineWaitsToSyncUntilTheIPhoneIsBack() async throws {
        let (alex, riley) = try await phones()
        await setOnline(false, alex, settling: alex, riley)

        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)

        let waiting = try row(on: alex)
        #expect(waiting.trailing == .waitingToSync)
        #expect(String(localized: try #require(waiting.detailLine)) == "Not delivered yet")
        #expect(String(localized: waiting.voiceOverLabel) == "Riley Park, Take the pills, Waiting to sync, Not delivered yet, Today, 8:30\u{202F}AM")
        #expect(riley.model.engine.reminders.isEmpty)

        await setOnline(true, alex, settling: alex, riley)

        let synced = try row(on: alex)
        #expect(synced.trailing == .status(.comingUp))
        #expect(alex.sharing.data.outbox.isEmpty)
        #expect(riley.model.engine.reminders.map(\.title) == ["Take the pills"])
    }

    @Test func aRevisionMadeOfflineWaitsToSyncOnADeliveredCopyWithNoHistory() async throws {
        let (alex, riley) = try await phones()
        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)
        #expect(try row(on: alex).history != nil)

        await setOnline(false, alex, settling: alex, riley)
        var edited = pills
        edited.title = "Take the vitamins"
        try alex.model.reviseSent(edited)

        let waiting = try row(on: alex)
        #expect(waiting.trailing == .waitingToSync)
        #expect(String(localized: try #require(waiting.detailLine)) == "Delivered")
        #expect(waiting.history == nil)
        #expect(String(localized: waiting.voiceOverLabel) == "Riley Park, Take the vitamins, Waiting to sync, Delivered, Today, 8:30\u{202F}AM")
    }

    // MARK: Waiting to sync on a received copy

    func copy(on riley: Phone) throws -> Reminder {
        try #require(riley.model.engine.reminders.first { $0.isReceived })
    }

    @Test func aStatusMadeOfflineWaitsToSyncOnTheCopyUntilTheIPhoneIsBack() async throws {
        let (alex, riley) = try await phones()
        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)
        let received = try copy(on: riley)
        #expect(riley.model.senders.fromLine(of: received)?.waitsToSync == false)

        await setOnline(false, riley, settling: alex, riley)
        riley.model.pause(received.id)
        await settle(alex, riley)

        let waiting = try #require(RemindersScreen(engine: riley.model.engine, senders: riley.model.senders).rows.first)
        #expect(waiting.from?.waitsToSync == true)
        #expect(String(localized: try #require(waiting.from).label) == "From Alex Morgan")
        #expect(try row(on: alex).trailing == .status(.comingUp))

        await setOnline(true, riley, settling: alex, riley)

        #expect(riley.model.senders.fromLine(of: try copy(on: riley))?.waitsToSync == false)
        #expect(try row(on: alex).trailing == .status(.paused))
        #expect(riley.sharing.data.outbox.isEmpty)
    }

    // MARK: Nothing made offline is lost or sent twice

    /// Due at 9:00 today, once, Gentle.
    let call = Reminder(title: "Call the clinic", dueTime: NewYork.local(2026, 10, 15, 9, 0), strength: .gentle)

    @Test func doneMadeOfflineWaitsToSyncOnTheCopyAndReachesTheSenderWhenBack() async throws {
        let (alex, riley) = try await phones()
        try alex.model.send(call, to: [connectionID])
        await settle(alex, riley)
        riley.clock.now = NewYork.local(2026, 10, 15, 9, 5)
        await riley.model.appOpened()
        await settle(alex, riley)
        #expect(try row(on: alex).trailing == .status(.nudging))

        await setOnline(false, riley, settling: alex, riley)
        let received = try copy(on: riley)
        riley.model.markDone(received.id)
        await settle(alex, riley)

        let card = try #require(NowScreen(engine: riley.model.engine, senders: riley.model.senders).lastDay.first { $0.title == "Call the clinic" })
        #expect(card.from?.waitsToSync == true)
        #expect(card.from?.spoken == "From Alex Morgan, Waiting to sync")
        #expect(try row(on: alex).trailing == .status(.nudging))

        await setOnline(true, riley, settling: alex, riley)

        #expect(try row(on: alex).trailing == .status(.done))
        #expect(riley.model.senders.fromLine(of: try copy(on: riley))?.waitsToSync == false)
    }

    @Test func aSendersEditsAndDeletesMadeOfflineArriveOnceEachWhenTheIPhoneIsBack() async throws {
        let (alex, riley) = try await phones()
        await setOnline(false, alex, settling: alex, riley)

        try alex.model.send(pills, to: [connectionID])
        try alex.model.send(call, to: [connectionID])
        var edited = pills
        edited.title = "Take the vitamins"
        try alex.model.reviseSent(edited)
        try alex.model.deleteSent(call.id)
        await settle(alex, riley)
        #expect(alex.sharing.data.outbox.map(\.kind) == [.send, .send, .revise, .cancel])

        await setOnline(true, alex, settling: alex, riley)

        let copies = riley.model.engine.reminders.filter(\.isReceived)
        #expect(copies.map(\.title).sorted() == ["Call the clinic", "Take the vitamins"])
        #expect(copies.first { $0.title == "Call the clinic" }?.isCanceled == true)
        #expect(alex.sharing.data.outbox.isEmpty)
        #expect(alex.adapter.submitted.count == 4)
        // Each copy's receipt came back once.
        #expect(riley.adapter.submitted.filter { $0.kind == .receipt }.count == 2)
    }

    @Test func theOutboxKeptAcrossARelaunchOfflineIsSentOnce() async throws {
        let (alex, riley) = try await phones()
        await setOnline(false, alex, settling: alex, riley)
        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)

        alex.relaunch()
        await alex.launch()
        #expect(alex.sharing.data.outbox.map(\.kind) == [.send])
        #expect(try row(on: alex).trailing == .waitingToSync)

        await setOnline(true, alex, settling: alex, riley)

        #expect(alex.adapter.submitted.count == 1)
        #expect(riley.model.engine.reminders.map(\.title) == ["Take the pills"])
        #expect(alex.sharing.data.outbox.isEmpty)
        #expect(try row(on: alex).trailing == .status(.comingUp))
    }

    @Test func aRecipientsPauseRemoveAndSettingsMadeOfflineReachTheSenderWhenBack() async throws {
        let (alex, riley) = try await phones()
        try alex.model.send(pills, to: [connectionID])
        try alex.model.send(call, to: [connectionID])
        await settle(alex, riley)
        let pillsCopy = try #require(riley.model.engine.reminders.first { $0.title == "Take the pills" })
        let callCopy = try #require(riley.model.engine.reminders.first { $0.title == "Call the clinic" })

        await setOnline(false, riley, settling: alex, riley)
        riley.model.pause(pillsCopy.id)
        riley.model.delete(callCopy.id)
        try riley.sharing.change(ConnectionChoices(sharesStatus: true, deliveryMode: .askMeFirst), for: connectionID)
        await settle(alex, riley)
        #expect(alex.sharing.data.connections.first?.theirs.deliveryMode == .startRightAway)

        await setOnline(true, riley, settling: alex, riley)

        let screen = SentScreen(engine: alex.model.engine, sharing: alex.sharing.data)
        let trailing = Dictionary(uniqueKeysWithValues: (screen.people.first?.rows ?? []).map { ($0.title, $0.trailing) })
        #expect(trailing == ["Take the pills": .status(.paused), "Call the clinic": .status(.removed)])
        #expect(alex.sharing.data.connections.first?.theirs.deliveryMode == .askMeFirst)
        #expect(riley.sharing.data.outbox.isEmpty)
    }

    // MARK: Received reminders keep nudging

    @Test func aReceivedReminderKeepsItsNudgesOffline() async throws {
        let (alex, riley) = try await phones()
        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)
        let pending = riley.center.pending.map(\.identifier)
        #expect(!pending.isEmpty)
        // Firm rings alarms from nudge 4.
        let alarms = riley.manager.scheduled.map(\.id)
        #expect(!alarms.isEmpty)

        await setOnline(false, riley, settling: alex, riley)
        riley.clock.now = NewYork.local(2026, 10, 15, 8, 20)
        await riley.model.appOpened()
        await settle(alex, riley)

        #expect(riley.center.pending.map(\.identifier) == pending)
        #expect(riley.manager.scheduled.map(\.id) == alarms)
        #expect(riley.model.engine.reminders.first { $0.isReceived }?.title == "Take the pills")
    }

    // MARK: Reordered and dropped changes

    // iCloud keeps one record for a sent reminder (a cancel is a flag on it), one for a receipt and
    // one for a status, and a fetch reads each record's latest state, so an earlier state of a record
    // never follows a later one. The fake's changes can; these tests reorder only what iCloud can:
    // changes in different records, and a send and its revision, where a fetch can find only the
    // revision.

    @Test func aStatusThatArrivesAheadOfItsReceiptLeavesTheRowAsInOrder() async throws {
        let (alex, riley) = try await phones()
        network.holdsDeliveries = true
        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)
        network.deliverAll()
        await settle(alex, riley)
        #expect(network.inFlight.map(\.change.kind) == [.receipt, .status])

        network.move(from: 1, to: 0)
        network.holdsDeliveries = false
        await settle(alex, riley)

        let row = try row(on: alex)
        #expect(row.trailing == .status(.comingUp))
        #expect(String(localized: try #require(row.detailLine)) == "Delivered")
    }

    @Test func aRevisionThatArrivesAheadOfItsSendKeepsTheRevision() async throws {
        let (alex, riley) = try await phones()
        network.holdsDeliveries = true
        try alex.model.send(pills, to: [connectionID])
        var edited = pills
        edited.title = "Take the vitamins"
        try alex.model.reviseSent(edited)
        await settle(alex, riley)
        #expect(network.inFlight.map(\.change.kind) == [.send, .revise])

        network.move(from: 1, to: 0)
        network.holdsDeliveries = false
        await settle(alex, riley)

        #expect(riley.model.engine.reminders.filter(\.isReceived).map(\.title) == ["Take the vitamins"])
        #expect(try row(on: alex).trailing == .status(.comingUp))
    }

    @Test func aDroppedRevisionIsPutRightByTheNextOne() async throws {
        let (alex, riley) = try await phones()
        try alex.model.send(pills, to: [connectionID])
        await settle(alex, riley)

        network.holdsDeliveries = true
        var edited = pills
        edited.title = "Take the vitamins"
        try alex.model.reviseSent(edited)
        await settle(alex, riley)
        network.drop(at: 0)
        edited.strength = .relentless
        try alex.model.reviseSent(edited)
        network.holdsDeliveries = false
        await settle(alex, riley)

        let received = try copy(on: riley)
        #expect(received.title == "Take the vitamins")
        #expect(received.strength == .relentless)
        #expect(alex.sharing.data.outbox.isEmpty)
    }

    // MARK: The offline banner

    @Test func offlineTheBannerSaysSoAndBackOnlineItGoes() async throws {
        let (alex, riley) = try await phones()
        #expect(alex.sharing.banner == nil)

        await setOnline(false, alex, settling: alex, riley)
        #expect(alex.sharing.banner == .offline)
        #expect(String(localized: SharingBanner.offline.text) == "**You're offline.** Reminders you've received keep nudging. What you send or change goes when you're back online.")
        #expect(SharingBanner.offline.systemImage == "wifi.slash")
        #expect(!SharingBanner.offline.offersOpenSettings)
        #expect(riley.sharing.banner == nil)

        await setOnline(true, alex, settling: alex, riley)
        #expect(alex.sharing.banner == nil)
    }

    @Test func pausedSharingIsSaidOverOffline() async throws {
        let (alex, riley) = try await phones()
        await setOnline(false, alex, settling: alex, riley)
        alex.adapter.account = .noAccount
        await alex.model.waitUntilApplied()

        #expect(alex.sharing.banner == .paused(.noAccount))
        #expect(SharingBanner.paused(.noAccount).systemImage == "icloud.slash")
    }

    @Test func anIPhoneOfflineAtLaunchShowsTheBanner() async throws {
        let (alex, _) = try await phones()
        alex.adapter.isOnline = false
        alex.relaunch()
        await alex.launch()

        #expect(alex.sharing.banner == .offline)
    }

    @Test func offlineASendStillGoesIntoTheOutbox() async throws {
        let (alex, riley) = try await phones()
        await setOnline(false, alex, settling: alex, riley)

        try alex.model.send(pills, to: [connectionID])

        #expect(alex.sharing.pause == nil)
        #expect(alex.sharing.data.outbox.map(\.kind) == [.send])
    }
}
