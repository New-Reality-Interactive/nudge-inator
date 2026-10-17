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
/// It writes a store of its own in the App Group container, which its `TemporaryStoreFile`
/// deletes with SQLite's side files (AGENTS.md: tests on the iPhone leave it as they found it).
@MainActor
@Suite(.enabled(if: DeviceCheck.isPhysicalDevice, "Data protection applies only on an iPhone"))
struct StoreProtectionDeviceCheck {
    let storeFile = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: ReminderStore.appGroupIdentifier)
        .map { TemporaryStoreFile(in: $0) }

    @Test func theStoreStaysReadableOnALockedPhoneAfterTheFirstUnlock() throws {
        let storeFile = try #require(storeFile, "No App Group container")
        let store = try ReminderStore(location: .file(storeFile.url))
        try store.save(StoredData(
            reminders: [Reminder(title: "Nudge-inator device check", dueTime: .now + 86_400, strength: .gentle)],
            tags: [],
            histories: [:]
        ))

        let written = storeFile.files.filter { FileManager.default.fileExists(atPath: $0.path()) }
        #expect(written.first == storeFile.url)
        for file in written {
            let protection = try file.resourceValues(forKeys: [.fileProtectionKey]).fileProtection
            print("Store protection: \(file.lastPathComponent) \(protection.map(\.rawValue) ?? "nil")")
            #expect(protection == .completeUntilFirstUserAuthentication || protection == URLFileProtection.none)
        }
    }
}

/// Ticket 18's device checks 1, 2 and 5, which need the wiring: the app's own model
/// (`AppDelegate.makeModel`) over the real notification center and alarm manager, with a store
/// of its own. Opt-in, since each waits for a person:
/// `TEST_RUNNER_NUDGE_ACTION_CHECK=1 xcodebuild test ... -only-testing:NudgeInatorTests/NudgeActionDeviceCheck/<test>`
/// Run one test at a time and follow its comment. Only Gentle reminders, which never ring, so no
/// alarm is scheduled and no AlarmKit prompt appears.
///
/// Cleanup acts only on what the check made (AGENTS.md). Each test deletes its reminders, which
/// removes their pending nudges, then removes the ones delivered, by the identifiers recorded
/// when they were scheduled. `deinit` removes them again in case a test failed first, and
/// cancels the app's alarms only once the check has seen it held none, so any are its own.
/// Notification permission is asked for only when the run says the app wasn't installed
/// (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`); uninstalling afterwards resets it.
@MainActor
@Suite(.enabled(
    if: DeviceCheck.isPhysicalDevice && ProcessInfo.processInfo.environment["NUDGE_ACTION_CHECK"] == "1",
    "Delivers notifications and needs a person: set TEST_RUNNER_NUDGE_ACTION_CHECK=1"
))
final class NudgeActionDeviceCheck {
    let storeFile = TemporaryStoreFile()
    private(set) var reminderIDs: [Reminder.ID] = []
    /// The identifiers of every nudge the check's reminders had pending.
    private(set) var notificationIDs: Set<String> = []
    /// Set once the check has seen the app held no alarms, so every alarm it holds after is the check's.
    private(set) var ownsEveryAlarm = false

    // Nonisolated, as every deinit is: it reads only Sendable values and calls the system's
    // synchronous removals, which Apple says are safe from any thread.
    deinit {
        Self.remove(notificationIDs)
        guard ownsEveryAlarm else { return }
        for alarm in (try? AlarmManager.shared.alarms) ?? [] {
            try? AlarmManager.shared.stop(id: alarm.id)
            try? AlarmManager.shared.cancel(id: alarm.id)
        }
    }

