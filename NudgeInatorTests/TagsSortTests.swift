import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Tags tab's Sort menu choice (#140): what it reads with nothing stored, after a relaunch and
/// after Delete All Data, and that it's kept apart from the Reminders tab's. A class so `deinit`
/// removes the defaults each test wrote, even when it fails. Prior art: `RemindersSortTests`.
@MainActor
final class TagsSortTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let suiteName = "TagsSortTests.\(UUID().uuidString)"

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: suiteName))
    }

    /// A record over this test's defaults, as each launch makes one.
    func record() throws -> TagsSortRecord {
        TagsSortRecord(defaults: try defaults())
    }

    func remindersRecord() throws -> RemindersSortRecord {
        RemindersSortRecord(defaults: try defaults())
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
            remindersSortRecord: try remindersRecord(),
            tagsSortRecord: try record(),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
    }

    @Test func withNothingStoredItIsNameAToZ() throws {
        #expect(try record().sort == TagSort(field: .name, order: .ascending))
    }

    @Test(arguments: [
        TagSort(field: .name, order: .descending),
        TagSort(field: .reminderCount, order: .ascending),
        TagSort(field: .reminderCount, order: .descending),
    ])
    func aChosenSortSurvivesARelaunch(_ sort: TagSort) throws {
        try record().sort = sort

        #expect(try record().sort == sort)
    }

    @Test func aStoredValueThisVersionDoesntKnowReadsAsNameAToZ() throws {
        try defaults().set("colour", forKey: "tagsSortField")
        try defaults().set("sideways", forKey: "tagsSortOrder")

        #expect(try record().sort == TagSort(field: .name, order: .ascending))
    }

    @Test func itIsKeptApartFromTheRemindersSort() throws {
        let reminders = RemindersSort(field: .dueDate, order: .descending)
        try remindersRecord().sort = reminders

        try record().sort = TagSort(field: .reminderCount, order: .descending)

        #expect(try remindersRecord().sort == reminders)
        #expect(try record().sort == TagSort(field: .reminderCount, order: .descending))
    }

    @Test func theModelReadsAndWritesTheRecord() async throws {
        let model = try model()
        await model.launch()

        model.tagsSort = TagSort(field: .reminderCount, order: .descending)

        #expect(try record().sort == TagSort(field: .reminderCount, order: .descending))
        try record().sort = TagSort(field: .name, order: .descending)
        #expect(model.tagsSort == TagSort(field: .name, order: .descending))
    }

    @Test func deleteAllDataSetsTheSortBackToNameAToZ() async throws {
        let model = try model()
        await model.launch()
        model.tagsSort = TagSort(field: .reminderCount, order: .descending)

        try await model.deleteAllData()

        #expect(model.tagsSort == TagSort(field: .name, order: .ascending))
        #expect(try record().sort == TagSort(field: .name, order: .ascending))
    }
}
