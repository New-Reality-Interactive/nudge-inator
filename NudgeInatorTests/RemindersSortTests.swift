import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Reminders tab's Sort menu choice (#115): what it reads with nothing stored, after a
/// relaunch and after Delete All Data. A class so `deinit` removes the defaults each test wrote,
/// even when it fails. Prior art: `DefaultPaceTests`.
@MainActor
final class RemindersSortTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let suiteName = "RemindersSortTests.\(UUID().uuidString)"

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    /// A record over this test's defaults, as each launch makes one.
    func record() throws -> RemindersSortRecord {
        RemindersSortRecord(defaults: try #require(UserDefaults(suiteName: suiteName)))
    }

    /// A model over this test's defaults, not yet launched, as before the store is read.
    func model() throws -> AppModel {
        let store = try ReminderStore(location: .inMemory)
        return AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: FakeNotificationCenter(), clock: clock),
            alarms: AlarmAdapter(manager: FakeAlarmManager(), clock: clock),
            defaultPaceRecord: .temporary,
            remindersSortRecord: try record(),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
    }

    @Test func withNothingStoredItIsCreatedOldestFirst() throws {
        #expect(try record().sort == RemindersSort(field: .created, order: .ascending))
    }

    @Test(arguments: [
        RemindersSort(field: .created, order: .descending),
        RemindersSort(field: .dueDate, order: .ascending),
        RemindersSort(field: .dueDate, order: .descending),
    ])
    func aChosenSortSurvivesARelaunch(_ sort: RemindersSort) throws {
        try record().sort = sort

        #expect(try record().sort == sort)
    }

    @Test func theModelReadsAndWritesTheRecord() async throws {
        let model = try model()
        await model.launch()

        model.remindersSort = RemindersSort(field: .dueDate, order: .descending)

        #expect(try record().sort == RemindersSort(field: .dueDate, order: .descending))
        try record().sort = RemindersSort(field: .created, order: .descending)
        #expect(model.remindersSort == RemindersSort(field: .created, order: .descending))
    }

    @Test func deleteAllDataSetsTheSortBackToCreatedOldestFirst() async throws {
        let model = try model()
        await model.launch()
        model.remindersSort = RemindersSort(field: .dueDate, order: .descending)

        try await model.deleteAllData()

        #expect(model.remindersSort == RemindersSort(field: .created, order: .ascending))
        #expect(try record().sort == RemindersSort(field: .created, order: .ascending))
    }
}
