import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Delete All Data covers sharing (ticket 214, spec #127 Privacy and compliance): Alex and Riley,
/// connected through the fake network, and Riley deleting all data. What a test asserts is what
/// Riley's app model, both stores and alarms keep, and what reaches Alex. Wording, layout and the
/// largest text size are the phone check.
@MainActor
struct DeleteAllDataSharingTests {
    typealias Phone = SharingAdapterTests.Phone

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

    @Test func deleteAllDataDisconnectsEveryoneAndEmptiesTheSharingStore() async throws {
        let (alex, riley) = try await phones()
        riley.model.add(pills)
        riley.model.add(received())
        riley.model.add(received("Feed the cat"))
        try riley.model.send(pills, to: [connectionID])
        riley.adapter.inviteAnswer = .names(InvitedPerson(name: "Sam Rivera", address: "sam@example.com"))
        _ = try await riley.sharing.invite()
        await settle(alex, riley)

        let account = riley.sharing.data.accountID
        #expect(account != nil)

        try await riley.model.deleteAllData()
        await settle(alex, riley)

        // The account ID stays: it is still the account signed in.
        #expect(riley.sharing.data == SharingData(accountID: account))
        #expect(try riley.sharing.currentData() == SharingData(accountID: account))
        #expect(riley.model.engine.reminders.isEmpty)
        #expect(riley.manager.scheduled.isEmpty)
        #expect(riley.center.pending.isEmpty)
        #expect(alex.sharing.data.connections.first?.state == .ended)
    }

    @Test func deleteAllDataRevokesAnOpenInvite() async throws {
        let (alex, riley) = try await phones()
        riley.adapter.inviteAnswer = .names(InvitedPerson(name: "Sam Rivera", address: "sam@example.com"))
        _ = try await riley.sharing.invite()
        await settle(alex, riley)

        try await riley.model.deleteAllData()

        #expect(riley.adapter.revoked.count == 1)
        #expect(riley.sharing.data.connections.isEmpty)
    }

    @Test func aPersonWithNoConnectionsSeesNothingNew() async throws {
        let riley = try Phone(seed: SharingData())
        await riley.launch()
        riley.model.add(pills)

        let account = riley.sharing.data.accountID

        try await riley.model.deleteAllData()

        #expect(riley.sharing.data == SharingData(accountID: account))
        #expect(riley.adapter.submitted.isEmpty)
        #expect(riley.model.engine.reminders.isEmpty)
    }
}
