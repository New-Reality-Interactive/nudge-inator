import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Sent's search, Sort and count header (ticket 328, spec #127 seam 1): Alex sends reminders to
/// Riley and Sam through the fake network, and the tests read Alex's Sent with a search and a sort.
/// Where the tools sit, the Sort menu and Clear Search are the phone check.
@MainActor
struct SentSearchAndSortTests {
    typealias Phone = SharingAdapterTests.Phone

    let network = FakeSharingNetwork()
    let rileyID = UUID()
    let samID = UUID()

    /// Due at 8:30 every day: the phones' clocks say 8:00 on 15 October.
    let pills = Reminder(title: "Take the pills", notes: "Two with water", dueTime: NewYork.local(2026, 10, 15, 8, 30), repeatRule: .everyDay, strength: .firm)
    /// Due at 9:00 today, once.
    let call = Reminder(title: "Call the clinic", dueTime: NewYork.local(2026, 10, 15, 9, 0), strength: .gentle)
    /// Due at 7:00 today, once, so already past: the row shows its start.
    let walk = Reminder(title: "Walk the dog", notes: "Bring water", dueTime: NewYork.local(2026, 10, 15, 7, 0), strength: .gentle)

    /// Alex, connected to Riley and Sam, having sent the pills to both, then the call to Sam, then
    /// the walk to Riley and Sam, a minute apart.
    func alexHavingSent() async throws -> Phone {
        let alex = try Phone(seed: SharingData(connections: [
            SharingConnection(id: rileyID, name: "Riley Park", state: .connected),
            SharingConnection(id: samID, name: "Sam Rivera", state: .connected),
        ]))
        let riley = try Phone(seed: SharingData(connections: [SharingConnection(id: rileyID, name: "Alex Morgan", state: .connected)]))
        let sam = try Phone(seed: SharingData(connections: [SharingConnection(id: samID, name: "Alex Morgan", state: .connected)]))
        network.join(alex.adapter, riley.adapter, through: rileyID)
        network.join(alex.adapter, sam.adapter, through: samID)
        for phone in [alex, riley, sam] { await phone.launch() }
        try alex.model.send(pills, to: [rileyID, samID])
        alex.clock.now += 60
        try alex.model.send(call, to: [samID])
        alex.clock.now += 60
        try alex.model.send(walk, to: [rileyID, samID])
        for phone in [alex, riley, sam] { await phone.model.waitUntilApplied() }
        await network.settle()
        for phone in [alex, riley, sam] { await phone.model.waitUntilApplied() }
        return alex
    }

    func sent(on alex: Phone, sort: RemindersSort = .createdOldestFirst, search: String = "") -> SentScreen {
        SentScreen(engine: alex.model.engine, sharing: alex.model.sharing?.data ?? SharingData(), tools: SentTools(search: search, sort: sort))
    }

    func titles(_ screen: SentScreen) -> [String: [String]] {
        Dictionary(uniqueKeysWithValues: screen.people.map { ($0.name, $0.rows.map(\.title)) })
    }

    // MARK: Search

    @Test func searchFindsTitlesAndNotesAndAPersonWithNoMatchDropsOut() async throws {
        let alex = try await alexHavingSent()

        let byTitle = sent(on: alex, search: "clinic")
        #expect(byTitle.people.map(\.name) == ["Sam Rivera"])
        #expect(titles(byTitle) == ["Sam Rivera": ["Call the clinic"]])

        let byNotes = sent(on: alex, search: " WATER ")
        #expect(byNotes.people.map(\.name) == ["Riley Park", "Sam Rivera"])
        #expect(titles(byNotes) == ["Riley Park": ["Take the pills", "Walk the dog"], "Sam Rivera": ["Take the pills", "Walk the dog"]])
    }

    // MARK: Sort

