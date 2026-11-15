import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Share Activity record (#396, spec #127 Offline and iCloud): what happened to a person's
/// sharing that they would otherwise never see. Riley's iPhone, connected to Alex through the fake
/// network; what a test asserts is what Riley's app model and sharing store keep. The Share
/// Activity page is #397's.
@MainActor
struct ShareActivityTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let connectionID = UUID()

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

    func reminder() -> Reminder {
        Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 9), strength: .firm)
    }

    // MARK: The record's limit

    @Test func theRecordKeepsTheNewestEntriesAndDropsTheOldestFirst() {
        var data = SharingData()
        for number in 1...(ShareActivityEntry.limit + 5) {
            data.record(ShareActivityEntry(at: Date(timeIntervalSince1970: Double(number)), connectionNames: ["Alex Morgan"], event: .otherPersonLeft))
        }

        #expect(data.activity.count == ShareActivityEntry.limit)
        #expect(data.activity.first?.at == Date(timeIntervalSince1970: 6))
        #expect(data.activity.last?.at == Date(timeIntervalSince1970: Double(ShareActivityEntry.limit + 5)))
        #expect(data.activity.map(\.at) == data.activity.map(\.at).sorted())
    }

    // MARK: Each event adds one entry

    @Test func aChangeICloudRefusedForGoodAddsAnEntryAndLeavesTheOutbox() async throws {
        let (_, riley) = try await phones()
        riley.adapter.isOnline = false
        try riley.model.send(reminder(), to: [connectionID])
        let change = try #require(riley.adapter.submitted.last)
        #expect(riley.sharing.data.outbox.map(\.id) == [change.entry.id])
        riley.clock.now = NewYork.local(2026, 10, 15, 8, 30)

        try await riley.sharing.gaveUp(change.entry.id)

        #expect(riley.sharing.data.activity == [
            ShareActivityEntry(id: riley.sharing.data.activity[0].id, at: NewYork.local(2026, 10, 15, 8, 30), connectionNames: ["Alex Morgan"], event: .changeGivenUp(.send)),
        ])
        #expect(riley.sharing.data.outbox.isEmpty)
    }

    @Test func aConnectionICloudLostAddsAnEntryAndEndsTheConnection() async throws {
        let (_, riley) = try await phones()
        riley.clock.now = NewYork.local(2026, 10, 15, 9, 15)

        try await riley.sharing.received(.connectionLost(connectionID))

        let entry = try #require(riley.sharing.data.activity.first)
        #expect(riley.sharing.data.activity.count == 1)
        #expect(entry.at == NewYork.local(2026, 10, 15, 9, 15))
        #expect(entry.connectionNames == ["Alex Morgan"])
        #expect(entry.event == .connectionLost)
        #expect(riley.sharing.data.connections.first?.state == .ended)
    }

    @Test func theOtherPersonLeavingAddsAnEntry() async throws {
        let (alex, riley) = try await phones()
        riley.clock.now = NewYork.local(2026, 10, 15, 10)

        try alex.sharing.disconnect(connectionID, received: [])
        await settle(alex, riley)

        let entries = riley.sharing.data.activity
        #expect(entries.map(\.event) == [.otherPersonLeft])
        #expect(entries.first?.connectionNames == ["Alex Morgan"])
        #expect(entries.first?.at == NewYork.local(2026, 10, 15, 10))
        #expect(alex.sharing.data.activity.isEmpty)
    }

    /// Nothing happened to a connection already ended, or one the app doesn't have.
    @Test func aDisconnectThatChangesNothingAddsNoEntry() async throws {
        let (_, riley) = try await phones()

        try await riley.sharing.received(.disconnect(connectionID))
        try await riley.sharing.received(.disconnect(connectionID))
        try await riley.sharing.received(.connectionLost(connectionID))
        try await riley.sharing.received(.disconnect(UUID()))

        #expect(riley.sharing.data.activity.map(\.event) == [.otherPersonLeft])
    }

    @Test func aChangeOfAppleAccountClearsTheRecordAndLeavesOneEntryForItself() async throws {
        let (alex, riley) = try await phones()
        try await riley.sharing.received(.connectionLost(connectionID))
        #expect(riley.sharing.data.activity.count == 1)
        riley.clock.now = NewYork.local(2026, 10, 15, 11)

        riley.adapter.signIn(as: "another-account")
        await settle(alex, riley)

        let entries = riley.sharing.data.activity
        #expect(entries.map(\.event) == [.accountChanged])
        #expect(entries.first?.connectionNames == ["Alex Morgan"])
        #expect(entries.first?.at == NewYork.local(2026, 10, 15, 11))
    }

    /// More than one connection removed: each name is kept, for the page to list in the person's language.
    @Test func aChangeOfAppleAccountKeepsEachConnectionRemoved() async throws {
        let (alex, riley) = try await phones()
        riley.adapter.inviteAnswer = .sent
        _ = try await riley.sharing.invite(to: InvitedPerson(name: "Sam Rivera", address: "sam@example.com"), via: .copyLink)

        riley.adapter.signIn(as: "another-account")
        await settle(alex, riley)

        #expect(riley.sharing.data.activity.first?.connectionNames == ["Alex Morgan", "Sam Rivera"])
    }

    @Test func aChangeOfAppleAccountThatRemovedNothingLeavesTheRecordEmpty() async throws {
        let riley = try Phone(seed: SharingData(accountID: AppleAccountID("old-account"), activity: [
            ShareActivityEntry(at: NewYork.local(2026, 10, 14, 9), connectionNames: ["Alex Morgan"], event: .otherPersonLeft),
        ]))
        network.add(riley.adapter)
        await riley.launch()
        // Connections is open, so the app may ask iCloud which account it is.
        riley.sharing.allowICloud()

        riley.adapter.signIn(as: "another-account")
        await riley.model.waitUntilApplied()
        await network.settle()
        await riley.model.waitUntilApplied()

        #expect(riley.sharing.data.activity.isEmpty)
    }

    // MARK: Kept

    @Test func theRecordSurvivesARelaunchOldestFirst() async throws {
        let (_, riley) = try await phones()
        riley.adapter.isOnline = false
        try riley.model.send(reminder(), to: [connectionID])
        let refused = try #require(riley.adapter.submitted.last)
        riley.clock.now = NewYork.local(2026, 10, 15, 9)
        try await riley.sharing.gaveUp(refused.entry.id)
        riley.clock.now = NewYork.local(2026, 10, 15, 10)
        try await riley.sharing.received(.connectionLost(connectionID))
        let before = riley.sharing.data.activity
        #expect(before.map(\.at) == [NewYork.local(2026, 10, 15, 9), NewYork.local(2026, 10, 15, 10)])

        riley.relaunch()
        await riley.launch()

        #expect(riley.sharing.data.activity == before)
    }

    @Test func personalRemindersAreUntouched() async throws {
        let (_, riley) = try await phones()
        let own = reminder()
        riley.model.add(own)
        let before = riley.model.engine.reminders

        try await riley.sharing.received(.connectionLost(connectionID))

        #expect(riley.model.engine.reminders == before)
    }
}
