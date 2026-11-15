import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Delete All Data covers sharing (ticket 214, spec #127 Privacy and compliance): Alex and Riley,
/// connected through the fake network, and Riley deleting all data, which turns Sharing off (#388).
/// What a test asserts is what Riley's app model, both stores and alarms keep, and what reaches
/// Alex. Wording, layout and the largest text size are the phone check.
@MainActor
struct DeleteAllDataSharingTests {
    typealias Phone = TurnOffSharingTests.Phone

    let network = FakeSharingNetwork()
    let connectionID = UUID()

    let pills = Reminder(
        title: "Take the pills",
        dueTime: NewYork.local(2026, 10, 15, 8, 30),
        repeatRule: .everyDay,
        strength: .relentless
    )

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

    func received(_ title: String = "Water the plants") -> Reminder {
        Reminder(
            title: title,
            dueTime: NewYork.local(2026, 10, 15, 9),
            repeatRule: .everyDay,
            strength: .relentless,
            origin: .received(connectionID: connectionID, sendersReminderID: UUID(), revision: 0, state: .accepted)
        )
    }

    func settle(_ phones: Phone...) async {
        for phone in phones { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in phones { await phone.model.waitUntilApplied() }
    }

    /// #396: what happened to sharing is part of what Delete All Data removes.
    @Test func deleteAllDataClearsTheShareActivityRecord() async throws {
        let (alex, riley) = try await phones()
        try await riley.sharing.received(.connectionLost(connectionID))
        #expect(riley.sharing.data.activity.count == 1)
        await settle(alex, riley)

        try await riley.model.deleteAllData()
        await settle(alex, riley)

        // Sharing is off now, so no model shows it: the store is read from its file.
        #expect(try riley.keptSharing().activity.isEmpty)
    }

    @Test func deleteAllDataDisconnectsEveryoneAndEmptiesTheSharingStore() async throws {
        let (alex, riley) = try await phones()
        riley.model.add(pills)
        riley.model.add(received())
        riley.model.add(received("Feed the cat"))
        try riley.model.send(pills, to: [connectionID])
        riley.adapter.inviteAnswer = .sent
        _ = try await riley.sharing.invite(to: InvitedPerson(name: "Sam Rivera", address: "sam@example.com"), via: .copyLink)
        await settle(alex, riley)
        #expect(alex.sharing.data.sentCopies.isEmpty)
        #expect(riley.sharing.data.sentCopies.count == 1)
        let account = riley.sharing.data.accountID
        #expect(account != nil)

        try await riley.model.deleteAllData()
        await settle(alex, riley)

        // The account ID stays: it is still the account signed in. The disconnect went, so the
        // outbox is empty again, and sharing has stopped.
        #expect(try riley.keptSharing() == SharingData(accountID: account))
        #expect(!riley.model.isSharingOn)
        #expect(!riley.record.isOn)
        #expect(riley.adapter.stops == 1)
        #expect(riley.model.engine.reminders.isEmpty)
        #expect(riley.manager.scheduled.isEmpty)
        #expect(riley.center.pending.isEmpty)
        #expect(alex.sharing.data.connections.first?.state == .ended)
    }

    /// The disconnect waits in the store, not only in the adapter, so the other person still gets
    /// Connection Ended when Riley was offline or the app was stopped before iCloud had it.
    @Test func theDisconnectOutlivesTheDeleteWhileICloudIsOutOfReach() async throws {
        let (alex, riley) = try await phones()
        riley.model.add(received())
        riley.model.add(pills)
        try riley.model.send(pills, to: [connectionID])
        await settle(alex, riley)
        let account = riley.sharing.data.accountID
        riley.adapter.isOnline = false

        try await riley.model.deleteAllData()
        riley.relaunch()
        await riley.launch()

        #expect(!riley.model.isSharingOn)
        let kept = try riley.keptSharing()
        #expect(kept.connections.isEmpty)
        #expect(kept.sentReminders.isEmpty)
        #expect(kept.sentCopies.isEmpty)
        #expect(kept.receivedSyncStates.isEmpty)
        #expect(kept.engineStates.isEmpty)
        #expect(kept.accountID == account)
        #expect(kept.outbox.map(\.kind) == [.disconnect])
        #expect(alex.sharing.data.connections.first?.state == .connected)

        riley.adapter.isOnline = true
        await settle(alex, riley)

        #expect(alex.sharing.data.connections.first?.state == .ended)
        #expect(try riley.keptSharing().outbox.isEmpty)
    }

    @Test func deleteAllDataRevokesAnOpenInvite() async throws {
        let (alex, riley) = try await phones()
        riley.adapter.inviteAnswer = .sent
        _ = try await riley.sharing.invite(to: InvitedPerson(name: "Sam Rivera", address: "sam@example.com"), via: .copyLink)
        await settle(alex, riley)

        try await riley.model.deleteAllData()

        #expect(riley.adapter.revoked.count == 1)
        #expect(try riley.keptSharing().connections.isEmpty)
    }

    @Test func aPersonWithNoConnectionsSeesNothingNew() async throws {
        let riley = try Phone(seed: SharingData())
        await riley.launch()
        riley.model.add(pills)

        let account = riley.sharing.data.accountID

        try await riley.model.deleteAllData()

        #expect(try riley.keptSharing() == SharingData(accountID: account))
        #expect(riley.adapter.submitted.isEmpty)
        #expect(riley.model.engine.reminders.isEmpty)
    }
}
