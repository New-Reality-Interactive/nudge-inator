import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Inviting someone, through the app model and the sharing adapter's fake (ticket 194, #217, spec
/// #127 seam 1). The fake stands for the delivery of the invite (the compose screen, the
/// clipboard): it is sent, or canceled, or fails. What a test asserts is what the sharing store
/// keeps and what the adapter was asked to do.
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

    @Test func aSentInviteIsListedAsInvitedWithThePersonItWasFor() async throws {
        let phone = try await launchedPhone()
        phone.adapter.inviteAnswer = .sent

        let outcome = try await phone.sharing.invite(to: jordan, via: .copyLink)

        let kept = try #require(phone.sharing.data.connections.first)
        #expect(outcome == .invited(kept))
        #expect(kept.name == "Jordan Lee")
        #expect(kept.address == "jordan.lee@icloud.com")
        #expect(kept.state == .invited)
        #expect(kept.invitedAt == phone.clock.now)
        // The adapter was asked for this connection's invite, to this person, by this route.
        #expect(phone.adapter.invites == [kept.id])
        #expect(phone.adapter.invited.map(\.person) == [jordan])
        #expect(phone.adapter.invited.map(\.route) == [.copyLink])

        phone.relaunch()
        await phone.launch()
        #expect(phone.sharing.data.connections == [kept])
    }

    @Test func cancelingTheDeliverySendsAndKeepsNothing() async throws {
        let phone = try await launchedPhone()
        phone.adapter.inviteAnswer = .canceled

        #expect(try await phone.sharing.invite(to: jordan, via: .copyLink) == .canceled)

        // Only the account the launch recorded (ticket 212).
        #expect(phone.sharing.data == SharingData(accountID: phone.adapter.accountID))
        #expect(phone.adapter.revoked.isEmpty)
    }

    @Test func anInviteThatCouldntBeMadeKeepsNothing() async throws {
        let phone = try await launchedPhone()
        phone.adapter.inviteAnswer = .fails

        await #expect(throws: FakeSharingAdapter.InviteFailed.self) {
            try await phone.sharing.invite(to: jordan, via: .copyLink)
        }

        // Only the account the launch recorded (ticket 212).
        #expect(phone.sharing.data == SharingData(accountID: phone.adapter.accountID))
    }

    @Test func aSharingStoreThatWontOpenMakesNoInvite() async throws {
        let phone = try await launchedPhone()
        phone.sharingStoreOpens = false
        phone.relaunch()
        await phone.launch()
        phone.adapter.inviteAnswer = .sent

        await #expect(throws: Phone.StoreWouldNotOpen.self) {
            try await phone.sharing.invite(to: jordan, via: .copyLink)
        }

        #expect(phone.adapter.invites.isEmpty)
    }

    @Test func cancelingAnInviteRevokesItAndTakesItOffTheList() async throws {
        let phone = try await launchedPhone()
        phone.adapter.inviteAnswer = .sent
        guard case .invited(let invited) = try await phone.sharing.invite(to: jordan, via: .copyLink) else {
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
    func invitingSomeoneAlreadyConnectedSaysSoAndMakesNoSecondConnection(address: String) async throws {
        let connected = SharingConnection(id: UUID(), name: "Jordan", state: .connected, address: "jordan.lee@icloud.com")
        let phone = try await launchedPhone(seed: SharingData(connections: [connected]))
        phone.adapter.inviteAnswer = .sent

        let outcome = try await phone.sharing.invite(to: InvitedPerson(name: "Jordan Lee", address: address), via: .copyLink)

        #expect(outcome == .alreadyConnected(connected))
        #expect(phone.sharing.data.connections == [connected])
        // Said before any iCloud work: no invite was made, so none needs revoking.
        #expect(phone.adapter.invites.isEmpty)
        #expect(phone.adapter.revoked.isEmpty)
    }

    @Test(arguments: ["+1 (555) 010-4477", "+15550104477"])
    func aPhoneNumberMatchesHoweverItIsWritten(address: String) async throws {
        let connected = SharingConnection(id: UUID(), name: "Priya Shah", state: .connected, address: "+1 555 010 4477")
        let phone = try await launchedPhone(seed: SharingData(connections: [connected]))
        phone.adapter.inviteAnswer = .sent

        #expect(try await phone.sharing.invite(to: InvitedPerson(name: "Priya", address: address), via: .copyLink) == .alreadyConnected(connected))
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
        phone.adapter.inviteAnswer = .sent

        guard case .invited = try await phone.sharing.invite(to: InvitedPerson(name: "sam ortiz", address: "sam.work@icloud.com"), via: .copyLink) else {
            Issue.record("A name alone doesn't make someone connected")
            return
        }
        #expect(phone.sharing.data.connections.count == 2)
    }

    @Test func theSameNameAtAnotherAddressDoesntReplaceTheirInvite() async throws {
        let first = SharingConnection(id: UUID(), name: "Jordan Lee", state: .invited, address: "jordan@icloud.com", invitedAt: NewYork.local(2026, 10, 12, 9))
        let phone = try await launchedPhone(seed: SharingData(connections: [first]))
        phone.adapter.inviteAnswer = .sent

        _ = try await phone.sharing.invite(to: jordan, via: .copyLink)

        #expect(phone.sharing.data.connections.count == 2)
        #expect(phone.adapter.revoked.isEmpty)
    }

    @Test func someoneWithAnotherNameAndAddressIsInvited() async throws {
        let connected = SharingConnection(id: UUID(), name: "Sam Ortiz", state: .connected, address: "sam@icloud.com")
        let phone = try await launchedPhone(seed: SharingData(connections: [connected]))
        phone.adapter.inviteAnswer = .sent

        guard case .invited = try await phone.sharing.invite(to: jordan, via: .copyLink) else {
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
        phone.adapter.inviteAnswer = .sent

        let outcome = try await phone.sharing.invite(to: jordan, via: .copyLink, replacing: wrong.id)

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
        phone.adapter.inviteAnswer = .sent

        _ = try await phone.sharing.invite(to: jordan, via: .copyLink)

        #expect(phone.sharing.data.connections.count == 1)
        #expect(phone.sharing.data.connections.first?.invitedAt == phone.clock.now)
        #expect(phone.adapter.revoked == [first.id])
    }

    @Test func inviteAgainClosedLeavesTheOldInvite() async throws {
        let wrong = SharingConnection(id: UUID(), name: "Jordan Lee", state: .invited, address: "jordan@icloud.com", invitedAt: NewYork.local(2026, 10, 12, 9))
        let phone = try await launchedPhone(seed: SharingData(connections: [wrong]))
        phone.adapter.inviteAnswer = .canceled

        #expect(try await phone.sharing.invite(to: jordan, via: .copyLink, replacing: wrong.id) == .canceled)

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

    @Test(arguments: InviteRoute.allCases)
    func theInviteIsDeliveredByTheRouteChosen(route: InviteRoute) async throws {
        let phone = try await launchedPhone()
        phone.adapter.inviteAnswer = .sent

        _ = try await phone.sharing.invite(to: jordan, via: route)

        #expect(phone.adapter.invited.map(\.route) == [route])
    }

    @Test func anInviteWaitingToBeAcceptedIsFoundByTheAddressHoweverItIsWritten() async throws {
        let waiting = SharingConnection(id: UUID(), name: "Jordan", state: .invited, address: "jordan.lee@icloud.com", invitedAt: NewYork.local(2026, 10, 12, 9))
        let connected = SharingConnection(id: UUID(), name: "Sam Ortiz", state: .connected, address: "sam@icloud.com")
        let phone = try await launchedPhone(seed: SharingData(connections: [waiting, connected]))

        #expect(phone.sharing.invitedConnection(for: InvitedPerson(name: "Jordan Lee", address: " Jordan.Lee@iCloud.com ")) == waiting)
        // Connected is a different answer (the sheet says "Already Connected"), and the same name alone is someone new.
        #expect(phone.sharing.invitedConnection(for: InvitedPerson(name: "Sam Ortiz", address: "sam@icloud.com")) == nil)
        #expect(phone.sharing.invitedConnection(for: InvitedPerson(name: "Jordan Lee", address: "jordan@work.com")) == nil)
    }

    @Test func aListedConnectionIsFoundInAnyState() async throws {
        let waiting = SharingConnection(id: UUID(), name: "Jordan", state: .invited, address: "jordan@icloud.com", invitedAt: NewYork.local(2026, 10, 12, 9))
        let connected = SharingConnection(id: UUID(), name: "Sam Ortiz", state: .connected, address: "sam@icloud.com")
        let phone = try await launchedPhone(seed: SharingData(connections: [waiting, connected]))

        #expect(phone.sharing.listedConnection(waiting.id) == waiting)
        #expect(phone.sharing.listedConnection(connected.id) == connected)
        #expect(phone.sharing.listedConnection(UUID()) == nil)
    }
}
