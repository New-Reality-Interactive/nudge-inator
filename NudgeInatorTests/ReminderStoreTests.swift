import Foundation
import Testing
import NudgeEngine
import SwiftData
@testable import NudgeInator

/// The store keeps reminders, tags and each reminder's history on the device. Each relaunch test
/// saves to a temporary file, drops the store, and reads it back through a new one.
@MainActor
struct ReminderStoreTests {
    let fileURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).store")

    func relaunchedStore() throws -> ReminderStore {
        try ReminderStore(location: .file(fileURL))
    }

    @Test func aReminderWithTagsAndARepeatReadsBackEqualAfterARelaunch() throws {
        let home = Tag(name: "home")
        let health = Tag(name: "health")
        let pills = Reminder(
            title: "Take the pills",
            notes: "With food",
            tagIDs: [health.id, home.id],
            dueTime: Date(timeIntervalSince1970: 1_791_000_000),
            repeatRule: .everyDay,
            strength: .firm,
            breakThroughFocus: false
        )
        let saved = StoredData(reminders: [pills], tags: [home, health], histories: [:])

        try ReminderStore(location: .file(fileURL)).save(saved)

        #expect(try relaunchedStore().load() == saved)
    }

    @Test func deletingATagKeepsItsRemindersAndTakesItOffThem() throws {
        let home = Tag(name: "home")
        let health = Tag(name: "health")
        let pills = Reminder(title: "Take the pills", tagIDs: [home.id, health.id], dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        let bins = Reminder(title: "Put the bins out", tagIDs: [home.id], dueTime: NewYork.local(2026, 10, 15, 19), strength: .gentle)
        let store = try ReminderStore(location: .file(fileURL))
        try store.save(StoredData(reminders: [pills, bins], tags: [home, health], histories: [:]))

        try store.deleteTag(home.id)

        let loaded = try relaunchedStore().load()
        #expect(loaded.tags == [health])
        #expect(loaded.reminders.map(\.id) == [pills.id, bins.id])
        #expect(loaded.reminders.map(\.tagIDs) == [[health.id], []])
    }

    /// Ticket 12: the store deletes the reminder and its history together with `engine.delete`.
    @Test func deletingAReminderDeletesItsHistoryAndLeavesTheOthers() throws {
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        let bins = Reminder(title: "Put the bins out", dueTime: NewYork.local(2026, 10, 15, 19), strength: .gentle)
        let paused = ReminderHistory(pauseSpans: [PauseSpan(start: NewYork.local(2026, 10, 15, 8))])
        let store = try ReminderStore(location: .file(fileURL))
        try store.save(StoredData(reminders: [pills, bins], tags: [], histories: [pills.id: paused, bins.id: paused]))

        try store.deleteReminder(pills.id)

        #expect(try relaunchedStore().load() == StoredData(reminders: [bins], tags: [], histories: [bins.id: paused]))
    }

    /// A save is the whole picture: what it leaves out goes, history and all, and a reminder saved
    /// again under its ID with no history comes back with none.
    @Test func savingReplacesWhatTheStoreHeld() throws {
        let home = Tag(name: "home")
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        let bins = Reminder(title: "Put the bins out", dueTime: NewYork.local(2026, 10, 15, 19), strength: .gentle)
        let paused = ReminderHistory(pauseSpans: [PauseSpan(start: NewYork.local(2026, 10, 15, 8))])
        let store = try ReminderStore(location: .file(fileURL))
        try store.save(StoredData(reminders: [pills, bins], tags: [home], histories: [pills.id: paused, bins.id: paused]))

        try store.save(StoredData(reminders: [bins], tags: [], histories: [:]))

        #expect(try relaunchedStore().load() == StoredData(reminders: [bins], tags: [], histories: [:]))
    }

    /// Settings' Delete All Data (ticket 30).
    @Test func deleteAllDataEmptiesRemindersTagsAndHistories() throws {
        let home = Tag(name: "home")
        let pills = Reminder(title: "Take the pills", tagIDs: [home.id], dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        let done = ReminderHistory(closedOccurrences: [pills.dueTime: Closing(state: .done, closedAt: NewYork.local(2026, 10, 15, 9, 5), nudgesSent: 1)])
        let store = try ReminderStore(location: .file(fileURL))
        try store.save(StoredData(reminders: [pills], tags: [home], histories: [pills.id: done]))

        try store.deleteAllData()

        #expect(try relaunchedStore().load() == StoredData(reminders: [], tags: [], histories: [:]))
    }

    /// No sync and no network (spec story 56). The default, `.automatic`, would sync as soon as a
    /// CloudKit entitlement appeared.
    @Test(arguments: [StoreLocation.appGroup, .inMemory, .file(URL(filePath: "/tmp/test.store"))])
    func noLocationSyncsWithCloudKit(_ location: StoreLocation) throws {
        // `CloudKitDatabase` isn't Equatable, so compare descriptions, after checking that they
        // tell `.none` from the default.
        let none = String(describing: ModelConfiguration.CloudKitDatabase.none)
        try #require(none != String(describing: ModelConfiguration.CloudKitDatabase.automatic))

        #expect(String(describing: ReminderStore.configuration(for: location).cloudKitDatabase) == none)
    }

    @Test func theInMemoryStoreWritesNothingToDisk() {
        #expect(ReminderStore.configuration(for: .inMemory).isStoredInMemoryOnly)
    }

    /// The simulator gives the test host its App Group container, so the path can be asserted.
    @Test func theAppStoreLivesInTheAppGroupContainer() throws {
        let container = try #require(FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ReminderStore.appGroupIdentifier))

        let url = ReminderStore.configuration(for: .appGroup).url

        #expect(url.standardizedFileURL.path().hasPrefix(container.standardizedFileURL.path()))
    }

    /// Pauses and titles come back oldest first, the order the engine reads them in.
    @Test func aReminderHistoryReadsBackEqualAfterARelaunch() throws {
        let pills = Reminder(title: "Take the blue pills", dueTime: NewYork.local(2026, 10, 1), repeatRule: .everyDay, strength: .firm)
        let history = ReminderHistory(
            closedOccurrences: [
                NewYork.local(2026, 10, 2): Closing(state: .done, closedAt: NewYork.local(2026, 10, 2, 9, 31), nudgesSent: 2),
                NewYork.local(2026, 10, 3): Closing(state: .missed(reason: .giveUpLimit), closedAt: NewYork.local(2026, 10, 3, 11, 12, 30), nudgesSent: 20),
            ],
            editAppliesAfter: NewYork.local(2026, 10, 3),
            pauseSpans: [
                PauseSpan(start: NewYork.local(2026, 10, 4, 8), end: NewYork.local(2026, 10, 5, 8)),
                PauseSpan(start: NewYork.local(2026, 10, 6, 8), end: NewYork.local(2026, 10, 7, 8)),
                PauseSpan(start: NewYork.local(2026, 10, 8, 8)),
            ],
            replacedTitles: [
                Replaced(value: "Take the pills", replacedAt: NewYork.local(2026, 10, 2, 9, 40)),
                Replaced(value: "Take the red pills", replacedAt: NewYork.local(2026, 10, 3, 9, 40)),
            ]
        )
        let saved = StoredData(reminders: [pills], tags: [], histories: [pills.id: history])

        try ReminderStore(location: .file(fileURL)).save(saved)

        #expect(try relaunchedStore().load() == saved)
    }

    /// Every 2 weeks on Monday and Wednesday, 5 times: the ticket's custom rule.
    nonisolated static let everyOtherMondayAndWednesdayFiveTimes = RepeatRule(
        frequency: .weekly,
        interval: 2,
        weekdays: [.init(.monday), .init(.wednesday)],
        end: .count(5)
    )

    /// The presets clamp month ends and a custom rule skips, so a preset must read back as the
    /// preset, not as the custom rule with the same RRULE text.
    @Test(arguments: [
        nil, RepeatRule.everyDay, .everyWeekday, .everyWeek, .everyTwoWeeks, .everyMonth, .everyYear,
        everyOtherMondayAndWednesdayFiveTimes,
    ])
    func aRepeatReadsBackAsTheSameRuleAfterARelaunch(_ rule: RepeatRule?) throws {
        let reminder = Reminder(title: "Pay rent", dueTime: Date(timeIntervalSince1970: 1_791_000_000), repeatRule: rule, strength: .gentle)

        try ReminderStore(location: .file(fileURL)).save(StoredData(reminders: [reminder], tags: [], histories: [:]))

        #expect(try relaunchedStore().load().reminders.first?.repeatRule == rule)
    }
}
