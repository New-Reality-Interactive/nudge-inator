import Foundation
import Testing
import NudgeEngine
import SwiftData
@testable import NudgeInator

/// 1.3.0 opens 1.2.0's store (schema version 1) under schema version 2, which adds the creation
/// date. Each test writes a file with version 1's schema, then opens it as a relaunch would.
@MainActor
struct StoreMigrationTests {
    let storeFile = TemporaryStoreFile()
    var fileURL: URL { storeFile.url }

    let home = Tag(name: "home")
    let health = Tag(name: "health")
    let pills = Reminder(
        title: "Take the pills",
        notes: "With food",
        tagIDs: [UUID(), UUID()],
        dueTime: NewYork.local(2026, 10, 15, 9),
        repeatRule: .everyDay,
        strength: .firm,
        pace: .consistent(wait: 300),
        breakThroughFocus: false
    )
    let bins = Reminder(title: "Put the bins out", dueTime: NewYork.local(2026, 10, 16, 19), strength: .relentless)
    let rent = Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 11, 1, 9), strength: .gentle)
    let migrationInstant = NewYork.local(2026, 10, 30, 12)

    /// What 1.2.0 saved for `pills`: one closed occurrence, two pauses (one open), a replaced title.
    var pillsHistory: ReminderHistory {
        ReminderHistory(
            closedOccurrences: [
                NewYork.local(2026, 10, 15, 9): Closing(state: .done, closedAt: NewYork.local(2026, 10, 15, 9, 5), nudgesSent: 1),
                NewYork.local(2026, 10, 16, 9): Closing(state: .missed(reason: .giveUpLimit), closedAt: NewYork.local(2026, 10, 16, 11), nudgesSent: 20),
            ],
            editAppliesAfter: NewYork.local(2026, 10, 16, 9),
            pauseSpans: [
                PauseSpan(start: NewYork.local(2026, 10, 17, 8), end: NewYork.local(2026, 10, 18, 8)),
                PauseSpan(start: NewYork.local(2026, 10, 19, 8)),
            ],
            replacedTitles: [Replaced(value: "Take the blue pills", replacedAt: NewYork.local(2026, 10, 14, 7))]
        )
    }

    func openAfterUpdate() throws -> ReminderStore {
        try ReminderStore(location: .file(fileURL), now: migrationInstant)
    }

    @Test func aVersion1StoreOpensWithEveryReminderHistoryAndTagKept() throws {
        try Version1Store.write(to: fileURL, reminders: [pills, bins, rent], tags: [home, health], histories: [pills.id: pillsHistory])

        let loaded = try openAfterUpdate().load()

        func stamped(_ reminder: Reminder) -> Reminder {
            var reminder = reminder
            reminder.createdAt = migrationInstant
            return reminder
        }
        #expect(loaded == StoredData(
            reminders: [pills, bins, rent].map(stamped),
            tags: [home, health],
            histories: [pills.id: pillsHistory]
        ))
    }

    @Test func everyMigratedReminderGetsTheMigrationInstantAndKeepsItsPosition() throws {
        try Version1Store.write(to: fileURL, reminders: [rent, pills, bins], tags: [], histories: [:])

        let loaded = try openAfterUpdate().load()

        #expect(loaded.reminders.map(\.id) == [rent.id, pills.id, bins.id])
        #expect(loaded.reminders.map(\.createdAt) == Array(repeating: migrationInstant, count: 3))
    }

    @Test func theMigrationInstantIsSavedOnceAndALaterLaunchLeavesItAlone() throws {
        try Version1Store.write(to: fileURL, reminders: [pills, bins], tags: [], histories: [:])
        _ = try openAfterUpdate().load()

        let later = try ReminderStore(location: .file(fileURL), now: migrationInstant.addingTimeInterval(86_400)).load()

        #expect(later.reminders.map(\.createdAt) == [migrationInstant, migrationInstant])
    }

    @Test func aReminderMadeAfterTheUpdateSortsAfterTheMigratedOnes() throws {
        try Version1Store.write(to: fileURL, reminders: [pills, bins], tags: [], histories: [:])
        let store = try openAfterUpdate()
        var data = try store.load()
        var added = rent
        added.createdAt = migrationInstant.addingTimeInterval(60)
        data.reminders.append(added)

        try store.save(data)

        let loaded = try ReminderStore(location: .file(fileURL), now: migrationInstant.addingTimeInterval(86_400)).load()
        #expect(loaded.reminders.map(\.id) == [pills.id, bins.id, rent.id])
        #expect(loaded.reminders.map(\.createdAt) == [migrationInstant, migrationInstant, added.createdAt])
    }

    @Test func anEmptyVersion1StoreOpensEmpty() throws {
        try Version1Store.write(to: fileURL, reminders: [], tags: [], histories: [:])

        #expect(try openAfterUpdate().load() == StoredData(reminders: [], tags: [], histories: [:]))
    }
}
