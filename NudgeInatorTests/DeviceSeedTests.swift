#if DEBUG
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The app side of the device seed. The load and removal decisions are tested in the
/// NudgeEngine package's NudgeDeviceSeed tests; this is the setting text and the record's storage.
final class DeviceSeedTests {
    let suiteName = "DeviceSeedTests.\(UUID().uuidString)"

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    @Test(arguments: [
        RemindersSort(field: .created, order: .ascending),
        RemindersSort(field: .dueDate, order: .descending),
    ])
    func aSortSurvivesBeingWrittenAndRead(sort: RemindersSort) {
        #expect(SeedSettingText.remindersSort(from: SeedSettingText.text(of: sort)) == sort)
    }

    @Test(arguments: [DefaultPace.shipped, DefaultPace(choice: .escalating, consistentWait: 900)])
    func aDefaultPaceSurvivesBeingWrittenAndRead(pace: DefaultPace) {
        #expect(SeedSettingText.defaultPace(from: SeedSettingText.text(of: pace)) == pace)
    }

    @Test func textTheAppDoesntKnowIsIgnored() {
        #expect(SeedSettingText.remindersSort(from: "title.ascending") == nil)
        #expect(SeedSettingText.remindersSort(from: "created") == nil)
        #expect(SeedSettingText.defaultPace(from: "consistent.7") == nil)
        #expect(SeedSettingText.defaultPace(from: "nonsense.600") == nil)
    }

    @Test func theSearchSetsSortIsOneTheAppReads() throws {
        let search = try #require(SeedSet.all.first { $0.name == "search" })
        let text = try #require(search.settings[.remindersSort])
        #expect(SeedSettingText.remindersSort(from: text) != nil)
    }

    @Test func theRecordSurvivesInTheDefaults() throws {
        let store = UserDefaultsSeedRecordStore(defaults: try #require(UserDefaults(suiteName: suiteName)))
        var record = SeedRecord()
        record.sets["search"] = SeedRecord.Loaded(
            reminderIDs: [UUID()], createdTagIDs: [UUID()], earlierSettings: ["remindersSort": "created.ascending"]
        )

        store.write(record)

        #expect(store.read() == record)
        store.write(SeedRecord())
        #expect(store.read() == SeedRecord())
    }
}

/// The seed target over a real model, so a seeded reminder takes the path a reminder made by hand
/// takes (#248): the engine stamps those with now, but a seeded one keeps the creation date its
/// set gives it, so the Created sort has dates to sort by.
@MainActor
struct ModelSeedTargetTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))

    func launchedModel(store: ReminderStore) async -> AppModel {
        let model = AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: FakeNotificationCenter(), clock: clock),
            alarms: AlarmAdapter(manager: FakeAlarmManager(), clock: clock),
            defaultPaceRecord: .temporary,
            remindersSortRecord: .temporary,
            tagsSortRecord: .temporary,
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
        await model.launch()
        return model
    }

    @Test func aSeededReminderKeepsItsCreationDateInTheEngineAndTheStore() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)
        let created = NewYork.local(2026, 10, 1, 9)
        let reminder = Reminder(
            title: "Seeded", dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle,
            breakThroughFocus: false, createdAt: created
        )

        ModelSeedTarget(model: model).add(reminder)

        #expect(try #require(model.engine.reminders.first { $0.id == reminder.id }).createdAt == created)
        #expect(try store.load().reminders.first { $0.id == reminder.id }?.createdAt == created)
    }

    @Test func aSetLoadedThroughTheModelGivesEachReminderItsOwnCreationDate() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        let target = ModelSeedTarget(model: model)
        let set = try #require(SeedSet.all.first { $0.name == "due-dates" })

        let before = Date()
        let outcome = DeviceSeed.run(command: set.name, sets: [set], on: target, record: MemorySeedRecordStore())
        let after = Date()

        #expect(outcome == .loaded(set.name))
        for seed in set.reminders {
            let created = try #require(model.engine.reminders.first { $0.id == seed.id }).createdAt
            // The target's now is the real clock, read once during the load.
            #expect(created >= before.addingTimeInterval(-seed.createdAgo))
            #expect(created <= after.addingTimeInterval(-seed.createdAgo))
        }
        let created = set.reminders.compactMap { seed in model.engine.reminders.first { $0.id == seed.id }?.createdAt }
        #expect(Set(created).count == set.reminders.count)
    }

    @Test func aReminderMadeByHandIsStillStampedWithNow() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        let reminder = Reminder(
            title: "By hand", dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle,
            breakThroughFocus: false, createdAt: NewYork.local(2026, 10, 1, 9)
        )

        model.add(reminder)

        #expect(try #require(model.engine.reminders.first { $0.id == reminder.id }).createdAt == clock.now)
    }
}

private final class MemorySeedRecordStore: SeedRecordStore {
    var record = SeedRecord()
    func read() -> SeedRecord { record }
    func write(_ record: SeedRecord) { self.record = record }
}
#endif
