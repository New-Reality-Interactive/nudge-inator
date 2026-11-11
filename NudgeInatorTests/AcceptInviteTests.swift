import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Accepting an invite (ticket 195, spec #127 seam 1): the sender's app model and the invited
/// people's, joined by the fake network, which offers an invite to the people the test names, as
/// the system hand-off does once iCloud has checked their Apple Account. What a test asserts is
/// what each sharing store keeps and what each person is shown.
@MainActor
struct AcceptInviteTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let riley = InvitedPerson(name: "Riley Park", address: "riley.park@icloud.com")

    /// The sender's sheet didn't send the invite, which every test here needs.
    struct InviteNotSent: Error {}

    /// A launched phone for each person, joined by the network.
    func launchedPhones(_ count: Int) async throws -> [Phone] {
        let phones = try (0..<count).map { _ in try Phone() }
        phones.forEach { network.add($0.adapter) }
        for phone in phones { await phone.launch() }
        return phones
    }

    /// The sender invites `riley` through the sheet, which also names `recipients` (the sheet
    /// can add more than one), from "Alex Morgan" as iCloud names the sender. Nobody has tapped it
    /// yet. Returns the sender's Invited connection.
    func invite(from sender: Phone, to recipients: [Phone]) async throws -> SharingConnection {
        sender.adapter.inviteAnswer = .names(riley)
        guard case .invited(let invited) = try await sender.sharing.invite() else {
            throw InviteNotSent()
        }
        network.share(invited.id, from: sender.adapter, senderName: "Alex Morgan", with: recipients.map(\.adapter))
        return invited
    }

    /// `recipient` taps the invite, and everything that follows from it happens.
    func tap(_ invite: SharingConnection, on recipient: Phone) async {
        network.tapInvite(invite.id, on: recipient.adapter)
        await network.settle()
    }

    // MARK: Accepting connects both ways

    @Test func acceptingConnectsBothPeopleUnderEachOthersNames() async throws {
        let phones = try await launchedPhones(2)
        let (alex, riley) = (phones[0], phones[1])

        let invited = try await invite(from: alex, to: [riley])
        await tap(invited, on: riley)

        let theirs = try #require(riley.sharing.data.connections.first)
        #expect(theirs.id == invited.id)
        #expect(theirs.name == "Alex Morgan")
        #expect(theirs.state == .connected)
        #expect(riley.sharing.acceptance == .connected(theirs))

        let mine = try #require(alex.sharing.data.connections.first)
        #expect(mine.id == invited.id)
        #expect(mine.name == "Riley Park")
        #expect(mine.state == .connected)
        #expect(alex.sharing.data.connections.count == 1)

        for phone in [alex, riley] {
            phone.relaunch()
            await phone.launch()
        }
        #expect(riley.sharing.data.connections == [theirs])
        #expect(alex.sharing.data.connections.map(\.state) == [.connected])
    }

    @Test func onceAcceptedEitherCanSendToTheOther() async throws {
        let phones = try await launchedPhones(2)
        let (alex, riley) = (phones[0], phones[1])
        let invited = try await invite(from: alex, to: [riley])
        await tap(invited, on: riley)

        try alex.sharing.submit(.settings(.init(name: "Alex M", ConnectionChoices(sharesStatus: false)), for: invited.id))
        try riley.sharing.submit(.settings(.init(name: "Riley P", ConnectionChoices(deliveryMode: .askMeFirst)), for: invited.id))
        await network.settle()

        #expect(riley.sharing.data.connections.map(\.theirs) == [ConnectionChoices(sharesStatus: false)])
        #expect(alex.sharing.data.connections.map(\.theirs) == [ConnectionChoices(deliveryMode: .askMeFirst)])
        // Each keeps the name the invite or the sharing sheet gave, whatever name the settings carry
        // (ticket 196).
        #expect(riley.sharing.data.connections.map(\.name) == ["Alex Morgan"])
        #expect(alex.sharing.data.connections.map(\.name) == ["Riley Park"])
    }

    @Test func theSendersInvitedRowBecomesTheConnectionByItsIDNotItsName() async throws {
        // Someone else invited under the same name stays Invited.
        let other = SharingConnection(id: UUID(), name: "Riley Park", state: .invited, address: "riley@work.example", invitedAt: NewYork.local(2026, 10, 14, 9))
        let alex = try Phone(seed: SharingData(connections: [other]))
        let riley = try Phone()
        [alex, riley].forEach { network.add($0.adapter) }
        await alex.launch()
        await riley.launch()

        let invited = try await invite(from: alex, to: [riley])
        await tap(invited, on: riley)

        #expect(alex.sharing.data.connections.map(\.id) == [other.id, invited.id])
        #expect(alex.sharing.data.connections.map(\.state) == [.invited, .connected])
    }

    @Test func tappingTheInviteAgainShowsTheConnectionWithNoSecondOne() async throws {
        let phones = try await launchedPhones(2)
        let (alex, riley) = (phones[0], phones[1])
        let invited = try await invite(from: alex, to: [riley])
        await tap(invited, on: riley)
        riley.sharing.dismissAcceptance()

        await tap(invited, on: riley)

        let theirs = try #require(riley.sharing.data.connections.first)
        #expect(riley.sharing.data.connections.count == 1)
        #expect(riley.sharing.acceptance == .connected(theirs))
        #expect(alex.sharing.data.connections.count == 1)
    }

    // MARK: One person per invite (spec #127, A6)

    @Test func theFirstToAcceptConnectsAndTheRestFindTheInviteUnavailable() async throws {
        let phones = try await launchedPhones(3)
        let (alex, riley, sam) = (phones[0], phones[1], phones[2])
        let invited = try await invite(from: alex, to: [riley, sam])

        await tap(invited, on: riley)
        await tap(invited, on: sam)

        #expect(riley.sharing.data.connections.map(\.state) == [.connected])
        #expect(sam.sharing.data.connections.isEmpty)
        // Taken off the share, so iCloud says it's unavailable before the app opens, as for an
        // invite to another Apple Account. The app's own message is for an invite it was handed
        // (the tests below).
        #expect(sam.sharing.acceptance == nil)
        #expect(alex.sharing.data.connections.count == 1)
        // Everyone else was taken off the share once Riley accepted.
        #expect(alex.adapter.keptOnly.map(\.participant) == [riley.adapter.participant])
    }

    @Test func twoAcceptingBeforeTheSenderHearsLeavesOnlyTheFirstConnected() async throws {
        let phones = try await launchedPhones(3)
        let (alex, riley, sam) = (phones[0], phones[1], phones[2])
        let invited = try await invite(from: alex, to: [riley, sam])

        // Both tap before Alex's app has heard of either.
        network.tapInvite(invited.id, on: riley.adapter)
        network.tapInvite(invited.id, on: sam.adapter)
        await network.settle()

        #expect(riley.sharing.data.connections.map(\.state) == [.connected])
        #expect(sam.sharing.data.connections.isEmpty)
        #expect(sam.sharing.acceptance == .unavailable)
        #expect(alex.sharing.data.connections.count == 1)
        #expect(alex.sharing.data.connections.first?.name == "Riley Park")

        sam.relaunch()
        await sam.launch()
        #expect(sam.sharing.data.connections.isEmpty)
    }

    /// A real adapter can report the withdrawal while the accept is still going through, before the
    /// app has kept the connection.
    @Test func takenOffTheShareWhileAcceptingLeavesNoConnection() async throws {
        let phones = try await launchedPhones(2)
        let (alex, riley) = (phones[0], phones[1])
        let invited = try await invite(from: alex, to: [riley])
        let sharing = riley.sharing
        riley.adapter.duringAccept = { try? await sharing.inviteWithdrawn(invited.id) }

        await tap(invited, on: riley)

        #expect(riley.sharing.data.connections.isEmpty)
        #expect(riley.sharing.acceptance == .unavailable)
    }

    @Test func aCanceledInviteIsUnavailable() async throws {
        let phones = try await launchedPhones(2)
        let (alex, riley) = (phones[0], phones[1])
        let invited = try await invite(from: alex, to: [riley])
        // Riley got it before it was canceled.
        network.tapInvite(invited.id, on: riley.adapter)
        try alex.sharing.cancelInvite(invited.id)

        await network.settle()

        #expect(riley.sharing.data.connections.isEmpty)
        #expect(riley.sharing.acceptance == .unavailable)
        #expect(alex.sharing.data.connections.isEmpty)
    }

    // MARK: When it can't be accepted now

    @Test func anInviteThatCouldntBeAcceptedSaysSoAndASecondTapWorks() async throws {
        let phones = try await launchedPhones(2)
        let (alex, riley) = (phones[0], phones[1])
        let invited = try await invite(from: alex, to: [riley])
        riley.adapter.acceptFails = true

        await tap(invited, on: riley)

        #expect(riley.sharing.acceptance == .failed)
        #expect(riley.sharing.data.connections.isEmpty)
        #expect(alex.sharing.data.connections.map(\.state) == [.invited])

        riley.adapter.acceptFails = false
        await tap(invited, on: riley)

        #expect(riley.sharing.data.connections.map(\.state) == [.connected])
        #expect(alex.sharing.data.connections.map(\.state) == [.connected])
    }

    @Test func aSharingStoreThatWontOpenAcceptsNothing() async throws {
        let phones = try await launchedPhones(2)
        let (alex, riley) = (phones[0], phones[1])
        let invited = try await invite(from: alex, to: [riley])
        riley.sharingStoreOpens = false
        riley.relaunch()
        await riley.launch()

        await tap(invited, on: riley)

        #expect(riley.sharing.acceptance == .failed)
        #expect(alex.sharing.data.connections.map(\.state) == [.invited])
    }
}
