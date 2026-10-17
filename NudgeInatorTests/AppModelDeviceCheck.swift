import AlarmKit
import Foundation
import NudgeEngine
import Testing
import UserNotifications
@testable import NudgeInator

/// Ticket 21's device check 8: the store must stay readable on a locked phone, because people
/// can choose Done on a notification without unlocking (Apple: "users can respond to actions
/// while the device is locked"), and the model saves after it. SwiftData has no file-protection
/// setting; Core Data's and the system's documented default is `completeUntilFirstUserAuthentication`.
/// It writes a store of its own in the App Group container, and deletes it with SQLite's side
/// files (AGENTS.md: tests on the iPhone leave it as they found it).
@MainActor
@Suite(.enabled(if: DeviceCheck.isPhysicalDevice, "Data protection applies only on an iPhone"))
final class StoreProtectionDeviceCheck {
    let url: URL? = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: ReminderStore.appGroupIdentifier)?
        .appending(path: "device-check-\(UUID().uuidString).store")

    deinit {
        guard let url else { return }
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(filePath: url.path() + suffix))
        }
    }

    @Test func theStoreStaysReadableOnALockedPhoneAfterTheFirstUnlock() throws {
        let url = try #require(url, "No App Group container")
        let store = try ReminderStore(location: .file(url))
        try store.save(StoredData(
            reminders: [Reminder(title: "Nudge-inator device check", dueTime: .now + 86_400, strength: .gentle)],
            tags: [],
            histories: [:]
        ))

        for suffix in ["", "-wal", "-shm"] {
            let file = URL(filePath: url.path() + suffix)
            guard FileManager.default.fileExists(atPath: file.path()) || suffix.isEmpty else { continue }
            let protection = try file.resourceValues(forKeys: [.fileProtectionKey]).fileProtection
            print("Store protection: \(file.lastPathComponent) \(protection.map(\.rawValue) ?? "nil")")
            #expect(protection == .completeUntilFirstUserAuthentication || protection == URLFileProtection.none)
        }
    }
}

/// Ticket 18's device checks 1, 2 and 5, which need the wiring: a real app model over the real
/// notification center and alarm manager, with a store of its own. Opt-in, since each waits for
/// a person: `TEST_RUNNER_NUDGE_ACTION_CHECK=1 xcodebuild test ... -only-testing:NudgeInatorTests/NudgeActionDeviceCheck/<test>`
/// Run one test at a time and follow its comment. Only Gentle reminders, which never ring, so
/// no alarm is scheduled and no AlarmKit prompt appears.
///
/// Cleanup: each test deletes its reminders, which removes their pending nudges, and removes the
/// notifications it delivered. If a test fails first, `deinit` removes them, and cancels any
/// alarm the app holds: the check requires it held none, so they are all its own. Notification
/// permission is asked for only when the run says the app wasn't installed
/// (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`); uninstalling afterwards resets it.
@MainActor
@Suite(.enabled(
    if: DeviceCheck.isPhysicalDevice && ProcessInfo.processInfo.environment["NUDGE_ACTION_CHECK"] == "1",
    "Delivers notifications and needs a person: set TEST_RUNNER_NUDGE_ACTION_CHECK=1"
))
final class NudgeActionDeviceCheck {
    let storeFile = TemporaryStoreFile()
    private(set) var reminderIDs: [Reminder.ID] = []

