import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Disconnect (ticket 197, spec #127 seam 1): two people connected through an accepted invite, one
/// ending the connection. What a test asserts is what each sharing store keeps, which reminders
/// each person's app model holds, and the alarms each phone has scheduled.
@MainActor
struct DisconnectTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()

    struct InviteNotSent: Error {}

    /// Alex invites Riley, and Riley accepts. Returns both phones and the connection's ID.
    func connected() async throws -> (alex: Phone, riley: Phone, id: UUID) {
        let alex = try Phone()
        let riley = try Phone()
        [alex, riley].forEach { network.add($0.adapter) }
        await alex.launch()
        await riley.launch()
        let id = try await invite(riley, from: alex)
        return (alex, riley, id)
    }

    /// `alex` invites Riley at her address, and she accepts. Returns the connection's ID.
    func invite(_ riley: Phone, from alex: Phone) async throws -> UUID {
        alex.adapter.inviteAnswer = .names(InvitedPerson(name: "Riley Park", address: "riley.park@icloud.com"))
        guard case .invited(let invited) = try await alex.sharing.invite() else { throw InviteNotSent() }
        network.share(invited.id, from: alex.adapter, senderName: "Alex Morgan", with: [riley.adapter])
        network.tapInvite(invited.id, on: riley.adapter)
        await network.settle()
        return invited.id
    }

    /// A Relentless reminder received through `connectionID`, due every day at 8:30, so its alarms
    /// are scheduled from the phones' 8:00.
    func received(through connectionID: UUID, state: ReminderOrigin.ReceivedState = .accepted) -> Reminder {
        Reminder(
            title: "Take the pills",
            dueTime: NewYork.local(2026, 10, 15, 8, 30),
            repeatRule: .everyDay,
            strength: .relentless,
            origin: .received(connectionID: connectionID, sendersReminderID: UUID(), revision: 1, state: state)
        )
    }

    /// The alarms the phone has scheduled. Each test phone holds one reminder, so they are its.
    func alarmIDs(on phone: Phone) -> Set<UUID> {
        Set(phone.manager.scheduled.map(\.id))
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NewYork.timeZone
        return calendar
    }

    func finish(_ phone: Phone) async {
        await phone.model.waitUntilApplied()
        await network.settle()
    }

    // MARK: Both ends

    @Test func disconnectingEndsTheConnectionAndTheOtherPersonsEndsOnceTheyChoose() async throws {
        let (alex, riley, id) = try await connected()

        try alex.model.disconnect(id, choosing: .remove)
        await finish(alex)

        #expect(alex.sharing.data.connections.isEmpty)
        #expect(riley.sharing.endedConnection?.id == id)
        #expect(riley.sharing.endedConnection?.name == "Alex Morgan")
        #expect(!riley.sharing.isConnected(id))

        try riley.model.disconnect(id, choosing: .remove)
        await finish(riley)

        #expect(riley.sharing.data.connections.isEmpty)
        #expect(riley.sharing.endedConnection == nil)
        // The connection had already ended, so Riley's app sends nothing back.
        #expect(!riley.adapter.submitted.contains { $0.kind == .disconnect })
    }

    @Test func theDisconnectGoesThroughTheOutboxLikeAnyChange() async throws {
        let (alex, _, id) = try await connected()
        alex.adapter.isOnline = false

        try alex.model.disconnect(id, choosing: .remove)
        await finish(alex)

        #expect(alex.sharing.data.outbox.map(\.kind) == [.disconnect])
        alex.adapter.isOnline = true
        await finish(alex)
        #expect(alex.sharing.data.outbox.isEmpty)
    }

    @Test func anEndedConnectionStillWaitsForTheChoiceAfterARelaunch() async throws {
        let (alex, riley, id) = try await connected()
        try alex.model.disconnect(id, choosing: .remove)
        await finish(alex)

        riley.relaunch()
        await riley.launch()

        #expect(riley.sharing.endedConnection?.id == id)
    }

    /// Neither can send to the other: neither lists the other as connected, and a new invite
    /// connects them again.
    @Test func afterADisconnectOnlyANewInviteConnectsThemAgain() async throws {
        let (alex, riley, id) = try await connected()
        try alex.model.disconnect(id, choosing: .remove)
        await finish(alex)
        try riley.model.disconnect(id, choosing: .remove)
        await finish(riley)

        #expect(alex.sharing.connectionsList(calendar: calendar).isEmpty)
        #expect(riley.sharing.connectionsList(calendar: calendar).isEmpty)

        let again = try await invite(riley, from: alex)

        #expect(again != id)
        #expect(alex.sharing.isConnected(again))
        #expect(riley.sharing.isConnected(again))
    }

    // MARK: What was received

    @Test func removeDeletesWhatWasReceivedAndCancelsItsAlarms() async throws {
        let (alex, riley, id) = try await connected()
        let copy = received(through: id)
        riley.model.add(copy)
        await riley.model.waitUntilApplied()
        #expect(!alarmIDs(on: riley).isEmpty)

        try alex.model.disconnect(id, choosing: .remove)
        await finish(alex)
        try riley.model.disconnect(id, choosing: .remove)
        await finish(riley)

        #expect(riley.model.engine.reminders.isEmpty)
        #expect(alarmIDs(on: riley).isEmpty)
        riley.relaunch()
        await riley.launch()
        #expect(riley.model.engine.reminders.isEmpty)
    }

    /// Nothing re-plans: the kept reminder's alarms keep their identifiers.
    @Test func keepMakesWhatWasReceivedThePersonsOwnWithItsAlarmsAsTheyWere() async throws {
        let (alex, _, id) = try await connected()
        let copy = received(through: id)
        alex.model.add(copy)
        await alex.model.waitUntilApplied()
        let alarms = alarmIDs(on: alex)
        #expect(!alarms.isEmpty)

        try alex.model.disconnect(id, choosing: .keepAsMyOwnReminders)
        await finish(alex)

        #expect(alex.model.engine.reminders.first { $0.id == copy.id }?.origin == .mine)
        #expect(alarmIDs(on: alex) == alarms)
        alex.relaunch()
        await alex.launch()
        #expect(alex.model.engine.reminders.first { $0.id == copy.id }?.origin == .mine)
        #expect(alex.model.engine.reminders.first { $0.id == copy.id }?.title == "Take the pills")
    }

    @Test func keepDeletesACopyStillWaitingWithNothingLeftBehind() async throws {
        let (alex, _, id) = try await connected()
        let waiting = received(through: id, state: .waiting)
        alex.model.add(waiting)
        await alex.model.waitUntilApplied()

        try alex.model.disconnect(id, choosing: .keepAsMyOwnReminders)
        await finish(alex)

        #expect(alex.model.engine.reminders.isEmpty)
        #expect(alarmIDs(on: alex).isEmpty)
    }

    // MARK: Failure

    @Test func aDisconnectTheSharingStoreCantKeepChangesNothing() async throws {
        let (alex, riley, id) = try await connected()
        let copy = received(through: id)
        alex.model.add(copy)
        alex.sharingStoreOpens = false
        alex.relaunch()
        await alex.launch()

        #expect(throws: Phone.StoreWouldNotOpen.self) {
            try alex.model.disconnect(id, choosing: .remove)
        }
        await finish(alex)

        #expect(alex.model.engine.reminders.first { $0.id == copy.id }?.origin == copy.origin)
        #expect(!alarmIDs(on: alex).isEmpty)
        #expect(riley.sharing.isConnected(id))
    }
}
