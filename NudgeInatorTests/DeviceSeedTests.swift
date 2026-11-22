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

    @Test(arguments: AlarmSound.allCases)
    func aDefaultAlarmSoundSurvivesBeingWrittenAndRead(sound: AlarmSound) {
        #expect(SeedSettingText.defaultAlarmSound(from: SeedSettingText.text(of: sound)) == sound)
    }

    /// #228's phone check starts on Default Alarm.
    @Test func theAlarmSoundSetStartsOnDefaultAlarm() throws {
        let set = try #require(SeedSet.all.first { $0.name == "alarm-sound" })
        let text = try #require(set.settings[.defaultAlarmSound])
        #expect(SeedSettingText.defaultAlarmSound(from: text) == .default)
    }

    @Test func quietHoursSurviveBeingWrittenAndRead() throws {
        let schedules = QuietHours(schedules: [
            try QuietHoursSchedule(start: TimeOfDay(hour: 22), end: TimeOfDay(hour: 7), days: [.sunday, .thursday]),
            try QuietHoursSchedule(start: TimeOfDay(hour: 18, minute: 30), end: TimeOfDay(hour: 21), days: [.tuesday], isOn: false),
        ])
        // The text holds no identity: a seed's schedules are new ones, with the same fields.
        let read = try #require(SeedSettingText.quietHours(from: SeedSettingText.text(of: schedules)))
        #expect(read.schedules.map(\.start) == schedules.schedules.map(\.start))
        #expect(read.schedules.map(\.end) == schedules.schedules.map(\.end))
        #expect(read.schedules.map(\.days) == schedules.schedules.map(\.days))
        #expect(read.schedules.map(\.isOn) == schedules.schedules.map(\.isOn))
        #expect(SeedSettingText.quietHours(from: SeedSettingText.text(of: QuietHours())) == QuietHours())
    }

    /// #370's phone check: two schedules on and one off, and a set with none for the empty state.
    @Test func theQuietHoursSetsAreOnesTheAppReads() throws {
        let page = try #require(SeedSet.all.first { $0.name == "quiet-hours-page" })
        let pageText = try #require(page.settings[.quietHours])
        let schedules = try #require(SeedSettingText.quietHours(from: pageText))
        #expect(schedules.schedules.map(\.isOn) == [true, true, false])
        let none = try #require(SeedSet.all.first { $0.name == "quiet-hours-none" })
        let noneText = try #require(none.settings[.quietHours])
        #expect(SeedSettingText.quietHours(from: noneText) == QuietHours())
    }

    /// #468's phone check: the tutorial unseen, so the Quiet Hours page opens it, over the page's
    /// three schedules.
    @Test func theQuietHoursTutorialSetLeavesTheTutorialUnseenOverThePagesSchedules() throws {
        let set = try #require(SeedSet.all.first { $0.name == "quiet-hours-tutorial" })
        let page = try #require(SeedSet.all.first { $0.name == "quiet-hours-page" })
        #expect(set.settings[.quietHoursTutorial] == "unseen")
        #expect(set.settings[.quietHours] == page.settings[.quietHours])
        #expect(set.reminders.isEmpty)
    }

    @Test func textTheAppDoesntKnowIsIgnored() {
        #expect(SeedSettingText.quietHours(from: "25:00-07:00 SU on") == nil)
        #expect(SeedSettingText.quietHours(from: "22:00-22:00 SU on") == nil)
        #expect(SeedSettingText.defaultAlarmSound(from: "foghorn") == nil)
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

    func launchedModel(store: ReminderStore, quietHoursTutorial: QuietHoursTutorialRecord = .temporary) async -> AppModel {
        let model = AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: FakeNotificationCenter(), clock: clock),
            alarms: AlarmAdapter(manager: FakeAlarmManager(), clock: clock),
            settingsRecords: .temporary(),
            doneQueue: .temporary,
            quietHoursTutorial: quietHoursTutorial,
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

    /// The set makes the tutorial unseen, and `clean` puts back what the phone had: seen.
    @Test func theTutorialsFlagIsSetAndPutBackThroughTheModel() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        model.quietHoursTutorialClosed()
        let target = ModelSeedTarget(model: model)
        let set = try #require(SeedSet.all.first { $0.name == "quiet-hours-tutorial" })
        let record = MemorySeedRecordStore()
        let schedules = model.quietHours

        #expect(DeviceSeed.run(command: set.name, sets: [set], on: target, record: record) == .loaded(set.name))
        #expect(model.isQuietHoursTutorialDue)

        _ = DeviceSeed.run(command: "clean", sets: [set], on: target, record: record)
        #expect(!model.isQuietHoursTutorialDue)
        #expect(target.setting(.quietHoursTutorial) == "seen")
        #expect(model.quietHours == schedules)
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
