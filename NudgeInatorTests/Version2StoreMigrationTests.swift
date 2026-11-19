import Foundation
import Testing
import NudgeEngine
import SwiftData
@testable import NudgeInator

/// 1.4.0 opens 1.3.0's store (schema version 2) under schema version 3, which adds a received
/// reminder's origin. Each test writes a file with version 2's schema, then opens it as a relaunch
/// would. Nothing in the file changes for a reminder of the person's own.
@MainActor
struct Version2StoreMigrationTests: StoreFixtured {
    let fixtures = StoreFixtures()
    let storeFile = TemporaryStoreFile()
    let updateInstant = NewYork.local(2026, 11, 10, 12)

    @Test func aVersion2StoreOpensWithEveryReminderHistoryAndTagKeptAndEveryReminderMine() throws {
        try Version2Store.write(to: fileURL, reminders: [pills, bins, rent], tags: [home, health], histories: [pills.id: pillsHistory])

        let loaded = try openAfterUpdate().load()

        #expect(loaded == StoredData(reminders: [pills, bins, rent], tags: [home, health], histories: [pills.id: pillsHistory]))
        #expect(loaded.reminders.allSatisfy { $0.origin == .mine })
    }

    /// The update stores no origin for a reminder of the person's own: every origin field in the
    /// migrated file is empty, not only read back as mine.
    @Test func aVersion2StoreHoldsNoOriginValueAfterTheUpdate() throws {
        try Version2Store.write(to: fileURL, reminders: [pills, bins, rent], tags: [], histories: [:])
        _ = try openAfterUpdate()

        let container = try openStoredRecords(at: fileURL)
        let records = try container.mainContext.fetch(FetchDescriptor<ReminderRecord>())
        #expect(records.count == 3)
        #expect(records.allSatisfy {
            $0.receivedConnectionID == nil && $0.receivedSendersReminderID == nil && $0.receivedRevision == nil
                && $0.receivedState == nil && $0.receivedOriginalDueTime == nil
        })
    }

    /// IDs, positions and creation dates are exactly what 1.3.0 saved: the update stamps nothing,
    /// since every 1.3.0 reminder already has a creation date.
    @Test func aVersion2StoreKeepsEveryIDPositionAndCreationDate() throws {
        try Version2Store.write(to: fileURL, reminders: [rent, pills, bins], tags: [health, home], histories: [:])

        let loaded = try openAfterUpdate().load()

        #expect(loaded.reminders.map(\.id) == [rent.id, pills.id, bins.id])
        #expect(loaded.reminders.map(\.createdAt) == [rent.createdAt, pills.createdAt, bins.createdAt])
        #expect(loaded.tags.map(\.id) == [health.id, home.id])
    }

    /// The same plan from the same reminders: every notification and alarm identifier comes from it,
    /// so none changes and nothing is re-planned.
    @Test func theEnginesPlanOverAVersion2StoresRemindersEqualsThePlanOverTheOnesWrittenIntoIt() throws {
        try Version2Store.write(to: fileURL, reminders: [pills, bins, rent], tags: [home, health], histories: [pills.id: pillsHistory])
        let loaded = try openAfterUpdate().load()

        #expect(try enginePlan(of: loaded.reminders) == enginePlan(of: [pills, bins, rent]))
        #expect(try !enginePlan(of: loaded.reminders).items.isEmpty)
    }

    @Test func aVersion1StoreStillOpensThroughBothStages() throws {
        try Version1Store.write(to: fileURL, reminders: [bins, rent], tags: [home], histories: [:])

        let loaded = try openAfterUpdate().load()

        #expect(loaded.reminders.map(\.id) == [bins.id, rent.id])
        #expect(loaded.reminders.allSatisfy { $0.origin == .mine && $0.createdAt == updateInstant })
    }
}
