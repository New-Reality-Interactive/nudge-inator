import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Settings' Default Pace (ticket 09): what it reads with nothing stored, after a relaunch and
/// after Delete All Data, and that changing it leaves the reminders already made alone. A class
/// so `deinit` removes the defaults each test wrote, even when it fails.
@MainActor
final class DefaultPaceTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let center = FakeNotificationCenter()
    let manager = FakeAlarmManager()
    let suiteName = "DefaultPaceTests.\(UUID().uuidString)"

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    /// A record over this test's defaults, as each launch makes one.
    func record() throws -> DefaultPaceRecord {
        DefaultPaceRecord(defaults: try #require(UserDefaults(suiteName: suiteName)))
    }

    /// A model over this test's defaults, not yet launched, as before the store is read.
    func model() throws -> AppModel {
        let store = try ReminderStore(location: .inMemory)
        return AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: center, clock: clock),
            alarms: AlarmAdapter(manager: manager, clock: clock),
            defaultPaceRecord: try record(),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
    }

    @Test func withNothingStoredItIsConsistentEvery10Min() throws {
        let defaultPace = try record().defaultPace

        #expect(defaultPace == DefaultPace(choice: .consistent, consistentWait: 10 * 60))
        #expect(defaultPace.pace == .consistent(wait: 10 * 60))
    }

    /// Escalating keeps the wait chosen for Consistent, as the form's Pace control does.
    @Test func aChosenDefaultPaceSurvivesARelaunch() throws {
        try record().defaultPace = DefaultPace(choice: .escalating, consistentWait: 30 * 60)

        #expect(try record().defaultPace == DefaultPace(choice: .escalating, consistentWait: 30 * 60))
    }

    /// The store reads a reminder with an unlisted wait as unreadable (ticket 07), so a new
    /// reminder must never start with one.
    @Test func aStoredWaitThatIsNotInTheListReadsAs10Min() throws {
        try record().defaultPace = DefaultPace(choice: .consistent, consistentWait: 7 * 60)

        #expect(try record().defaultPace == DefaultPace(choice: .consistent, consistentWait: 10 * 60))
    }

    /// Before the first unlock `UserDefaults` reads as empty, so a value read at launch could be
    /// Consistent · 10 min when the person chose another. The model reads it when asked.
    @Test func theModelReadsTheDefaultPaceWhenAskedNotAtLaunch() async throws {
        let model = try model()
        await model.launch()

        try record().defaultPace = DefaultPace(choice: .escalating, consistentWait: 60 * 60)

        #expect(model.defaultPace == DefaultPace(choice: .escalating, consistentWait: 60 * 60))
    }

    @Test func deleteAllDataSetsTheDefaultPaceBackToConsistentEvery10Min() async throws {
        let model = try model()
        await model.launch()
        model.defaultPace = DefaultPace(choice: .escalating, consistentWait: 60 * 60)

        try await model.deleteAllData()

        #expect(model.defaultPace == DefaultPace(choice: .consistent, consistentWait: 10 * 60))
        #expect(try record().defaultPace == DefaultPace(choice: .consistent, consistentWait: 10 * 60))
    }

    /// Spec story 40: each reminder keeps its own pace.
    @Test func changingTheDefaultPaceLeavesEveryReminderAsItWas() async throws {
        let model = try model()
        await model.launch()
        let form = ReminderForm(engine: { model.engine }, now: { [clock] in clock.now }, defaultPace: model.defaultPace)
        form.title = "Water the plants"
        #expect(form.save(to: model))
        model.add(Reminder(title: "Stretch", dueTime: NewYork.local(2026, 10, 16, 9), strength: .firm, pace: .escalating))

        model.defaultPace = DefaultPace(choice: .consistent, consistentWait: 2 * 60)

        #expect(model.engine.reminders.map(\.pace) == [.consistent(wait: 10 * 60), .escalating])
    }
}
