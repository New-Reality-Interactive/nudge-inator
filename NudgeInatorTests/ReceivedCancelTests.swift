import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The sender's Delete reaching a received copy (ticket 205, spec #127 seam 1): Alex sends Riley a
/// reminder and deletes it with `deleteSent`, and the tests read Riley's copy, details, badges,
/// notifications, alarms and Disconnect as Riley's app model builds them. Layout and VoiceOver are
/// the phone check.
@MainActor
struct ReceivedCancelTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let connectionID = UUID()

    /// Relentless, due at 8:30 every day, so it rings as alarms: the phones' clocks say 8:00 on 15 October.
    let pills = Reminder(
        title: "Take the pills",
        notes: "Two with water.",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .relentless
    )

    /// Alex and Riley, connected, Riley's Delivery mode `rileysMode`.
    func phones(rileysMode: DeliveryMode = .startRightAway) async throws -> (alex: Phone, riley: Phone) {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Riley Park", state: .connected, theirs: ConnectionChoices(deliveryMode: rileysMode)),
        ]))
        let riley = try Phone(seed: SharingData(connections: [
            SharingConnection(id: connectionID, name: "Alex Morgan", state: .connected, mine: ConnectionChoices(deliveryMode: rileysMode)),
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

    /// Alex deletes the sent reminder, and both phones settle.
    func delete(_ reminder: Reminder, from alex: Phone, to riley: Phone) async throws {
        try alex.model.deleteSent(reminder.id)
        await settle(alex, riley)
    }

    func copy(on riley: Phone) throws -> Reminder {
        try #require(riley.model.engine.reminders.first { $0.isReceived })
    }

    func open(_ riley: Phone, at hour: Int, _ minute: Int) async {
        riley.clock.now = NewYork.local(2026, 10, 15, hour, minute)
        await riley.model.appOpened()
        await riley.model.waitUntilApplied()
    }

    func details(on riley: Phone) throws -> ReminderDetails {
        try #require(ReminderDetails(engine: riley.model.engine, id: copy(on: riley).id, sharing: riley.sharing.data))
    }

    // MARK: The copy

    @Test func aDeleteByTheSenderCancelsTheCopyAndItsNudgesAndAlarms() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        #expect(!riley.manager.scheduled.isEmpty)

        try await delete(pills, from: alex, to: riley)

        let held = try copy(on: riley)
        #expect(held.isCanceled)
        #expect(riley.model.engine.status(of: held.id) == .canceled)
        #expect(riley.center.pending.isEmpty)
        #expect(riley.manager.scheduled.isEmpty)
    }

    @Test func aRingingAlarmStopsWhenTheCopyIsCanceled() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        await open(riley, at: 8, 35)
        let ringing = try #require(riley.manager.scheduled.first)
        riley.manager.ring(ringing.id)

        try await delete(pills, from: alex, to: riley)

        #expect(riley.manager.stoppedIDs.contains(ringing.id))
        #expect(riley.manager.scheduled.isEmpty)
    }

    @Test func aNudgingCopyLeavesTheNowBadgeAndTheIconBadge() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        await open(riley, at: 8, 35)
        #expect(riley.model.engine.badgeCount == 1)

        try await delete(pills, from: alex, to: riley)

        #expect(riley.model.engine.badgeCount == 0)
        #expect(riley.model.engine.nudgingOccurrences().isEmpty)
        #expect(riley.center.badgeCounts.last == 0)
    }

    @Test func aWaitingCopyIsCanceledToo() async throws {
        let (alex, riley) = try await phones(rileysMode: .askMeFirst)
        try await send(pills, from: alex, to: riley)
        #expect(try copy(on: riley).isWaiting)

        try await delete(pills, from: alex, to: riley)

        let held = try copy(on: riley)
        #expect(held.isCanceled)
        #expect(!held.isWaiting)
        #expect(riley.model.engine.waitingForAcceptance().isEmpty)
    }

    @Test func theCanceledCopyStaysUntilTheRecipientRemovesIt() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        try await delete(pills, from: alex, to: riley)
        await open(riley, at: 9, 0)
        #expect(try copy(on: riley).isCanceled)

        riley.model.delete(try copy(on: riley).id)
        await riley.model.waitUntilApplied()

        #expect(riley.model.engine.reminders.isEmpty)
        #expect(riley.sharing.data.receivedSyncStates.isEmpty)
    }

    @Test func theCanceledStateSurvivesARelaunch() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        try await delete(pills, from: alex, to: riley)

        riley.relaunch()
        await riley.launch()

        #expect(try copy(on: riley).isCanceled)
        #expect(riley.center.pending.isEmpty)
        #expect(riley.manager.scheduled.isEmpty)
    }

    @Test func aCancelForACopyNotHeldOrDeliveredAgainChangesNothing() async throws {
        let (alex, riley) = try await phones()
        try await riley.sharing.received(.cancel(UUID(), for: connectionID))
        #expect(riley.model.engine.reminders.isEmpty)

        try await send(pills, from: alex, to: riley)
        try await delete(pills, from: alex, to: riley)
        let cancel = try #require(alex.adapter.submitted.first { $0.kind == .cancel })
        let held = try copy(on: riley)

        try await riley.sharing.received(cancel)
        await settle(riley)

        #expect(try copy(on: riley) == held)
    }

    @Test func aLateRevisionOfACanceledCopyChangesNothing() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        try alex.model.reviseSent({ var edited = pills; edited.title = "Take the blue pills"; return edited }())
        await settle(alex, riley)
        let revision = try #require(alex.adapter.submitted.first { $0.kind == .revise })
        try await delete(pills, from: alex, to: riley)
        let canceled = try copy(on: riley)

        try await riley.sharing.received(revision)
        await settle(riley)

        #expect(try copy(on: riley) == canceled)
    }

    @Test func aCancelThroughAConnectionThatIsntConnectedChangesNothing() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        let held = try copy(on: riley)

        try await riley.sharing.received(.cancel(pills.id, for: UUID()))

        #expect(try copy(on: riley) == held)
    }

    // MARK: The details

    @Test func theDetailsOfACanceledCopySayCanceledAndOfferOnlyRemove() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        try await delete(pills, from: alex, to: riley)

        let shown = try details(on: riley)

        #expect(shown.status == .canceled)
        #expect(shown.isCanceled)
        #expect(shown.pauseAction == nil)
        #expect(shown.next == .none)
        #expect(shown.card == nil)
        #expect(shown.received?.senderName == "Alex Morgan")
    }

    // MARK: Disconnect

    @Test(arguments: [DisconnectChoice.remove, .keepAsMyOwnReminders])
    func aCanceledCopyGoesWhicheverIsChosenAndIsNotCounted(choice: DisconnectChoice) async throws {
        let (alex, riley) = try await phones()
        let other = Reminder(title: "Call Mum", dueTime: NewYork.local(2026, 10, 15, 9), strength: .relentless)
        try await send(pills, from: alex, to: riley)
        try await send(other, from: alex, to: riley)
        try await delete(pills, from: alex, to: riley)
        #expect(riley.model.engine.keptOnDisconnect(from: connectionID) == 1)

        try riley.model.disconnect(connectionID, choosing: choice)
        await settle(riley)

        let remaining = riley.model.engine.reminders
        #expect(remaining.allSatisfy { !$0.isCanceled })
        #expect(remaining.map(\.title) == (choice == .remove ? [] : ["Call Mum"]))
        // Neither is received any more: Keep makes the other personal.
        #expect(riley.sharing.data.receivedSyncStates.isEmpty)
        #expect(riley.center.pending.allSatisfy { !$0.identifier.contains(pills.id.uuidString) })
    }

    @Test func aCanceledCopyAloneLeavesNothingToKeepOnTheEndedConnection() async throws {
        let (alex, riley) = try await phones()
        try await send(pills, from: alex, to: riley)
        try await delete(pills, from: alex, to: riley)
        try alex.model.disconnect(connectionID, choosing: .remove)
        await settle(alex, riley)
        #expect(riley.sharing.endedConnection?.id == connectionID)
        #expect(riley.model.engine.keptOnDisconnect(from: connectionID) == 0)

        try riley.model.disconnect(connectionID, choosing: .keepAsMyOwnReminders)
        await settle(riley)

        #expect(riley.model.engine.reminders.isEmpty)
        #expect(riley.manager.scheduled.isEmpty)
        #expect(riley.center.pending.isEmpty)
    }
}
