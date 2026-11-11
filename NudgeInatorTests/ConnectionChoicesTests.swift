import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// A connection's Status sharing and Delivery mode (ticket 196, spec #127 seam 1): two people
/// connected through an accepted invite, each changing their own choices for what they receive.
/// What a test asserts is what each sharing store keeps and what each person's connection shows.
@MainActor
struct ConnectionChoicesTests {
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
        alex.adapter.inviteAnswer = .names(InvitedPerson(name: "Riley Park", address: "riley.park@icloud.com"))
        guard case .invited(let invited) = try await alex.sharing.invite() else { throw InviteNotSent() }
        network.share(invited.id, from: alex.adapter, senderName: "Alex Morgan", with: [riley.adapter])
        network.tapInvite(invited.id, on: riley.adapter)
        await network.settle()
        return (alex, riley, invited.id)
    }

    func connection(_ id: UUID, on phone: Phone) throws -> SharingConnection {
        try #require(phone.sharing.data.connections.first { $0.id == id })
    }

    @Test func bothPeopleStartWithStatusSharingOnAndStartRightAway() async throws {
        let (alex, riley, id) = try await connected()

        for phone in [alex, riley] {
            let connection = try connection(id, on: phone)
            #expect(connection.mine == ConnectionChoices(sharesStatus: true, deliveryMode: .startRightAway))
            #expect(connection.theirs == ConnectionChoices(sharesStatus: true, deliveryMode: .startRightAway))
        }
    }

    @Test func aPersonsChoicesReachTheOtherAsTheirsAndLeaveTheOthersOwnAlone() async throws {
        let (alex, riley, id) = try await connected()
        let rileys = ConnectionChoices(sharesStatus: false, deliveryMode: .askMeFirst)

        try riley.sharing.change(rileys, for: id)
        await network.settle()

        #expect(try connection(id, on: riley).mine == rileys)
        #expect(try connection(id, on: alex).theirs == rileys)
        // Riley's choices toward Alex don't set Alex's toward Riley.
        #expect(try connection(id, on: alex).mine == ConnectionChoices())
        #expect(try connection(id, on: riley).theirs == ConnectionChoices())
    }

    @Test func bothPeoplesChoicesAreKeptAcrossARelaunch() async throws {
        let (alex, riley, id) = try await connected()
        try riley.sharing.change(ConnectionChoices(deliveryMode: .askMeFirst), for: id)
        try alex.sharing.change(ConnectionChoices(sharesStatus: false), for: id)
        await network.settle()

        for phone in [alex, riley] {
            phone.relaunch()
            await phone.launch()
        }

        #expect(try connection(id, on: riley).mine == ConnectionChoices(deliveryMode: .askMeFirst))
        #expect(try connection(id, on: riley).theirs == ConnectionChoices(sharesStatus: false))
        #expect(try connection(id, on: alex).mine == ConnectionChoices(sharesStatus: false))
        #expect(try connection(id, on: alex).theirs == ConnectionChoices(deliveryMode: .askMeFirst))
    }

    @Test func aChangeTheStoreCantKeepChangesNothingAndSendsNothing() async throws {
        let (alex, riley, id) = try await connected()
        riley.sharingStoreOpens = false
        riley.relaunch()
        await riley.launch()

        #expect(throws: Phone.StoreWouldNotOpen.self) {
            try riley.sharing.change(ConnectionChoices(sharesStatus: false), for: id)
        }
        await network.settle()

        #expect(riley.sharing.data == SharingData())
        #expect(try connection(id, on: alex).theirs == ConnectionChoices())
    }

    @Test func choosingWhatIsAlreadyChosenSendsNothing() async throws {
        let (_, riley, id) = try await connected()

        try riley.sharing.change(ConnectionChoices(), for: id)

        #expect(riley.sharing.data.outbox.isEmpty)
        #expect(riley.adapter.submitted.isEmpty)
    }

    @Test func bothPeopleKeepWhenTheyConnected() async throws {
        let (alex, riley, id) = try await connected()

        #expect(try connection(id, on: alex).connectedAt == alex.clock.now)
        #expect(try connection(id, on: riley).connectedAt == riley.clock.now)
    }
}
