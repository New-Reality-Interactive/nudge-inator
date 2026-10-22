import AlarmKit
import Foundation
import NudgeEngine
import Testing
import UserNotifications
@testable import NudgeInator

/// First launch (ticket 31) through the app model, over the real adapters on the fakes: the
/// welcome, then the notification prompt, then the alarm prompt, and never again once finished.
/// A class so `deinit` removes the defaults each test wrote, even when it fails.
@MainActor
final class OnboardingTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let center = FakeNotificationCenter()
    let manager = FakeAlarmManager()
    let suiteName = "OnboardingTests.\(UUID().uuidString)"

    init() {
        manager.authorizationState = .notDetermined
    }

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    /// A launched model over the shared fakes and this test's defaults, as a relaunch builds it.
    func launchedModel(store: ReminderStore? = nil) async throws -> AppModel {
        let store = try store ?? ReminderStore(location: .inMemory)
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let model = AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: center, clock: clock),
            alarms: AlarmAdapter(manager: manager, clock: clock),
            onboardingRecord: OnboardingRecord(defaults: defaults),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
        await model.launch()
        return model
    }

    @Test func firstLaunchShowsOnboardingOnceAndTheNextLaunchDoesNot() async throws {
        let first = try await launchedModel()
        #expect(first.onboarding == .welcome)

        await first.askForPermissions()
        #expect(first.onboarding == nil)

        let second = try await launchedModel()
        #expect(second.onboarding == nil)
    }

    /// The notification prompt first, then the alarm prompt, and onboarding counts as finished
    /// only after both, so a kill between them shows it again.
    @Test func theNotificationPromptComesBeforeTheAlarmPromptAndOnlyThenIsOnboardingFinished() async throws {
        let model = try await launchedModel()
        let record = OnboardingRecord(defaults: try #require(UserDefaults(suiteName: suiteName)))
        var prompts: [String] = []
        center.whileRequestingAuthorization = { prompts.append("notifications, finished: \(record.isFinished)") }
        manager.whileRequestingAuthorization = { prompts.append("alarms, finished: \(record.isFinished)") }

        await model.askForPermissions()

        #expect(prompts == ["notifications, finished: false", "alarms, finished: false"])
        #expect(record.isFinished)
    }

    /// The alarm prompt follows whatever the person chose for notifications. Before it, the
    /// plan's alarms wait, so no `schedule` can raise AlarmKit's own prompt; its answer re-plans
    /// them, and the banners' `reach` follows.
    @Test(arguments: [
        (UNAuthorizationStatus.authorized, AlarmManager.AuthorizationState.authorized, 20, DeliveryKind?.some(.notification), DeliveryKind?.some(.alarm)),
        (.denied, .authorized, 20, nil, .alarm),
        (.authorized, .denied, 0, .notification, .notification),
    ])
    func theAnswersReachThePlan(
        notifications: UNAuthorizationStatus,
        alarms: AlarmManager.AuthorizationState,
        scheduledAlarms: Int,
        normal: DeliveryKind?,
        urgent: DeliveryKind?
    ) async throws {
        let model = try await launchedModel()
        model.add(Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 9), strength: .relentless))
        await model.waitUntilApplied()
        #expect(manager.scheduleCalls.isEmpty)
        center.promptAnswer = notifications
        manager.promptAnswer = alarms

        await model.askForPermissions()
        await model.waitUntilApplied()

        #expect(manager.scheduled.count == scheduledAlarms)
        #expect(model.engine.reach.normal == normal)
        #expect(model.engine.reach.urgent == urgent)
    }

    /// Onboarding was finished (data restored from a backup, say) but alarms were never asked
    /// for: only the alarm prompt, so the plan's alarms aren't held back for good.
    @Test func afterOnboardingAlarmsNeverAskedForAskOnlyForAlarms() async throws {
        OnboardingRecord(defaults: try #require(UserDefaults(suiteName: suiteName))).isFinished = true
        let model = try await launchedModel()
        #expect(model.onboarding == .alarmsOnly)

        await model.askForPermissions()

        #expect(center.requestedAuthorizationOptions.isEmpty)
        #expect(manager.authorizationRequests == 1)
        #expect(model.onboarding == nil)
        #expect(model.permissions.alarms == .allowed)
    }

    /// Each system prompt makes the app inactive and then active, an App opened, and a read of
    /// AlarmKit's state right after its prompt froze the iPhone (ticket 22). So App opened leaves
    /// it alone while the prompts are up and for a moment after; a later return reads it again,
    /// however many App opened events the prompts made.
    @Test func appOpenedDoesNotReadAlarmKitAroundThePrompts() async throws {
        let model = try await launchedModel()
        let readsAtLaunch = manager.authorizationReads
        var opened: [Task<Void, Never>] = []
        center.whileRequestingAuthorization = { opened.append(Task { await model.appOpened() }) }

        await model.askForPermissions()
        for task in opened { await task.value }
        await model.appOpened()
        await model.appOpened()
        #expect(manager.authorizationReads == readsAtLaunch)

        clock.now += 5
        await model.appOpened()
        #expect(manager.authorizationReads == readsAtLaunch + 1)
    }

    /// A read of AlarmKit's state that doesn't answer in time counts as not asked for the plan,
    /// but it isn't known to be, so it doesn't bring the cover back for someone who answered.
    @Test func afterOnboardingAnAlarmReadThatTimesOutShowsNothing() async throws {
        OnboardingRecord(defaults: try #require(UserDefaults(suiteName: suiteName))).isFinished = true
        manager.authorizationReadHangs = true
        let store = try ReminderStore(location: .inMemory)
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let model = AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: center, clock: clock),
            alarms: AlarmAdapter(manager: manager, clock: clock, authorizationReadLimit: .milliseconds(50)),
            onboardingRecord: OnboardingRecord(defaults: defaults),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
        await model.launch()

        #expect(model.permissions.alarms == .notDetermined)
        #expect(model.onboarding == nil)
    }

    @Test func afterOnboardingAlarmsAlreadyAnsweredShowNothing() async throws {
        OnboardingRecord(defaults: try #require(UserDefaults(suiteName: suiteName))).isFinished = true
        manager.authorizationState = .denied
        let model = try await launchedModel()
        #expect(model.onboarding == nil)
    }
}