    deinit {
        let prefixes = reminderIDs.map { "nudge.\($0.uuidString)." }
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests().map(\.identifier)
            let delivered = await center.deliveredNotifications().map(\.request.identifier)
            let ours = (pending + delivered).filter { id in prefixes.contains { id.hasPrefix($0) } }
            center.removePendingNotificationRequests(withIdentifiers: ours)
            center.removeDeliveredNotifications(withIdentifiers: ours)
        }
        for alarm in (try? AlarmManager.shared.alarms) ?? [] {
            try? AlarmManager.shared.cancel(id: alarm.id)
        }
    }

    /// A launched model with notifications allowed and none of the app's alarms scheduled.
    func launchedModel() async throws -> AppModel {
        let clock = SystemClock()
        let notifications = NotificationAdapter(center: SystemNotificationCenter(), clock: clock)
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined,
           ProcessInfo.processInfo.environment["NUDGE_FRESH_INSTALL"] == "1" {
            _ = try await notifications.requestAuthorization()
        }
        try #require(await center.notificationSettings().authorizationStatus == .authorized, "Allow notifications for Nudge-inator, or set TEST_RUNNER_NUDGE_FRESH_INSTALL=1 on a fresh install")
        try #require(try AlarmManager.shared.alarms.isEmpty, "Nudge-inator already holds alarms; the check would cancel them")
        let model = AppModel(
            clock: clock,
            store: Result { try ReminderStore(location: .file(storeFile.url)) },
            notifications: notifications,
            alarms: AlarmAdapter(manager: SystemAlarmManager(), clock: clock)
        )
        await model.launch()
        return model
    }

    func add(_ reminder: Reminder, to model: AppModel) async {
        reminderIDs.append(reminder.id)
        model.add(reminder)
        await model.waitUntilApplied()
    }

    /// Waits up to `limit` for the person to choose Done on the reminder's notification.
    func waitForDone(on reminder: Reminder, in model: AppModel, limit: Duration = .seconds(240)) async throws -> Bool {
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            if model.engine.latestOccurrence(for: reminder.id)?.state == .done { return true }
            try await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    /// Deletes the reminders, which removes their pending nudges, and their delivered ones.
    func cleanUp(_ model: AppModel) async {
        let prefixes = reminderIDs.map { "nudge.\($0.uuidString)." }
        for id in reminderIDs { model.delete(id) }
        await model.waitUntilApplied()
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications().map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: delivered.filter { id in prefixes.contains { id.hasPrefix($0) } })
    }

    /// Checks 5 and 1 (banner): keep the app in front, unlocked. A banner reading "Nudge-inator
    /// banner check" shows about a minute in; pull it down and choose Done.
    @Test(.timeLimit(.minutes(5)))
    func doneFromABannerWithTheAppInFrontReachesTheModelAndTheStore() async throws {
        let model = try await launchedModel()
        let reminder = Reminder(title: "Nudge-inator banner check", dueTime: .now + 60, strength: .gentle, breakThroughFocus: false)
        await add(reminder, to: model)

        let done = try await waitForDone(on: reminder, in: model)
        let saved = try ReminderStore(location: .file(storeFile.url)).load()
        await cleanUp(model)

        #expect(done, "Done wasn't chosen, or didn't reach the model")
        #expect(saved.histories[reminder.id]?.closedOccurrences[reminder.dueTime]?.state == .done)
    }

    /// Check 1 (Lock Screen): lock the phone as soon as the run starts. About 90 seconds in,
    /// "Nudge-inator Lock Screen check" arrives; long-press it and choose Done without unlocking.
    /// Then unlock, so the run can finish.
    @Test(.timeLimit(.minutes(5)))
    func doneFromTheLockScreenReachesTheModelAndTheStore() async throws {
        let model = try await launchedModel()
        let reminder = Reminder(title: "Nudge-inator Lock Screen check", dueTime: .now + 90, strength: .gentle, breakThroughFocus: false)
        await add(reminder, to: model)

        let done = try await waitForDone(on: reminder, in: model)
        let saved = try ReminderStore(location: .file(storeFile.url)).load()
        await cleanUp(model)

        #expect(done, "Done wasn't chosen, or didn't reach the model")
        #expect(saved.histories[reminder.id]?.closedOccurrences[reminder.dueTime]?.state == .done)
    }

    /// Check 2: turn on a Focus that doesn't allow Nudge-inator but allows Time Sensitive
    /// notifications, then lock the phone. About 90 seconds in, two nudges are delivered at once:
    /// "Nudge-inator Time Sensitive check" should show, and "Nudge-inator held check" should be
    /// held. Note what you saw, unlock, and turn the Focus off. Gentle's nudge 5 is its first
    /// High one, so that reminder fell due 2 h 44 min 4 s before it.
    @Test(.timeLimit(.minutes(5)))
    func aTimeSensitiveNudgeIsDeliveredBesideAnOrdinaryOneDuringAFocus() async throws {
        let model = try await launchedModel()
        let fireTime = Date.now + 90
        let gentleNudgeFive: TimeInterval = 3600 + 2700 + 2025 + 1519
        let timeSensitive = Reminder(title: "Nudge-inator Time Sensitive check", dueTime: fireTime - gentleNudgeFive, strength: .gentle)
        let ordinary = Reminder(title: "Nudge-inator held check", dueTime: fireTime, strength: .gentle, breakThroughFocus: false)
        await add(timeSensitive, to: model)
        await add(ordinary, to: model)

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let first = pending.filter { $0.identifier.hasPrefix("nudge.\(timeSensitive.id.uuidString).") }
            .min { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
                < ($1.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() ?? .distantFuture }
        #expect(first?.content.interruptionLevel == .timeSensitive)
        #expect(first?.content.body == "Nudge 5 of 20 · High")

        // Delivered or not, both are in Notification Center once they fire; held is what the person sees.
        try await Task.sleep(for: .seconds(fireTime.timeIntervalSinceNow + 30))
        let delivered = await center.deliveredNotifications().map(\.request.content.title)
        print("Focus check: delivered \(delivered.filter { $0.hasPrefix("Nudge-inator") })")
        await cleanUp(model)

        #expect(delivered.contains(timeSensitive.title))
        #expect(delivered.contains(ordinary.title))
    }
}
