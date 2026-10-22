import Foundation
import Testing
import NudgeEngine
import SwiftData
@testable import NudgeInator

/// The store keeps reminders, tags and each reminder's history on the device. Each relaunch test
/// saves to a temporary file, drops the store, and reads it back through a new one.
@MainActor
struct ReminderStoreTests {
    let storeFile = TemporaryStoreFile()
    var fileURL: URL { storeFile.url }

    func store() throws -> ReminderStore {
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

        try store().save(saved)

        #expect(try store().load() == saved)
    }

    @Test func deletingATagKeepsItsRemindersAndTakesItOffThem() throws {
        let home = Tag(name: "home")
        let health = Tag(name: "health")
        let pills = Reminder(title: "Take the pills", tagIDs: [home.id, health.id], dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        let bins = Reminder(title: "Put the bins out", tagIDs: [home.id], dueTime: NewYork.local(2026, 10, 15, 19), strength: .gentle)
        let opened = try store()
        try opened.save(StoredData(reminders: [pills, bins], tags: [home, health], histories: [:]))

        try opened.deleteTag(home.id)

        let loaded = try store().load()
        #expect(loaded.tags == [health])
        #expect(loaded.reminders.map(\.id) == [pills.id, bins.id])
        #expect(loaded.reminders.map(\.tagIDs) == [[health.id], []])
    }

    /// Ticket 12: the store deletes the reminder and its history together with `engine.delete`.
    @Test func deletingAReminderDeletesItsHistoryAndLeavesTheOthers() throws {
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        let bins = Reminder(title: "Put the bins out", dueTime: NewYork.local(2026, 10, 15, 19), strength: .gentle)
        let paused = ReminderHistory(pauseSpans: [PauseSpan(start: NewYork.local(2026, 10, 15, 8))])
        let opened = try store()
        try opened.save(StoredData(reminders: [pills, bins], tags: [], histories: [pills.id: paused, bins.id: paused]))

        try opened.delete(pills.id)

        #expect(try store().load() == StoredData(reminders: [bins], tags: [], histories: [bins.id: paused]))
    }

    /// A save is the whole picture: what it leaves out goes, history and all, and a reminder saved
    /// again under its ID with no history comes back with none.
    @Test func savingReplacesWhatTheStoreHeld() throws {
        let home = Tag(name: "home")
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        let bins = Reminder(title: "Put the bins out", dueTime: NewYork.local(2026, 10, 15, 19), strength: .gentle)
        let paused = ReminderHistory(pauseSpans: [PauseSpan(start: NewYork.local(2026, 10, 15, 8))])
        let opened = try store()
        try opened.save(StoredData(reminders: [pills, bins], tags: [home], histories: [pills.id: paused, bins.id: paused]))

        try opened.save(StoredData(reminders: [bins], tags: [], histories: [:]))

        #expect(try store().load() == StoredData(reminders: [bins], tags: [], histories: [:]))
    }

    /// Settings' Delete All Data (ticket 30).
    @Test func deleteAllDataEmptiesRemindersTagsAndHistories() throws {
        let home = Tag(name: "home")
        let pills = Reminder(title: "Take the pills", tagIDs: [home.id], dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        let done = ReminderHistory(closedOccurrences: [pills.dueTime: Closing(state: .done, closedAt: NewYork.local(2026, 10, 15, 9, 5), nudgesSent: 1)])
        let opened = try store()
        try opened.save(StoredData(reminders: [pills], tags: [home], histories: [pills.id: done]))

        try opened.deleteAllData()

        #expect(try store().load() == StoredData(reminders: [], tags: [], histories: [:]))
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

    /// The simulator and the iPhone give the test host its App Group container, so the path can be
    /// asserted. On the iPhone the store's path starts `/private/var` and the container's `/var`,
    /// the same directory (`/var` links to it). `resolvingSymlinksInPath()` strips `/private` only
    /// from a file that exists, and the store file isn't created here, so the prefix goes by hand.
    @Test func theAppStoreLivesInTheAppGroupContainer() throws {
        let container = try #require(FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ReminderStore.appGroupIdentifier))

        let url = ReminderStore.configuration(for: .appGroup).url

        func withoutPrivate(_ url: URL) -> String {
            let path = url.standardizedFileURL.path()
            return path.hasPrefix("/private/") ? String(path.dropFirst("/private".count)) : path
        }
        #expect(withoutPrivate(url).hasPrefix(withoutPrivate(container)))
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

        try store().save(saved)

        #expect(try store().load() == saved)
    }

    /// Pause, Resume and Pause again in the same instant: the spans share a start, and only their
    /// saved order says which is last, so which one leaves the reminder paused. Titles likewise.
    /// SwiftData hands relationships back in any order, so this runs a few times.
    @Test(arguments: 1...5)
    func historyRecordsWithEqualTimesKeepTheirOrder(_ attempt: Int) throws {
        let instant = NewYork.local(2026, 10, 15, 9, 40)
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        let history = ReminderHistory(
            pauseSpans: [PauseSpan(start: instant, end: instant), PauseSpan(start: instant)],
            replacedTitles: [Replaced(value: "Pills", replacedAt: instant), Replaced(value: "Take pills", replacedAt: instant)]
        )
        let saved = StoredData(reminders: [pills], tags: [], histories: [pills.id: history])

        try store().save(saved)

        #expect(try store().load() == saved)
    }

    /// RRULE text keeps UNTIL to the second, but the rule's own instant is what the engine reads.
    @Test func aRepeatEndingAtAnInstantKeepsItExactly() throws {
        let until = NewYork.local(2026, 12, 31, 23, 59).addingTimeInterval(59.5)
        let rule = RepeatRule(frequency: .daily, end: .untilTime(until))
        let reminder = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15), repeatRule: rule, strength: .gentle)

        try store().save(StoredData(reminders: [reminder], tags: [], histories: [:]))

        #expect(try store().load().reminders.first?.repeatRule == rule)
    }

    /// The engine keeps the history of a reminder dropped without Delete (ticket 12), but the
    /// store keeps only reminders it holds: a history with no reminder isn't saved.
    @Test func aHistoryWithNoReminderIsNotSaved() throws {
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        let paused = ReminderHistory(pauseSpans: [PauseSpan(start: NewYork.local(2026, 10, 15, 8))])

        try store().save(StoredData(reminders: [pills], tags: [], histories: [UUID(): paused]))

        #expect(try store().load() == StoredData(reminders: [pills], tags: [], histories: [:]))
    }

    /// `update(reminders:)` isn't checked, so a list could hold an ID twice. The save is turned
    /// down whole rather than writing two records for one reminder.
    @Test func aSaveWithAReminderIDTwiceIsTurnedDownAndChangesNothing() throws {
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        let saved = StoredData(reminders: [pills], tags: [], histories: [:])
        try store().save(saved)
        var renamed = pills
        renamed.title = "Take the blue pills"

        #expect(throws: StoreError.duplicateID(pills.id)) {
            try store().save(StoredData(reminders: [renamed, pills], tags: [], histories: [:]))
        }
        #expect(try store().load() == saved)
    }

