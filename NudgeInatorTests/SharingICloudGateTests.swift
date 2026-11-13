import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Nothing asks iCloud until the person opens Connections or an invite reaches them (spec #127,
/// decision 4; #216): through the app model, the fake adapter counts each start and account read,
/// which the real adapter makes requests for.
@MainActor
struct SharingICloudGateTests {
    typealias Phone = SharingAdapterTests.Phone

    @Test func aPersonWhoNeverSharesIsNeverAskedAboutICloud() async throws {
        let phone = try Phone()

        await phone.launch()
        await phone.model.appOpened()
        await phone.sharing.waitUntilApplied()

        #expect(phone.adapter.starts == 0)
        #expect(phone.adapter.accountReads == 0)
        #expect(phone.sharing.accountState == nil)
    }

    @Test func openingConnectionsStartsSharing() async throws {
        let phone = try Phone()
        await phone.launch()

        phone.sharing.allowICloud()
        await phone.sharing.waitUntilApplied()

        #expect(phone.adapter.starts == 1)
        #expect(phone.sharing.accountState == .available)
    }

    @Test func anInviteReachingThemStartsSharing() async throws {
        let phone = try Phone()
        await phone.launch()

        await phone.sharing.invited(IncomingInvite(connectionID: UUID(), senderName: "Alex"))
        await phone.sharing.waitUntilApplied()

        #expect(phone.adapter.starts == 1)
        #expect(phone.sharing.accountState == .available)
    }

    @Test func sharingKeptFromBeforeStartsAtLaunch() async throws {
        let phone = try Phone(seed: SharingData(connections: [SharingConnection(id: UUID(), name: "Sam", state: .connected)]))

        await phone.launch()

        #expect(phone.adapter.starts == 1)
        #expect(phone.adapter.accountReads == 1)
    }

    @Test func theAdaptersStateIsKeptAcrossARelaunch() async throws {
        let phone = try Phone()
        await phone.launch()
        let state = SharingSyncState(engines: [SyncEngineState(database: .private, data: Data([1, 2]))], cache: Data([3]))

        try phone.sharing.keepSyncState(state)
        phone.relaunch()
        await phone.launch()

        #expect(phone.sharing.savedSyncState() == state)
    }
}
