import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The heartbeat in the app model (#435, spec #127 seam 1): when the app asks for one, and what the
/// other person's arrives as: Last synced, and whether the connection is Quiet. Over the fake adapter.
@MainActor
struct HeartbeatModelTests {
    typealias Phone = SharingAdapterTests.Phone

    let connectionID = UUID()
    let fourteenDays: TimeInterval = 14 * 24 * 60 * 60

    func phone(_ connections: [SharingConnection]) async throws -> Phone {
        let phone = try Phone(seed: SharingData(connections: connections))
        await phone.launch()
        return phone
    }

    func connected(mine: ConnectionChoices = ConnectionChoices(), theirs: ConnectionChoices = ConnectionChoices()) -> SharingConnection {
        SharingConnection(id: connectionID, name: "Sam", state: .connected, mine: mine, theirs: theirs)
    }

    /// Sam's settings, as they arrive from iCloud with `lastSynced` on them.
    func arrives(_ lastSynced: Date?, sharesStatus: Bool = true, on phone: Phone) async throws {
        let settings = SharingChange.ConnectionSettings(ConnectionChoices(sharesStatus: sharesStatus), lastSynced: lastSynced)
        try await phone.sharing.received(.settings(settings, for: connectionID))
    }

    func connection(on phone: Phone) throws -> SharingConnection {
        try #require(phone.sharing.data.connections.first { $0.id == connectionID })
    }

    // MARK: Asking for a heartbeat

    @Test func theAppAsksForAHeartbeatOfAConnectedConnectionWithItsStatusSharingOn() async throws {
        let phone = try await phone([connected()])

        #expect(phone.adapter.heartbeats.map(\.choices) == [[connectionID: ConnectionChoices()]])
        #expect(phone.adapter.heartbeats.map(\.now) == [phone.clock.now])
    }

    @Test func theHeartbeatRequestCarriesThePersonsOwnChoices() async throws {
        let mine = ConnectionChoices(sharesStatus: true, deliveryMode: .askMeFirst)
        let phone = try await phone([connected(mine: mine)])

        #expect(phone.adapter.heartbeats.map(\.choices) == [[connectionID: mine]])
    }

    @Test func theAppAsksAgainWhenItIsOpenedAgain() async throws {
        let phone = try await phone([connected()])

        phone.sharing.refreshAccountState()
        await phone.sharing.waitUntilApplied()

        #expect(phone.adapter.heartbeats.count == 2)
    }

    @Test func noHeartbeatWhileStatusSharingIsOff() async throws {
        let phone = try await phone([connected(mine: ConnectionChoices(sharesStatus: false))])

        #expect(phone.adapter.heartbeats.isEmpty)
    }

    @Test func noHeartbeatForAnInviteOrAConnectionTheOtherPersonEnded() async throws {
        let phone = try await phone([
            SharingConnection(id: UUID(), name: "Jordan", state: .invited),
            SharingConnection(id: UUID(), name: "Priya", state: .ended),
        ])

        #expect(phone.adapter.heartbeats.isEmpty)
    }

    @Test func noHeartbeatWhileICloudIsntAvailable() async throws {
        let phone = try Phone(seed: SharingData(connections: [connected()]))
        phone.adapter.account = .noAccount

        await phone.launch()

        #expect(phone.adapter.heartbeats.isEmpty)
    }

    @Test func noHeartbeatBeforeTheAppMayAskICloud() async throws {
        // Nothing is kept, and Connections hasn't been opened: the adapter isn't started and asked nothing.
        let phone = try await phone([])

        #expect(phone.adapter.starts == 0)
        #expect(phone.adapter.heartbeats.isEmpty)
    }

    // MARK: Last synced

    @Test func theOtherPersonsHeartbeatSetsTheConnectionsLastSynced() async throws {
        let phone = try await phone([connected()])
        let synced = phone.clock.now.addingTimeInterval(-3_600)

        try await arrives(synced, on: phone)

        #expect(try connection(on: phone).theirLastSynced == synced)
    }

    @Test func settingsWithoutAHeartbeatRemoveLastSynced() async throws {
        let phone = try await phone([connected()])
        try await arrives(phone.clock.now, on: phone)

        try await arrives(nil, sharesStatus: false, on: phone)

        #expect(try connection(on: phone).theirLastSynced == nil)
    }

    @Test func lastSyncedIsKeptAcrossARelaunch() async throws {
        let phone = try await phone([connected()])
        let synced = phone.clock.now.addingTimeInterval(-3_600)
        try await arrives(synced, on: phone)

        phone.relaunch()
        await phone.launch()

        #expect(try connection(on: phone).theirLastSynced == synced)
    }

    // MARK: Quiet

    @Test func aConnectionWhoseOtherPersonHasntSyncedIn14DaysIsQuiet() async throws {
        let phone = try await phone([connected()])
        let synced = phone.clock.now
        try await arrives(synced, on: phone)

        phone.clock.now = synced.addingTimeInterval(fourteenDays)

        #expect(try connection(on: phone).lastSyncedIfQuiet(at: phone.clock.now, after: fourteenDays) != nil)
        #expect(try connection(on: phone).lastSyncedIfQuiet(at: phone.clock.now, after: fourteenDays) == synced)
    }

    @Test func aConnectionSyncedSinceIsNotQuiet() async throws {
        let phone = try await phone([connected()])
        try await arrives(phone.clock.now, on: phone)
        phone.clock.now = phone.clock.now.addingTimeInterval(fourteenDays)
        try await arrives(phone.clock.now.addingTimeInterval(-60), on: phone)

        #expect(try connection(on: phone).lastSyncedIfQuiet(at: phone.clock.now, after: fourteenDays) == nil)
    }

    @Test func aConnectionJustUnder14DaysIsNotQuiet() async throws {
        let phone = try await phone([connected()])
        try await arrives(phone.clock.now, on: phone)

        phone.clock.now = phone.clock.now.addingTimeInterval(fourteenDays - 1)

        #expect(try connection(on: phone).lastSyncedIfQuiet(at: phone.clock.now, after: fourteenDays) == nil)
    }

    @Test func aConnectionWithNoLastSyncedIsNotQuiet() async throws {
        let phone = try await phone([connected()])
        phone.clock.now = phone.clock.now.addingTimeInterval(100 * fourteenDays)

        #expect(try connection(on: phone).lastSyncedIfQuiet(at: phone.clock.now, after: fourteenDays) == nil)
    }

    @Test func aConnectionIsNotQuietOnceTheirStatusSharingIsOff() async throws {
        let phone = try await phone([connected(theirs: ConnectionChoices(sharesStatus: false))])
        var connection = try connection(on: phone)
        connection.theirLastSynced = phone.clock.now.addingTimeInterval(-100 * fourteenDays)

        #expect(connection.lastSyncedIfQuiet(at: phone.clock.now, after: fourteenDays) == nil)
    }

    @Test func theModelReadsQuietByItsOwnClockAndTheDefaultWindow() async throws {
        let phone = try await phone([connected()])
        try await arrives(phone.clock.now, on: phone)
        let window = SharingConnection.quietAfter

        phone.clock.now = phone.clock.now.addingTimeInterval(window - 1)
        #expect(phone.sharing.lastSyncedIfQuiet(of: connectionID) == nil)

        phone.clock.now = phone.clock.now.addingTimeInterval(1)
        #expect(phone.sharing.lastSyncedIfQuiet(of: connectionID) != nil)
    }

    @Test func quietIs14DaysInAReleaseBuildAndShorterInDebug() {
        #expect(SharingConnection.quietInterval(isDebug: false) == 14 * 24 * 60 * 60)
        #expect(SharingConnection.quietInterval(isDebug: true) < 60 * 60)
    }
}
