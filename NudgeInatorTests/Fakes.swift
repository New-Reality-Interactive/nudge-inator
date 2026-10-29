import AlarmKit
import AppIntents
import Foundation
import NudgeEngine
import NudgeShared
import UserNotifications
@testable import NudgeInator

/// A clock the test sets by hand, so no test depends on real time.
final class FakeClock: EngineClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

/// Records every schedule plan the engine hands to it.
final class FakeScheduler: SchedulerAdapter {
    private(set) var appliedPlans: [SchedulePlan] = []

    var lastPlan: SchedulePlan? { appliedPlans.last }

    func apply(_ plan: SchedulePlan) {
        appliedPlans.append(plan)
    }
}

/// Test dates as local wall-clock times in New York, so no test depends on the simulator's time
/// zone.
enum NewYork {
    static let timeZone = TimeZone(identifier: "America/New_York")!

    static func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }
}

/// Stands in for `UNUserNotificationCenter`: keeps the real requests the adapter adds, so tests
/// assert on real content, triggers and interruption levels.
@MainActor
final class FakeNotificationCenter: UserNotificationCenter {
    private(set) var pending: [UNNotificationRequest] = []
    /// Every request passed to `add(_:)`, in order.
    private(set) var added: [UNNotificationRequest] = []
    /// The last categories registered, or `nil` if none were.
    private(set) var categories: Set<UNNotificationCategory>?
    /// When set, every `add(_:)` throws it and nothing is added.
    var addError: (any Error)?
    var settings = NotificationSettingsSnapshot(authorizationStatus: .notDetermined, timeSensitiveSetting: .notSupported)
    /// Every options set passed to `requestAuthorization(options:)`.
    private(set) var requestedAuthorizationOptions: [UNAuthorizationOptions] = []
    /// Weak, as the real center's is.
    private(set) weak var delegate: (any UNUserNotificationCenterDelegate)?

    func add(_ request: UNNotificationRequest) async throws {
        added.append(request)
        if let addError { throw addError }
        // As the real center does: the same identifier replaces the pending request.
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pending
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        pending.removeAll { identifiers.contains($0.identifier) }
    }

    func removeAllPendingNotificationRequests() {
        pending.removeAll()
    }

    /// Delivered notifications can't be made in a test, so only the call is kept.
    private(set) var removedAllDeliveredCount = 0

    func removeAllDeliveredNotifications() {
        removedAllDeliveredCount += 1
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        self.categories = categories
    }

    func setDelegate(_ delegate: any UNUserNotificationCenterDelegate) {
        self.delegate = delegate
    }

    /// When set, each `notificationSettings()` waits for `releaseLatestSettingsRead()`, so a test
    /// can choose the order overlapping reads finish in.
    var holdsSettingsReads = false
    private var heldSettingsReads: [CheckedContinuation<Void, Never>] = []
    var heldSettingsReadCount: Int { heldSettingsReads.count }

    func releaseLatestSettingsRead() {
        heldSettingsReads.popLast()?.resume()
    }

    func notificationSettings() async -> NotificationSettingsSnapshot {
        if holdsSettingsReads {
            await withCheckedContinuation { heldSettingsReads.append($0) }
        }
        return settings
    }

    /// What the person answers when `requestAuthorization(options:)` shows the prompt. As on the
    /// iPhone, it shows only while the status is not determined.
    var promptAnswer = UNAuthorizationStatus.authorized
    /// Runs during each `requestAuthorization(options:)`, while the prompt would be up.
    var whileRequestingAuthorization: (() -> Void)?

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedAuthorizationOptions.append(options)
        whileRequestingAuthorization?()
        if settings.authorizationStatus == .notDetermined {
            // Allowing a prompt that names badges allows them too.
            let badgeSetting: UNNotificationSetting = promptAnswer == .authorized && options.contains(.badge) ? .enabled : settings.badgeSetting
            settings = NotificationSettingsSnapshot(authorizationStatus: promptAnswer, timeSensitiveSetting: settings.timeSensitiveSetting, badgeSetting: badgeSetting)
        } else if settings.authorizationStatus == .authorized, settings.badgeSetting == .notSupported, options.contains(.badge) {
            // No prompt, as on the iPhone (device experiment, #82): an install authorized before
            // it asked for badges gets them by asking again.
            settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: settings.timeSensitiveSetting, badgeSetting: .enabled)
        }
        return settings.authorizationStatus == .authorized
    }

    /// Every count passed to `setBadgeCount(_:)`, in order, including ones it threw for.
    private(set) var badgeCounts: [Int] = []
    /// When set, every `setBadgeCount(_:)` throws it.
    var badgeError: (any Error)?

    func setBadgeCount(_ count: Int) async throws {
        badgeCounts.append(count)
        if let badgeError { throw badgeError }
    }
}

