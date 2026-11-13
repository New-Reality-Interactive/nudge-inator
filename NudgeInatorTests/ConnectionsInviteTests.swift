import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Inviting someone, through the app model and the sharing adapter's fake (ticket 194, spec #127
/// seam 1). The fake stands for the system sharing sheet: it names whoever the test says, or is
/// canceled, or fails. What a test asserts is what the sharing store keeps and what the adapter
/// was asked to do.
@MainActor
struct ConnectionsInviteTests {
    typealias Phone = SharingAdapterTests.Phone

    let jordan = InvitedPerson(name: "Jordan Lee", address: "jordan.lee@icloud.com")

    /// A launched phone with Connections open, where inviting starts.
    func launchedPhone(seed: SharingData = SharingData()) async throws -> Phone {
        let phone = try Phone(seed: seed)
        await phone.launch()
        phone.sharing.allowICloud()
        await phone.sharing.waitUntilApplied()
        return phone
    }

    @Test func aSentInviteIsListedAsInvitedWithThePersonAsTheSheetNamedThem() async throws {
        let phone = try await launchedPhone()
        phone.adapter.inviteAnswer = .names(jordan)

        let outcome = try await phone.sharing.invite()

        let kept = try #require(phone.sharing.data.connections.first)
        #expect(outcome == .invited(kept))
        #expect(kept.name == "Jordan Lee")
        #expect(kept.address == "jordan.lee@icloud.com")
        #expect(kept.state == .invited)
        #expect(kept.invitedAt == phone.clock.now)
        // The sheet was asked for this connection's invite.
        #expect(phone.adapter.invites == [kept.id])

        phone.relaunch()
        await phone.launch()
        #expect(phone.sharing.data.connections == [kept])
    }

    @Test func closingTheSheetSendsAndKeepsNothing() async throws {
        let phone = try await launchedPhone()
        phone.adapter.inviteAnswer = .canceled

        #expect(try await phone.sharing.invite() == .canceled)

        // Only the account the launch recorded (ticket 212).
        #expect(phone.sharing.data == SharingData(accountID: phone.adapter.accountID))
        #expect(phone.adapter.revoked.isEmpty)
    }

    @Test func anInviteThatCouldntBeMadeKeepsNothing() async throws {
        let phone = try await launchedPhone()
        phone.adapter.inviteAnswer = .fails

        await #expect(throws: FakeSharingAdapter.InviteFailed.self) {
            try await phone.sharing.invite()
        }

