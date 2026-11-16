import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// How Sharing Works opening by itself the first time Sharing is turned on (#424, spec #127 seam 1):
/// through the app model over the fake sharing adapter and network, with the tutorial's seen-flag
/// in the phone's own defaults suite, as the Sharing switch's record is. What a test asserts is
/// whether the tutorial is due, and what the flag keeps. That the sheet opens over Settings, only
/// once the Connected sheet has gone, is the phone check.
@MainActor
struct SharingTutorialFirstTimeTests {
    typealias Phone = TurnOffSharingTests.Phone

    // MARK: From Settings

    @Test func turningSharingOnTheFirstTimeOpensTheTutorial() async throws {
        let phone = try Phone(sharingOn: false)
        await phone.launch()

        phone.model.setSharing(on: true)

        #expect(phone.model.isSharingTutorialDue)
    }

    /// Close and Done both close the sheet, which is what the model hears.
    @Test func onceClosedItDoesntOpenAgainWhenSharingIsTurnedOffAndOn() async throws {
        let phone = try Phone(sharingOn: false)
        await phone.launch()
        phone.model.setSharing(on: true)
        await phone.sharing.waitUntilApplied()

        phone.model.sharingTutorialClosed()
        phone.model.setSharing(on: false)
        phone.model.setSharing(on: true)

        #expect(!phone.model.isSharingTutorialDue)
        #expect(phone.tutorial.isSeen)
    }

    // MARK: Through an invite while Sharing is off

    /// Alex has invited Riley, whose phone has Sharing off, and Riley opens the invite (#389's
    /// helpers).
    let invites = InviteWhileSharingOffTests()

    func rileyOpensAnInvite() async throws -> Phone {
        let (_, riley, invite) = try await invites.phones()
        invites.open(invite, on: riley)
        return riley
    }

    func turnOnSharingAndConnect(on riley: Phone) async {
        riley.model.answerPendingInvite(turnOnSharing: true)
        await invites.network.settle()
        await riley.model.waitUntilApplied()
    }

    @Test func turnOnSharingOpensTheTutorialOnlyOnceTheConnectedSheetIsDone() async throws {
        let riley = try await rileyOpensAnInvite()

        await turnOnSharingAndConnect(on: riley)

        guard case .connected = riley.sharing.acceptance else {
            Issue.record("Connected isn't shown")
            return
        }
        #expect(!riley.model.isSharingTutorialDue)

        riley.sharing.dismissAcceptance()
        riley.model.connectedSheetClosed()

        #expect(riley.model.isSharingTutorialDue)
    }

    /// Change These opens the connection's page: that counts as having seen the tutorial, so none
    /// follows the sheet closing, nor a later off and on.
    @Test func changeTheseCountsAsSeen() async throws {
        let riley = try await rileyOpensAnInvite()
        await turnOnSharingAndConnect(on: riley)

        riley.model.changeTheseChosen()
        riley.sharing.dismissAcceptance()
        riley.model.connectedSheetClosed()

        #expect(!riley.model.isSharingTutorialDue)
        #expect(riley.tutorial.isSeen)
        // Connected, so off is Turn Off Sharing's confirmation.
        try riley.model.turnSharingOff(choosing: .remove)
        riley.model.setSharing(on: true)
        #expect(riley.model.isSharingOn)
        #expect(!riley.model.isSharingTutorialDue)
    }

    @Test func notNowOpensNoTutorialAndLeavesItUnseen() async throws {
        let riley = try await rileyOpensAnInvite()

        riley.model.answerPendingInvite(turnOnSharing: false)
        riley.model.connectedSheetClosed()

        #expect(!riley.model.isSharingOn)
        #expect(!riley.model.isSharingTutorialDue)
        #expect(!riley.tutorial.isSeen)
    }

    // MARK: Already on

    /// A tester on an earlier build, with Sharing on and a connection: no automatic tutorial, as
    /// Sharing isn't being turned on.
    @Test func aLaunchWithSharingAlreadyOnOpensNoTutorial() async throws {
        let phone = try Phone(seed: SharingData(connections: [
            SharingConnection(id: UUID(), name: "Alex Morgan", state: .connected),
        ]))
        await phone.launch()
        phone.model.setSharing(on: true)

        #expect(phone.model.isSharingOn)
        #expect(!phone.model.isSharingTutorialDue)
        #expect(!phone.tutorial.isSeen)
    }

    // MARK: The flag

    /// A new install, and a reinstall, which empties the app's defaults: unseen.
    @Test func anUnsetRecordReadsUnseen() {
        let suiteName = "SharingTutorialFirstTimeTests.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        #expect(!SharingTutorialRecord(defaults: UserDefaults(suiteName: suiteName)!).isSeen)
    }

    @Test func deleteAllDataLeavesTheFlagAsItWas() async throws {
        let phone = try Phone(sharingOn: false)
        await phone.launch()
        phone.model.setSharing(on: true)
        await phone.sharing.waitUntilApplied()
        phone.model.sharingTutorialClosed()

        try await phone.model.deleteAllData()

        #expect(phone.tutorial.isSeen)
    }
}
