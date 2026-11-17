#if DEBUG
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The stand-in sharing's Quiet controls (#436), so a Debug build has a Quiet connection for the
/// phone check of a connection's page: Riley Park goes Quiet, syncs again, and keeps or loses Last
/// synced as their Status sharing changes, as the real heartbeat does (#435).
@MainActor
struct StandInQuietTests {
    let clock = FakeClock(now: NewYork.local(2026, 11, 16, 9))
    let day: TimeInterval = 24 * 60 * 60

    func seeded() async throws -> (SharingModel, StandInSharingAdapter) {
        let model = try #require(StandInSharing.modelIfAsked(clock: clock, environment: [StandInSharing.variable: "seeded"]))
        let adapter = try #require(StandInSharing.current)
        // Opens the store, as the app model's launch does.
        model.refreshAccountState()
        await model.waitUntilApplied()
        return (model, adapter)
    }

    func riley(on model: SharingModel) throws -> SharingConnection {
        try #require(model.connection(SeedSet.standInConnectionID))
    }

    @Test func goingQuietShowsLastSynced18DaysBack() async throws {
        let (model, adapter) = try await seeded()

        await adapter.theyGoQuiet(try riley(on: model), at: clock.now)

        #expect(model.lastSyncedIfQuiet(of: SeedSet.standInConnectionID) == clock.now.addingTimeInterval(-18 * day))
    }

    @Test func syncingAgainEndsQuiet() async throws {
        let (model, adapter) = try await seeded()
        await adapter.theyGoQuiet(try riley(on: model), at: clock.now)

        await adapter.theySync(try riley(on: model), at: clock.now)

        #expect(model.lastSyncedIfQuiet(of: SeedSet.standInConnectionID) == nil)
        #expect(try riley(on: model).theirLastSynced == clock.now)
    }

    @Test func turningTheirStatusSharingOffClearsLastSynced() async throws {
        let (model, adapter) = try await seeded()
        await adapter.theyGoQuiet(try riley(on: model), at: clock.now)

        await adapter.theyChoose(ConnectionChoices(sharesStatus: false), for: try riley(on: model))

        #expect(try riley(on: model).theirLastSynced == nil)
        #expect(model.lastSyncedIfQuiet(of: SeedSet.standInConnectionID) == nil)
    }

    @Test func changingTheirDeliveryModeKeepsQuiet() async throws {
        let (model, adapter) = try await seeded()
        await adapter.theyGoQuiet(try riley(on: model), at: clock.now)

        await adapter.theyChoose(ConnectionChoices(sharesStatus: true, deliveryMode: .askMeFirst), for: try riley(on: model))

        #expect(model.lastSyncedIfQuiet(of: SeedSet.standInConnectionID) == clock.now.addingTimeInterval(-18 * day))
    }
}
#endif