    @Test func createdOldestFirstIsTheOrderSentAndNewestFirstItsReverseInsideEachGroup() async throws {
        let alex = try await alexHavingSent()

        #expect(titles(sent(on: alex)) == [
            "Riley Park": ["Take the pills", "Walk the dog"],
            "Sam Rivera": ["Take the pills", "Call the clinic", "Walk the dog"],
        ])
        let newest = sent(on: alex, sort: RemindersSort(field: .created, order: .descending))
        #expect(newest.people.map(\.name) == ["Riley Park", "Sam Rivera"])
        #expect(titles(newest) == [
            "Riley Park": ["Walk the dog", "Take the pills"],
            "Sam Rivera": ["Walk the dog", "Call the clinic", "Take the pills"],
        ])
    }

    @Test func dueDateOrdersEachGroupByTheDueTimeItsRowsShowEitherWayRound() async throws {
        let alex = try await alexHavingSent()

        let earliest = sent(on: alex, sort: RemindersSort(field: .dueDate, order: .ascending))
        #expect(earliest.people.map(\.name) == ["Riley Park", "Sam Rivera"])
        #expect(titles(earliest) == [
            "Riley Park": ["Walk the dog", "Take the pills"],
            "Sam Rivera": ["Walk the dog", "Take the pills", "Call the clinic"],
        ])
        let latest = sent(on: alex, sort: RemindersSort(field: .dueDate, order: .descending))
        #expect(titles(latest) == [
            "Riley Park": ["Take the pills", "Walk the dog"],
            "Sam Rivera": ["Call the clinic", "Take the pills", "Walk the dog"],
        ])
    }

    /// Two due at one time keep the order sent under Earliest First, and its reverse under Latest
    /// First, as Mine's ties do.
    @Test func remindersDueAtOneTimeKeepTheOrderSentReversedForLatestFirst() async throws {
        let alex = try await alexHavingSent()
        let pharmacy = Reminder(title: "Call the pharmacy", dueTime: NewYork.local(2026, 10, 15, 9, 0), strength: .gentle)
        alex.clock.now += 60
        try alex.model.send(pharmacy, to: [samID])
        await alex.model.waitUntilApplied()

        let earliest = sent(on: alex, sort: RemindersSort(field: .dueDate, order: .ascending))
        let latest = sent(on: alex, sort: RemindersSort(field: .dueDate, order: .descending))

        #expect(titles(earliest)["Sam Rivera"] == ["Walk the dog", "Take the pills", "Call the clinic", "Call the pharmacy"])
        #expect(titles(latest)["Sam Rivera"] == ["Call the pharmacy", "Call the clinic", "Take the pills", "Walk the dog"])
    }

    // MARK: Count and no match

    /// The pills went to Riley and Sam, and count once.
    @Test func theCountIsOfRemindersSoOneSentToTwoPeopleCountsOnce() async throws {
        let alex = try await alexHavingSent()

        #expect(String(localized: sent(on: alex).countText) == "3 reminders out of 3")
        #expect(String(localized: sent(on: alex, search: "water").countText) == "2 reminders out of 3")
        #expect(String(localized: sent(on: alex, search: "clinic").countText) == "1 reminder out of 3")
    }

    @Test func aSearchMatchingNothingIsNoMatchWithNoGroups() async throws {
        let alex = try await alexHavingSent()

        let screen = sent(on: alex, search: "zebra")

        #expect(screen.emptyState == .noMatch)
        #expect(screen.people.isEmpty)
        #expect(String(localized: screen.countText) == "0 reminders out of 3")
    }

    /// A search left over can't turn Sent's two empty states into No Matches.
    @Test func aSearchLeavesSentsEmptyStatesAsTheyAre() async throws {
        let alone = try Phone(seed: SharingData())
        await alone.launch()
        let connected = try Phone(seed: SharingData(connections: [SharingConnection(id: rileyID, name: "Riley Park", state: .connected)]))
        await connected.launch()

        #expect(sent(on: alone, search: "zebra").emptyState == .noOneToSendTo)
        #expect(sent(on: connected, search: "zebra").emptyState == .nothingSent)
    }

    /// The tab shows the search field and Sort exactly when Sent isn't in one of its empty states.
    @Test func sentHasItsToolsExactlyOutsideItsEmptyStates() async throws {
        let alone = try Phone(seed: SharingData())
        await alone.launch()
        let connected = try Phone(seed: SharingData(connections: [SharingConnection(id: rileyID, name: "Riley Park", state: .connected)]))
        await connected.launch()
        let alex = try await alexHavingSent()

        for (phone, search, hasTools) in [(alone, "", false), (connected, "", false), (alex, "", true), (alex, "zebra", true)] {
            let data = phone.model.sharing?.data ?? SharingData()
            let screen = sent(on: phone, search: search)
            #expect(SentScreen.hasTools(in: data) == hasTools)
            #expect((screen.emptyState == nil || screen.emptyState == .noMatch) == hasTools)
        }
    }
}