    nonisolated private static func remove(_ identifiers: Set<String>) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Array(identifiers))
        center.removeDeliveredNotifications(withIdentifiers: Array(identifiers))
    }

    /// The app's model, launched, with notifications allowed and none of the app's alarms scheduled.
    func launchedModel() async throws -> AppModel {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined,
           ProcessInfo.processInfo.environment["NUDGE_FRESH_INSTALL"] == "1" {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        }
        try #require(await center.notificationSettings().authorizationStatus == .authorized, "Allow notifications for Nudge-inator, or set TEST_RUNNER_NUDGE_FRESH_INSTALL=1 on a fresh install")
        try #require(try AlarmManager.shared.alarms.isEmpty, "Nudge-inator already holds alarms; the check would cancel them")
        ownsEveryAlarm = true
        let model = AppDelegate.makeModel { [storeFile] in try ReminderStore(location: .file(storeFile.url)) }
        await model.launch()
        return model
    }

    func add(_ reminder: Reminder, to model: AppModel) async {
        reminderIDs.append(reminder.id)
        model.add(reminder)
        await model.waitUntilApplied()
        let prefix = "nudge.\(reminder.id.uuidString)."
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        notificationIDs.formUnion(pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
    }

    /// Waits for the person to choose Done on the reminder's first nudge, giving up a minute
    /// after it fires, so a missed or wrong tap ends the run soon rather than leaving it waiting.
    func waitForDone(on reminder: Reminder, in model: AppModel) async throws -> Bool {
        let deadline = reminder.dueTime + 60
        while Date.now < deadline {
            if model.engine.latestOccurrence(for: reminder.id)?.state == .done { return true }
            try await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    /// Deletes the reminders through the model, as the app would, then the nudges they delivered.
    func cleanUp(_ model: AppModel) async {
        for id in reminderIDs { model.delete(id) }
        await model.waitUntilApplied()
        Self.remove(notificationIDs)
    }

    /// Checks 5 and 1 (banner): keep the app in front, unlocked. A banner reading "Nudge-inator
    /// banner check" shows about a minute in; pull it down and choose Done (tapping it opens
    /// the app, which isn't Done). It fails a minute after the banner if no Done arrives.
    @Test(.timeLimit(.minutes(3)))
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

    /// Check 1 (Lock Screen): lock the phone as soon as the run starts. About 45 seconds in,
    /// "Nudge-inator Lock Screen check" arrives; long-press it and choose Done without unlocking.
    /// Then unlock, so the run can finish. It fails a minute after the nudge if no Done arrives.
    @Test(.timeLimit(.minutes(3)))
    func doneFromTheLockScreenReachesTheModelAndTheStore() async throws {
        let model = try await launchedModel()
        let reminder = Reminder(title: "Nudge-inator Lock Screen check", dueTime: .now + 45, strength: .gentle, breakThroughFocus: false)
        await add(reminder, to: model)

        let done = try await waitForDone(on: reminder, in: model)
        let saved = try ReminderStore(location: .file(storeFile.url)).load()
        await cleanUp(model)

        #expect(done, "Done wasn't chosen, or didn't reach the model")
        #expect(saved.histories[reminder.id]?.closedOccurrences[reminder.dueTime]?.state == .done)
    }

    /// Check 2: turn on a Focus that doesn't allow Nudge-inator but allows Time Sensitive
    /// notifications, then lock the phone. About 45 seconds in, two nudges are delivered at once:
    /// "Nudge-inator Time Sensitive check" should show, and "Nudge-inator held check" should be
    /// held. Choosing Done on the first is fine. Note what you saw, unlock, and turn the Focus
    /// off. The Focus must allow Time Sensitive notifications (its Apps › Time Sensitive
    /// Notifications): with it off, the first run here showed nothing. Gentle's nudge 5 is its first
    /// High one, so that reminder fell due 2 h 44 min 4 s before it.
    @Test(.timeLimit(.minutes(3)))
    func aTimeSensitiveNudgeIsDeliveredBesideAnOrdinaryOneDuringAFocus() async throws {
        let model = try await launchedModel()
        let fireTime = Date.now + 45
        let gentleNudgeFive: TimeInterval = 3600 + 2700 + 2025 + 1519
        let timeSensitive = Reminder(title: "Nudge-inator Time Sensitive check", dueTime: fireTime - gentleNudgeFive, strength: .gentle)
        let ordinary = Reminder(title: "Nudge-inator held check", dueTime: fireTime, strength: .gentle, breakThroughFocus: false)
        await add(timeSensitive, to: model)
        await add(ordinary, to: model)

        let center = UNUserNotificationCenter.current()
        let first = await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix("nudge.\(timeSensitive.id.uuidString).") }
            .min { Self.fireDate(of: $0) < Self.fireDate(of: $1) }
        #expect(first?.content.interruptionLevel == .timeSensitive)
        #expect(first?.content.body == "Nudge 5 of 20 · High")

        // Held or shown, both are in Notification Center once they fire; what the person saw is the check.
        try await Task.sleep(for: .seconds(fireTime.timeIntervalSinceNow + 30))
        let delivered = await center.deliveredNotifications().map(\.request.content.title)
        // Choosing Done on a nudge takes it out of Notification Center, and is proof it arrived.
        let timeSensitiveDone = model.engine.latestOccurrence(for: timeSensitive.id)?.state == .done
        print("Focus check: delivered \(delivered.filter { $0.hasPrefix("Nudge-inator") }), Time Sensitive Done: \(timeSensitiveDone)")
        await cleanUp(model)

        #expect(delivered.contains(timeSensitive.title) || timeSensitiveDone)
        #expect(delivered.contains(ordinary.title))
    }

    private static func fireDate(of request: UNNotificationRequest) -> Date {
        (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
    }
}