/// Records what the notification adapter reports, as the app model will receive it (ticket 21).
@MainActor
final class FakeNotificationEvents: NotificationAdapterEvents {
    private(set) var dones: [DeliveredNudge] = []
    private(set) var schedulingErrors: [any Error] = []

    func markDone(_ nudge: DeliveredNudge) async {
        dones.append(nudge)
    }

    func schedulingFailed(_ error: any Error) {
        schedulingErrors.append(error)
    }

    /// The app model's tests cover what a presentation does.
    func notificationPresented() {}
}

/// A store file, in the temporary directory unless given another, deleted with SQLite's side
/// files when released.
final class TemporaryStoreFile: Sendable {
    let url: URL

    /// The store and the side files SQLite makes beside it.
    var files: [URL] {
        ["", "-wal", "-shm"].map { URL(filePath: url.path() + $0) }
    }

    init(in directory: URL = FileManager.default.temporaryDirectory) {
        url = directory.appending(path: "\(UUID().uuidString).store")
    }

    deinit {
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

/// Stands in for `AlarmManager`: keeps the schedule and attributes of every alarm the adapter
/// schedules, so tests assert on what the alert shows and when it rings.
@MainActor
final class FakeAlarmManager: AlarmManaging {
    struct Scheduled {
        var id: Alarm.ID
        var schedule: Alarm.Schedule
        var attributes: AlarmAttributes<NudgeAlarmMetadata>
        var stopIntent: (any LiveActivityIntent)?
        var secondaryIntent: (any LiveActivityIntent)?
        var state: Alarm.State = .scheduled

        var fireDate: Date? {
            if case .fixed(let date) = schedule { date } else { nil }
        }
    }

    /// The alarms the system holds, in the order scheduled.
    private(set) var scheduled: [Scheduled] = []
    /// Every alarm passed to `schedule`, in order, including refused ones.
    private(set) var scheduleCalls: [Scheduled] = []
    private(set) var cancelledIDs: [Alarm.ID] = []

    /// When set, `schedule` throws `maximumLimitReached` once the system holds this many.
    var alarmLimit: Int?
    /// When set, every `schedule` throws it and nothing is scheduled.
    var scheduleError: (any Error)?

    func schedule(
        id: Alarm.ID,
        schedule: Alarm.Schedule,
        attributes: AlarmAttributes<NudgeAlarmMetadata>,
        stopIntent: (any LiveActivityIntent)?,
        secondaryIntent: (any LiveActivityIntent)?
    ) async throws {
        let alarm = Scheduled(id: id, schedule: schedule, attributes: attributes, stopIntent: stopIntent, secondaryIntent: secondaryIntent)
        scheduleCalls.append(alarm)
        defer { whileScheduling?() }
        if let scheduleError { throw scheduleError }
        if let alarmLimit, scheduled.count >= alarmLimit {
            throw AlarmManager.AlarmError.maximumLimitReached
        }
        scheduled.removeAll { $0.id == id }
        scheduled.append(alarm)
    }

    /// What the system does at an alarm's fire time.
    func ring(_ id: Alarm.ID) {
        for index in scheduled.indices where scheduled[index].id == id {
            scheduled[index].state = .alerting
        }
    }

    /// When set, every `cancel(id:)` throws it and nothing is cancelled.
    var cancelError: (any Error)?
    /// Runs after each `schedule` call, as if something happened while AlarmKit was busy.
    var whileScheduling: (() -> Void)?

    func cancel(id: Alarm.ID) throws {
        if let cancelError { throw cancelError }
        cancelledIDs.append(id)
        scheduled.removeAll { $0.id == id }
    }

    private(set) var stoppedIDs: [Alarm.ID] = []
    /// When set, every `stop(id:)` throws it and nothing is stopped.
    var stopError: (any Error)?

    /// Apple: "If the alarm is a one-shot … then the system deletes the alarm." Every nudge is.
    func stop(id: Alarm.ID) throws {
        if let stopError { throw stopError }
        stoppedIDs.append(id)
        scheduled.removeAll { $0.id == id }
    }

    /// When set, `alarms()` throws it.
    var alarmsError: (any Error)?

    func alarms() throws -> [AlarmSnapshot] {
        if let alarmsError { throw alarmsError }
        return scheduled.map { AlarmSnapshot(id: $0.id, state: $0.state) }
    }

    /// The system's authorization state, which `readAuthorizationState()` returns.
    var authorizationState = AlarmManager.AuthorizationState.authorized
    /// How many times the adapter read the state, the call that froze the iPhone.
    private(set) var authorizationReads = 0
    /// When set, `readAuthorizationState()` never answers, as on the iPhone.
    var authorizationReadHangs = false

    /// When set, each `readAuthorizationState()` waits for `releaseLatestAuthorizationRead(returning:)`,
    /// so a test can finish a read after something newer has happened.
    var holdsAuthorizationReads = false
    private var heldAuthorizationReads: [CheckedContinuation<AlarmManager.AuthorizationState, Never>] = []
    var heldAuthorizationReadCount: Int { heldAuthorizationReads.count }

    func releaseLatestAuthorizationRead(returning state: AlarmManager.AuthorizationState) {
        heldAuthorizationReads.popLast()?.resume(returning: state)
    }

    func readAuthorizationState() async -> AlarmManager.AuthorizationState {
        authorizationReads += 1
        if holdsAuthorizationReads {
            return await withCheckedContinuation { heldAuthorizationReads.append($0) }
        }
        if authorizationReadHangs {
            try? await Task.sleep(for: .seconds(3600))
        }
        return authorizationState
    }

    /// What the person answers when `requestAuthorization()` shows the prompt.
    var promptAnswer = AlarmManager.AuthorizationState.authorized
    private(set) var authorizationRequests = 0

    /// Runs during each `requestAuthorization()`, while the prompt would be up.
    var whileRequestingAuthorization: (() -> Void)?

    func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        authorizationRequests += 1
        whileRequestingAuthorization?()
        if authorizationState == .notDetermined {
            authorizationState = promptAnswer
        }
        return authorizationState
    }

    private var authorizationContinuations: [AsyncStream<AlarmManager.AuthorizationState>.Continuation] = []

    func authorizationUpdates() -> AsyncStream<AlarmManager.AuthorizationState> {
        let (stream, continuation) = AsyncStream.makeStream(of: AlarmManager.AuthorizationState.self)
        authorizationContinuations.append(continuation)
        return stream
    }

    /// What the system does when the person changes the app's alarm permission in Settings.
    func changeAuthorization(to state: AlarmManager.AuthorizationState) {
        authorizationState = state
        for continuation in authorizationContinuations {
            continuation.yield(state)
        }
    }
}

extension DoneQueue {
    /// A queue in the temporary directory, for models whose tests queue no Done, so none reads or
    /// deletes the app's own queue (ticket 32). `DoneBeforeFirstUnlockTests` uses folders of its own.
    static let temporary = DoneQueue(folder: FileManager.default.temporaryDirectory.appending(path: "NudgeInatorTests.DoneQueue"))
}

extension DefaultPaceRecord {
    /// A record in a suite of the tests' own, for models whose Delete All Data would otherwise
    /// clear the app's own Default Pace. `DefaultPaceTests` uses suites of its own.
    static var temporary: DefaultPaceRecord { DefaultPaceRecord(defaults: UserDefaults(suiteName: "NudgeInatorTests.DefaultPace")!) }
}

extension Collection {
    /// The one element, or `nil` if there are none or several.
    var only: Element? { count == 1 ? first : nil }
}

/// Stands in for ticket 21's app model: owns the engine and sends the alarm adapter's reports on
/// to it, as the real model will.
@MainActor
final class FakeAlarmEvents: AlarmAdapterEvents {
    var engine: Engine?
    /// A nudge whose alarm AlarmKit turned down with `maximumLimitReached`.
    struct LimitReport: Equatable {
        var reminderID: Reminder.ID
        var fireTime: Date
    }

    private(set) var limitReports: [LimitReport] = []
    private(set) var schedulingErrors: [any Error] = []

    func markAlarmLimitReached(_ reminderID: Reminder.ID, firingAt fireTime: Date) {
        limitReports.append(LimitReport(reminderID: reminderID, fireTime: fireTime))
        engine?.markAlarmLimitReached(reminderID, firingAt: fireTime)
    }

    func schedulingFailed(_ error: any Error) {
        schedulingErrors.append(error)
    }

    private(set) var authorizationChanges = 0

    func alarmAuthorizationChanged() {
        authorizationChanges += 1
    }
}

/// Sits between the engine and an adapter: records each plan, then passes it on.
@MainActor
final class RecordingScheduler: @MainActor SchedulerAdapter {
    private let adapter: any SchedulerAdapter
    private(set) var appliedPlans: [SchedulePlan] = []

    var lastPlan: SchedulePlan? { appliedPlans.last }

    init(passingTo adapter: any SchedulerAdapter) {
        self.adapter = adapter
    }

    func apply(_ plan: SchedulePlan) {
        appliedPlans.append(plan)
        adapter.apply(plan)
    }
}
