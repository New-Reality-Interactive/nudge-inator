import Foundation
import Testing
import NudgeEngine
import SwiftData
@testable import NudgeInator

/// 1.5.0 opens 1.4.0's store (schema version 3) under schema version 4, which adds a reminder's
/// alarm sound. Each test writes a file with version 3's schema, then opens it as a relaunch would.
/// Every reminder comes up on Default and nothing else in the file changes.
@MainActor
struct Version3StoreMigrationTests: StoreFixtured {
    let fixtures = StoreFixtures()
    let storeFile = TemporaryStoreFile()
    let updateInstant = NewYork.local(2026, 11, 20, 12)

    let received = Reminder(
        title: "Call Gran",
        dueTime: NewYork.local(2026, 10, 17, 18),
        strength: .gentle,
        createdAt: NewYork.local(2026, 10, 3, 8),
        origin: .received(connectionID: UUID(), sendersReminderID: UUID(), revision: 2, state: .accepted, originalDueTime: NewYork.local(2026, 10, 17, 17))
    )

    /// Reminders, tags, histories, IDs, order and origins are as 1.4.0 saved them; the sound is the
    /// one thing the update adds, and it is Default.
    @Test func aVersion3StoreOpensWithEverythingKeptAndEveryReminderOnDefault() throws {
        try Version3Store.write(to: fileURL, reminders: [pills, bins, received], tags: [home, health], histories: [pills.id: pillsHistory])

        let loaded = try openAfterUpdate().load()

        #expect(loaded == StoredData(reminders: [pills, bins, received], tags: [home, health], histories: [pills.id: pillsHistory]))
        #expect(loaded.reminders.allSatisfy { $0.alarmSound == .default })
    }

    /// The update stores Default as the sound's ID for every reminder, so a later build that reads the
    /// field directly finds the same thing the app does.
    @Test func aVersion3StoreHoldsTheDefaultSoundIDForEveryReminderAfterTheUpdate() throws {
        try Version3Store.write(to: fileURL, reminders: [pills, bins, received], tags: [], histories: [:])
        _ = try openAfterUpdate()

        let container = try openStoredRecords(at: fileURL)
        let records = try container.mainContext.fetch(FetchDescriptor<ReminderRecord>())
        #expect(records.count == 3)
        #expect(records.allSatisfy { $0.alarmSoundID == "default" })
    }

    @Test func aVersion3StoreKeepsEveryIDPositionAndCreationDate() throws {
        try Version3Store.write(to: fileURL, reminders: [received, pills, bins], tags: [health, home], histories: [:])

        let loaded = try openAfterUpdate().load()

        #expect(loaded.reminders.map(\.id) == [received.id, pills.id, bins.id])
        #expect(loaded.reminders.map(\.createdAt) == [received.createdAt, pills.createdAt, bins.createdAt])
        #expect(loaded.tags.map(\.id) == [health.id, home.id])
    }

    /// The same plan from the same reminders: every notification and alarm identifier comes from it,
    /// so none changes and nothing is re-planned.
    @Test func theEnginesPlanOverAVersion3StoresRemindersEqualsThePlanOverTheOnesWrittenIntoIt() throws {
        try Version3Store.write(to: fileURL, reminders: [pills, bins, received], tags: [home, health], histories: [pills.id: pillsHistory])
        func plan(of reminders: [Reminder]) throws -> SchedulePlan {
            let scheduler = FakeScheduler()
            var engine = Engine(clock: FakeClock(now: NewYork.local(2026, 10, 20, 8)), scheduler: scheduler, timeZone: NewYork.timeZone)
            engine.update(reminders: reminders)
            return try #require(scheduler.lastPlan)
        }

        let loaded = try openAfterUpdate().load()

        #expect(try plan(of: loaded.reminders) == plan(of: [pills, bins, received]))
        #expect(try !plan(of: loaded.reminders).items.isEmpty)
    }

    @Test func aVersion2StoreStillOpensThroughEveryStage() throws {
        try Version2Store.write(to: fileURL, reminders: [pills, bins], tags: [home], histories: [:])

        let loaded = try openAfterUpdate().load()

        #expect(loaded.reminders.map(\.id) == [pills.id, bins.id])
        #expect(loaded.reminders.allSatisfy { $0.origin == .mine && $0.alarmSound == .default })
    }

    @Test func aVersion1StoreStillOpensThroughEveryStage() throws {
        try Version1Store.write(to: fileURL, reminders: [bins], tags: [home], histories: [:])

        let loaded = try openAfterUpdate().load()

        #expect(loaded.reminders.map(\.id) == [bins.id])
        #expect(loaded.reminders.allSatisfy { $0.createdAt == updateInstant && $0.alarmSound == .default })
    }
}