    @Test func aSaveWithATagIDTwiceIsTurnedDown() throws {
        let home = Tag(name: "home")

        #expect(throws: StoreError.duplicateID(home.id)) {
            try store().save(StoredData(reminders: [], tags: [home, home], histories: [:]))
        }
    }

    @Test(arguments: [Strength.gentle, .firm, .relentless])
    func everyStrengthReadsBackTheSame(_ strength: Strength) throws {
        let reminder = Reminder(title: "Stretch", dueTime: NewYork.local(2026, 10, 15), strength: strength)

        try store().save(StoredData(reminders: [reminder], tags: [], histories: [:]))

        #expect(try store().load().reminders.first?.strength == strength)
    }

    /// A reminder's pace is saved with it (enhancement-pace ticket 04).
    @Test(arguments: [Pace.escalating])
    func aReminderPaceSurvivesASaveAndReload(_ pace: Pace) throws {
        let reminder = Reminder(title: "Stretch", dueTime: NewYork.local(2026, 10, 15), strength: .firm, pace: pace)

        try store().save(StoredData(reminders: [reminder], tags: [], histories: [:]))

        #expect(try store().load().reminders.first?.pace == pace)
    }

    /// A pace kind the store can't map back is an error, not a reminder that quietly nudges
    /// another way.
    @Test func aPaceKindTheStoreCantMapBackIsUnreadable() throws {
        let reminder = Reminder(title: "Stretch", dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        try store().save(StoredData(reminders: [reminder], tags: [], histories: [:]))
        let container = try ModelContainer(
            for: ReminderRecord.self, ClosedOccurrenceRecord.self, PauseSpanRecord.self, ReplacedTitleRecord.self, TagRecord.self,
            configurations: ReminderStore.configuration(for: .file(fileURL))
        )
        for record in try container.mainContext.fetch(FetchDescriptor<ReminderRecord>()) {
            record.paceKind = "gallop"
        }
        try container.mainContext.save()

        #expect(throws: StoreError.unreadable(field: .paceKind, value: "gallop")) {
            try store().load()
        }
    }

    /// Every state a closing can hold, including Nudging, which a closing never has but the
    /// engine's type allows.
    @Test(arguments: [
        OccurrenceState.done, .missed(reason: .giveUpLimit), .missed(reason: .nextTookOver), .skipped(reason: .paused),
        .nudging(nudgeNumber: 4),
    ])
    func everyClosedStateReadsBackTheSame(_ state: OccurrenceState) throws {
        let reminder = Reminder(title: "Stretch", dueTime: NewYork.local(2026, 10, 15), strength: .firm)
        let closing = Closing(state: state, closedAt: NewYork.local(2026, 10, 15, 10), nudgesSent: 4)
        let saved = StoredData(reminders: [reminder], tags: [], histories: [reminder.id: ReminderHistory(closedOccurrences: [reminder.dueTime: closing])])

        try store().save(saved)

        #expect(try store().load() == saved)
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

        try store().save(StoredData(reminders: [reminder], tags: [], histories: [:]))

        #expect(try store().load().reminders.first?.repeatRule == rule)
    }
}