        // Only the account the launch recorded (ticket 212).
        #expect(phone.sharing.data == SharingData(accountID: phone.adapter.accountID))
    }

    @Test func aSharingStoreThatWontOpenShowsNoSheet() async throws {
        let phone = try await launchedPhone()
        phone.sharingStoreOpens = false
        phone.relaunch()
        await phone.launch()
        phone.adapter.inviteAnswer = .names(jordan)

        await #expect(throws: Phone.StoreWouldNotOpen.self) {
            try await phone.sharing.invite()
        }

        #expect(phone.adapter.invites.isEmpty)
    }

    @Test func cancelingAnInviteRevokesItAndTakesItOffTheList() async throws {
        let phone = try await launchedPhone()
        phone.adapter.inviteAnswer = .names(jordan)
        guard case .invited(let invited) = try await phone.sharing.invite() else {
            Issue.record("The invite should have been sent")
            return
        }

        try phone.sharing.cancelInvite(invited.id)

        #expect(phone.adapter.revoked == [invited.id])
        #expect(phone.sharing.data.connections.isEmpty)
        phone.relaunch()
        await phone.launch()
        #expect(phone.sharing.data.connections.isEmpty)
    }

    // MARK: Someone already connected, or already invited

    @Test(arguments: ["jordan.lee@icloud.com", "  Jordan.Lee@iCloud.com "])
    func invitingSomeoneAlreadyConnectedSaysSoAndMakesNoSecondConnection(sheetAddress: String) async throws {
        let connected = SharingConnection(id: UUID(), name: "Jordan", state: .connected, address: "jordan.lee@icloud.com")
        let phone = try await launchedPhone(seed: SharingData(connections: [connected]))
        phone.adapter.inviteAnswer = .names(InvitedPerson(name: "Jordan Lee", address: sheetAddress))

        let outcome = try await phone.sharing.invite()

        #expect(outcome == .alreadyConnected(connected))
        #expect(phone.sharing.data.connections == [connected])
        // The sheet had already made the invite, so it is revoked.
        #expect(phone.adapter.revoked == phone.adapter.invites)
    }

    @Test(arguments: ["+1 (555) 010-4477", "+15550104477"])
    func aPhoneNumberMatchesHoweverItIsWritten(sheetAddress: String) async throws {
        let connected = SharingConnection(id: UUID(), name: "Priya Shah", state: .connected, address: "+1 555 010 4477")
        let phone = try await launchedPhone(seed: SharingData(connections: [connected]))
        phone.adapter.inviteAnswer = .names(InvitedPerson(name: "Priya", address: sheetAddress))

        #expect(try await phone.sharing.invite() == .alreadyConnected(connected))
    }

    /// Two people can share a name, so only the address says it's the same person (the developer's
    /// call at #194's phone check, over the mockup's name-or-address match). Someone who invited
    /// this person has no address here, so inviting them back isn't caught.
    @Test(arguments: [
        SharingConnection(id: UUID(), name: "Sam Ortiz", state: .connected, address: "sam@icloud.com"),
        SharingConnection(id: UUID(), name: "Sam Ortiz", state: .connected),
    ])
    func theSameNameAtAnotherAddressIsSomeoneNew(connected: SharingConnection) async throws {
        let phone = try await launchedPhone(seed: SharingData(connections: [connected]))
        phone.adapter.inviteAnswer = .names(InvitedPerson(name: "sam ortiz", address: "sam.work@icloud.com"))

        guard case .invited = try await phone.sharing.invite() else {
            Issue.record("A name alone doesn't make someone connected")
            return
        }
        #expect(phone.sharing.data.connections.count == 2)
    }

    @Test func theSameNameAtAnotherAddressDoesntReplaceTheirInvite() async throws {
        let first = SharingConnection(id: UUID(), name: "Jordan Lee", state: .invited, address: "jordan@icloud.com", invitedAt: NewYork.local(2026, 10, 12, 9))
        let phone = try await launchedPhone(seed: SharingData(connections: [first]))
        phone.adapter.inviteAnswer = .names(jordan)

        _ = try await phone.sharing.invite()

        #expect(phone.sharing.data.connections.count == 2)
        #expect(phone.adapter.revoked.isEmpty)
    }

    @Test func someoneWithAnotherNameAndAddressIsInvited() async throws {
        let connected = SharingConnection(id: UUID(), name: "Sam Ortiz", state: .connected, address: "sam@icloud.com")
        let phone = try await launchedPhone(seed: SharingData(connections: [connected]))
        phone.adapter.inviteAnswer = .names(jordan)

        guard case .invited = try await phone.sharing.invite() else {
            Issue.record("Jordan isn't connected")
            return
        }
        #expect(phone.sharing.data.connections.count == 2)
    }

    @Test func inviteAgainReplacesTheOldInviteWithTheNewOne() async throws {
        let older = SharingConnection(id: UUID(), name: "Sam", state: .connected, address: "sam@icloud.com")
        let wrong = SharingConnection(id: UUID(), name: "Jordan Lee", state: .invited, address: "jordan@icloud.com", invitedAt: NewYork.local(2026, 10, 12, 9))
        let later = SharingConnection(id: UUID(), name: "Priya", state: .invited, address: "priya@icloud.com", invitedAt: NewYork.local(2026, 10, 14, 9))
        let phone = try await launchedPhone(seed: SharingData(connections: [older, wrong, later]))
        phone.adapter.inviteAnswer = .names(jordan)

        let outcome = try await phone.sharing.invite(replacing: wrong.id)

        let again = phone.sharing.data.connections[1]
        #expect(outcome == .invited(again))
        #expect(again.address == "jordan.lee@icloud.com")
        #expect(again.invitedAt == phone.clock.now)
        #expect(again.id != wrong.id)
        #expect(phone.sharing.data.connections.map(\.id) == [older.id, again.id, later.id])
        #expect(phone.adapter.revoked == [wrong.id])
    }

    @Test func invitingSomeoneAlreadyInvitedReplacesTheirInvite() async throws {
        let first = SharingConnection(id: UUID(), name: "Jordan Lee", state: .invited, address: "jordan.lee@icloud.com", invitedAt: NewYork.local(2026, 10, 12, 9))
        let phone = try await launchedPhone(seed: SharingData(connections: [first]))
        phone.adapter.inviteAnswer = .names(jordan)

        _ = try await phone.sharing.invite()

        #expect(phone.sharing.data.connections.count == 1)
        #expect(phone.sharing.data.connections.first?.invitedAt == phone.clock.now)
        #expect(phone.adapter.revoked == [first.id])
    }

    @Test func inviteAgainClosedLeavesTheOldInvite() async throws {
        let wrong = SharingConnection(id: UUID(), name: "Jordan Lee", state: .invited, address: "jordan@icloud.com", invitedAt: NewYork.local(2026, 10, 12, 9))
        let phone = try await launchedPhone(seed: SharingData(connections: [wrong]))
        phone.adapter.inviteAnswer = .canceled

        #expect(try await phone.sharing.invite(replacing: wrong.id) == .canceled)

        #expect(phone.sharing.data.connections == [wrong])
        #expect(phone.adapter.revoked.isEmpty)
    }

    @Test func onlyAnInviteCanBeCanceledThisWay() async throws {
        let connected = SharingConnection(id: UUID(), name: "Sam", state: .connected)
        let phone = try await launchedPhone(seed: SharingData(connections: [connected]))

        try phone.sharing.cancelInvite(connected.id)

        #expect(phone.adapter.revoked.isEmpty)
        #expect(phone.sharing.data.connections == [connected])
    }
}
