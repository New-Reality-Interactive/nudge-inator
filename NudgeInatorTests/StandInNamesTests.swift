#if DEBUG
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The stand-in sharing's `names` set (#335): four connected people, each sent one reminder, so the
/// phone check of Sent's name order has an accented name to place.
@MainActor
struct StandInNamesTests {
    let clock = FakeClock(now: NewYork.local(2026, 11, 21, 9))

    @Test func namesHasFourConnectedPeopleEachSentOneReminder() async throws {
        let model = try #require(StandInSharing.modelIfAsked(clock: clock, environment: [StandInSharing.variable: "names"]))
        model.refreshAccountState()
        await model.waitUntilApplied()

        let connected = model.connected

        #expect(Set(connected.map(\.name)) == ["Zoe Adams", "Riley Park", "Ana Ortiz", "Émile Roy"])
        #expect(model.data.sentCopies.count == 4)
        #expect(Set(model.data.sentCopies.map(\.connectionID)) == Set(connected.map(\.id)))
    }

    @Test func sentListsThePeopleInTheLocalesNameOrder() async throws {
        let model = try #require(StandInSharing.modelIfAsked(clock: clock, environment: [StandInSharing.variable: "names"]))
        model.refreshAccountState()
        await model.waitUntilApplied()

        // By code point "Émile Roy" would come last.
        #expect(model.data.sentConnections.map(\.name) == ["Ana Ortiz", "Émile Roy", "Riley Park", "Zoe Adams"])
    }
}
#endif
