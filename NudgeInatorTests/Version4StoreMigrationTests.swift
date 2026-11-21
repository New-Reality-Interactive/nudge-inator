import Foundation
import Testing
import NudgeEngine
import SwiftData
@testable import NudgeInator

/// 1.6.0 opens 1.5.0's store (schema version 4) under schema version 5, which adds how many of a
/// fixed closing's nudges quiet hours held. Each test writes a file with version 4's schema, then
/// opens it as a relaunch would. Every closing comes up with no held count, which the engine reads
/// as none held, and nothing else in the file changes.
@MainActor
struct Version4StoreMigrationTests: StoreFixtured {
    let fixtures = StoreFixtures()
    let storeFile = TemporaryStoreFile()
    let updateInstant = NewYork.local(2026, 11, 25, 12)

    let siren = Reminder(
        title: "Wake up",
        dueTime: NewYork.local(2026, 10, 17, 7),
        strength: .relentless,
        alarmSound: .siren,
        createdAt: NewYork.local(2026, 10, 3, 8),
        origin: .received(connectionID: UUID(), sendersReminderID: UUID(), revision: 2, state: .accepted)
    )

    /// Reminders, tags, histories, IDs, order, origins and sounds are as 1.5.0 saved them, and every
    /// closing has no held count, as `pillsHistory`'s don't.
    @Test func aVersion4StoreOpensWithEverythingKept() throws {
        try Version4Store.write(to: fileURL, reminders: [pills, bins, siren], tags: [home, health], histories: [pills.id: pillsHistory])

        let loaded = try openAfterUpdate().load()

        #expect(loaded == StoredData(reminders: [pills, bins, siren], tags: [home, health], histories: [pills.id: pillsHistory]))
        #expect(loaded.histories[pills.id]?.closedOccurrences.values.allSatisfy { $0.nudgesHeld == nil } == true)
    }

    /// The lightweight stage leaves the new field empty in the file itself.
    @Test func aVersion4StoreHoldsNoHeldCountAfterTheUpdate() throws {
        try Version4Store.write(to: fileURL, reminders: [pills], tags: [], histories: [pills.id: pillsHistory])
        _ = try openAfterUpdate()

        let container = try openStoredRecords(at: fileURL)
        let records = try container.mainContext.fetch(FetchDescriptor<ClosedOccurrenceRecord>())
        #expect(records.count == 2)
        #expect(records.allSatisfy { $0.nudgesHeld == nil })
    }

    /// The same plan from the same reminders: every notification and alarm identifier comes from it,
    /// so none changes and nothing is re-planned.
    @Test func theEnginesPlanOverAVersion4StoresRemindersEqualsThePlanOverTheOnesWrittenIntoIt() throws {
        try Version4Store.write(to: fileURL, reminders: [pills, bins, siren], tags: [home, health], histories: [pills.id: pillsHistory])
        let loaded = try openAfterUpdate().load()

        #expect(try enginePlan(of: loaded.reminders) == enginePlan(of: [pills, bins, siren]))
        #expect(try !enginePlan(of: loaded.reminders).items.isEmpty)
    }

    @Test func aVersion3StoreStillOpensThroughEveryStage() throws {
        try Version3Store.write(to: fileURL, reminders: [pills, bins], tags: [home], histories: [pills.id: pillsHistory])

        let loaded = try openAfterUpdate().load()

        #expect(loaded.reminders.map(\.id) == [pills.id, bins.id])
        #expect(loaded.histories[pills.id] == pillsHistory)
    }

    @Test func aVersion1StoreStillOpensThroughEveryStage() throws {
        try Version1Store.write(to: fileURL, reminders: [bins], tags: [home], histories: [:])

        let loaded = try openAfterUpdate().load()

        #expect(loaded.reminders.map(\.id) == [bins.id])
        #expect(loaded.reminders.allSatisfy { $0.createdAt == updateInstant && $0.alarmSound == .default })
    }
}
