import Foundation
import Testing
@testable import NudgeInator

/// How Quiet Hours Work opening by itself the first time the Quiet Hours page opens (#468): through
/// the app model, with the tutorial's seen-flag in this test's own defaults suite. What a test
/// asserts is whether the tutorial is due, and what the flag keeps. That the sheet opens over the
/// Quiet Hours page is the phone check. A class so `deinit` removes the defaults each test wrote,
/// even when it fails.
@MainActor
final class QuietHoursTutorialFirstTimeTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let suiteName = "QuietHoursTutorialFirstTimeTests.\(UUID().uuidString)"

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    /// A model over this test's defaults, as each launch makes one.
    func model() throws -> AppModel {
        let store = try ReminderStore(location: .inMemory)
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: FakeNotificationCenter(), clock: clock),
            alarms: AlarmAdapter(manager: FakeAlarmManager(), clock: clock),
            settingsRecords: SettingsRecords(defaults: defaults),
            doneQueue: .temporary,
            quietHoursTutorial: QuietHoursTutorialRecord(defaults: defaults),
            timeZone: NewYork.timeZone
        )
    }

    @Test func itIsDueUntilItHasBeenSeen() throws {
        #expect(try model().isQuietHoursTutorialDue)
    }

    /// Close, Done and a swipe all close the sheet, which is what the model hears.
    @Test func onceClosedItIsNeverDueAgain() throws {
        let model = try model()

        model.quietHoursTutorialClosed()

        #expect(!model.isQuietHoursTutorialDue)
    }

    /// A relaunch, and an update, which is a relaunch of a newer app over the same defaults.
    @Test func onceClosedItIsNotDueAfterARelaunchOrAnUpdate() throws {
        try model().quietHoursTutorialClosed()

        #expect(try !model().isQuietHoursTutorialDue)
    }

    /// Like How Sharing Works' flag, it isn't the person's data: Delete All Data leaves it seen.
    @Test func deleteAllDataLeavesItSeen() async throws {
        let model = try model()
        await model.launch()
        model.quietHoursTutorialClosed()

        try await model.deleteAllData()

        #expect(!model.isQuietHoursTutorialDue)
    }
}
