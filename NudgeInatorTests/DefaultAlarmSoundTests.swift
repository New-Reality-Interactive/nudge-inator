import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Settings' Default Alarm Sound (#228): what it reads with nothing stored, after a relaunch and
/// after Delete All Data, and that changing it leaves the reminders already made alone. A class
/// so `deinit` removes the defaults each test wrote, even when it fails.
@MainActor
final class DefaultAlarmSoundTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let center = FakeNotificationCenter()
    let manager = FakeAlarmManager()
    let suiteName = "DefaultAlarmSoundTests.\(UUID().uuidString)"

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: suiteName))
    }

    /// A model over this test's defaults, not yet launched, as before the store is read.
    func model() throws -> AppModel {
        let store = try ReminderStore(location: .inMemory)
        return AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: center, clock: clock),
            alarms: AlarmAdapter(manager: manager, clock: clock),
            settingsRecords: .temporary(defaultAlarmSound: DefaultAlarmSoundRecord(defaults: try defaults())),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
    }

    @Test func withNothingStoredItIsDefaultAlarm() async throws {
        let model = try model()
        await model.launch()

        #expect(model.defaultAlarmSound == .default)
    }

    /// A relaunch makes a new model over the same defaults.
    @Test(arguments: AlarmSound.allCases)
    func aChosenSoundSurvivesARelaunch(sound: AlarmSound) async throws {
        let before = try model()
        await before.launch()
        before.defaultAlarmSound = sound

        let after = try model()
        await after.launch()

        #expect(after.defaultAlarmSound == sound)
    }

    /// A newer build may save a sound this one doesn't know.
    @Test func anUnknownSavedSoundReadsAsDefaultAlarm() async throws {
        try defaults().set("foghorn", forKey: DefaultAlarmSoundRecord.key)
        let model = try model()
        await model.launch()

        #expect(model.defaultAlarmSound == .default)
    }

    /// Before the first unlock `UserDefaults` reads as empty, so the model reads it when asked,
    /// as it does the Default Pace.
    @Test func theModelReadsTheSoundWhenAskedNotAtLaunch() async throws {
        let model = try model()
        await model.launch()

        try defaults().set(AlarmSound.siren.id, forKey: DefaultAlarmSoundRecord.key)

        #expect(model.defaultAlarmSound == .siren)
    }

    @Test func deleteAllDataSetsItBackToDefaultAlarm() async throws {
        let model = try model()
        await model.launch()
        model.defaultAlarmSound = .bell

        try await model.deleteAllData()

        #expect(model.defaultAlarmSound == .default)
        #expect(try defaults().string(forKey: DefaultAlarmSoundRecord.key) == nil)
    }

    /// Spec story 8: each reminder keeps its own sound.
    @Test func changingItLeavesEveryReminderAsItWas() async throws {
        let model = try model()
        await model.launch()
        model.add(Reminder(title: "Stretch", dueTime: NewYork.local(2026, 10, 16, 9), strength: .relentless, alarmSound: .chime))
        model.add(Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 16, 10), strength: .relentless))

        model.defaultAlarmSound = .siren

        #expect(model.engine.reminders.map(\.alarmSound) == [.chime, .default])
    }

    /// The picker's rows in order, the engine's Default named Default Alarm (#223's review).
    @Test func theSoundsAreNamedInThePickersOrder() {
        let names = AlarmSound.allCases.map { String(localized: $0.title) }

        #expect(names == ["Default Alarm", "Chime", "Bell", "Pulse", "Beacon", "Rise", "Siren"])
    }
}
