import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Opening an invite while Sharing is off (#389, spec #127 seam 1): Alex invites Riley through the
/// fake network, and Riley's phone, with Sharing off, is handed the invite as the scene delegate
/// hands it: the sender's name, and what hands the invite to the adapter once there is one. What a
/// test asserts is what Riley's app model asks and keeps, and what reaches Alex. The alert's layout,
/// VoiceOver and the largest text size are the phone check.
@MainActor
struct InviteWhileSharingOffTests {
    typealias Phone = TurnOffSharingTests.Phone

    let network = FakeSharingNetwork()
    let riley = InvitedPerson(name: "Riley Park", address: "riley.park@icloud.com")

    /// Alex, with Sharing on, has invited Riley, whose phone has Sharing off and has never made
    /// the sharing model.
    func phones() async throws -> (alex: Phone, riley: Phone, invite: SharingConnection) {
        let alex = try Phone()
        let rileysPhone = try Phone(sharingOn: false)
        network.add(alex.adapter)
        network.add(rileysPhone.adapter)
        await alex.launch()
        await rileysPhone.launch()
        return (alex, rileysPhone, try await sendInvite(from: alex, to: rileysPhone))
    }

    struct InviteNotSent: Error {}

    /// Alex invites `riley` and the invite is shared with `recipient`'s phone, as iCloud names Alex.
    func sendInvite(from alex: Phone, to recipient: Phone) async throws -> SharingConnection {
        alex.adapter.inviteAnswer = .sent
        guard case .invited(let invited) = try await alex.sharing.invite(to: riley, via: .copyLink) else {
            throw InviteNotSent()
        }
        network.share(invited.id, from: alex.adapter, senderName: "Alex Morgan", with: [recipient.adapter])
        return invited
    }

    /// Riley opens the invite: the scene delegate hands it over, and the hand-over taps it on the
    /// adapter, as `CloudKitSharingAdapter.receive` does.
    func open(_ invite: SharingConnection, on phone: Phone) {
        phone.model.receiveInvite(from: "Alex Morgan") { [network] in
            network.tapInvite(invite.id, on: phone.adapter)
        }
    }

    // MARK: Asking

    @Test func anInviteWhileSharingIsOffAsksFirstAndHandsOverNothing() async throws {
        let (_, riley, invite) = try await phones()

        open(invite, on: riley)
        await network.settle()

        #expect(riley.model.pendingInvite == PendingInvite(senderName: "Alex Morgan"))
        #expect(!riley.model.isSharingOn)
        #expect(!riley.record.isOn)
        #expect(riley.made == 0)
        #expect(try riley.keptSharing().connections.isEmpty)
    }

    // MARK: Turn On Sharing

    @Test func turnOnSharingTurnsItOnAndConnectsBothPeople() async throws {
        let (alex, riley, invite) = try await phones()
        open(invite, on: riley)

        riley.model.answerPendingInvite(turnOnSharing: true)
        await network.settle()
        await riley.model.waitUntilApplied()

        #expect(riley.model.pendingInvite == nil)
        #expect(riley.model.isSharingOn)
        #expect(riley.record.isOn)
        let theirs = try #require(riley.sharing.data.connections.first)
        #expect(theirs.id == invite.id)
        #expect(theirs.name == "Alex Morgan")
        #expect(theirs.state == .connected)
        #expect(riley.sharing.acceptance == .connected(theirs))
        #expect(alex.sharing.data.connections.map(\.state) == [.connected])
    }

    @Test func turnOnSharingCarriesOnWithTheModelWindingDown() async throws {
        // Riley had Sharing on with Sam, and turned it off while offline: the switch is winding down.
        let alex = try Phone()
        let rileysPhone = try Phone(seed: SharingData(connections: [
            SharingConnection(id: UUID(), name: "Sam Rivera", state: .connected),
        ]))
        network.add(alex.adapter)
        network.add(rileysPhone.adapter)
        await alex.launch()
        await rileysPhone.launch()
        rileysPhone.adapter.isOnline = false
        try rileysPhone.model.turnSharingOff(choosing: .remove)
        #expect(!rileysPhone.model.isSharingOn)
        let made = rileysPhone.made
        let invite = try await sendInvite(from: alex, to: rileysPhone)

        open(invite, on: rileysPhone)
        #expect(rileysPhone.model.pendingInvite != nil)
        rileysPhone.model.answerPendingInvite(turnOnSharing: true)
        await network.settle()
        await rileysPhone.model.waitUntilApplied()

        #expect(rileysPhone.made == made)
        #expect(rileysPhone.model.isSharingOn)
        #expect(rileysPhone.sharing.data.connections.map(\.name) == ["Alex Morgan"])
        #expect(alex.sharing.data.connections.map(\.state) == [.connected])
    }

    // MARK: Not Now

    @Test func notNowLeavesSharingOffAndTheInviteOpenForAnotherTry() async throws {
        let (alex, riley, invite) = try await phones()
        open(invite, on: riley)

        riley.model.answerPendingInvite(turnOnSharing: false)
        await network.settle()

        #expect(riley.model.pendingInvite == nil)
        #expect(!riley.model.isSharingOn)
        #expect(!riley.record.isOn)
        #expect(riley.made == 0)
        #expect(try riley.keptSharing().connections.isEmpty)
        #expect(alex.sharing.data.connections.map(\.state) == [.invited])

        // Opening the same invite again asks again.
        open(invite, on: riley)
        #expect(riley.model.pendingInvite == PendingInvite(senderName: "Alex Morgan"))
        riley.model.answerPendingInvite(turnOnSharing: true)
        await network.settle()
        await riley.model.waitUntilApplied()
        #expect(riley.sharing.data.connections.map(\.state) == [.connected])
    }

    // MARK: Sharing on, and other invites

    @Test func withSharingOnTheInviteGoesStraightToTheModelWithNoPrompt() async throws {
        let alex = try Phone()
        let rileysPhone = try Phone()
        network.add(alex.adapter)
        network.add(rileysPhone.adapter)
        await alex.launch()
        await rileysPhone.launch()
        let invite = try await sendInvite(from: alex, to: rileysPhone)

        open(invite, on: rileysPhone)
        await network.settle()
        await rileysPhone.model.waitUntilApplied()

        #expect(rileysPhone.model.pendingInvite == nil)
        #expect(rileysPhone.sharing.data.connections.map(\.state) == [.connected])
        #expect(rileysPhone.sharing.acceptance == .connected(try #require(rileysPhone.sharing.data.connections.first)))
    }

    @Test func notNowStillTakesTheInviteWhenSharingWasTurnedOnMeanwhile() async throws {
        let (alex, riley, invite) = try await phones()
        open(invite, on: riley)
        riley.model.setSharing(on: true)

        riley.model.answerPendingInvite(turnOnSharing: false)
        await network.settle()
        await riley.model.waitUntilApplied()

        #expect(riley.model.pendingInvite == nil)
        #expect(riley.sharing.data.connections.map(\.state) == [.connected])
        #expect(alex.sharing.data.connections.map(\.state) == [.connected])
    }

    @Test func aNewerInviteReplacesOneNotYetAnswered() async throws {
        let (_, riley, _) = try await phones()
        var handedOver: [String] = []
        riley.model.receiveInvite(from: "Alex Morgan") { handedOver.append("Alex Morgan") }
        riley.model.receiveInvite(from: "Sam Rivera") { handedOver.append("Sam Rivera") }

        #expect(riley.model.pendingInvite == PendingInvite(senderName: "Sam Rivera"))
        riley.model.answerPendingInvite(turnOnSharing: true)
        #expect(handedOver == ["Sam Rivera"])
    }
}
