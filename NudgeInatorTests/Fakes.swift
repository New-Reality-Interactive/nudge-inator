import Foundation
import NudgeEngine
import UserNotifications
import AlarmKit
import AppIntents
import NudgeShared
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

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        self.categories = categories
    }

    func setDelegate(_ delegate: any UNUserNotificationCenterDelegate) {
        self.delegate = delegate
    }

    func notificationSettings() async -> NotificationSettingsSnapshot {
        settings
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedAuthorizationOptions.append(options)
        return true
    }
}

/// Records what the notification adapter reports, as the app model will receive it (ticket 21).
@MainActor
final class FakeNotificationEvents: NotificationAdapterEvents {
    private(set) var dones: [DeliveredNudge] = []
    private(set) var schedulingErrors: [any Error] = []

    func markDone(_ reminderID: Reminder.ID, nudgeFiredAt fireTime: Date) {
        dones.append(DeliveredNudge(reminderID: reminderID, fireTime: fireTime))
    }

    func schedulingFailed(_ error: any Error) {
        schedulingErrors.append(error)
    }
}

/// A store file in the temporary directory, deleted with SQLite's side files when released.
final class TemporaryStoreFile: Sendable {
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).store")

    deinit {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(filePath: url.path() + suffix))
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
        secondaryIntent: (any LiveActivityIntent)?
    ) async throws {
        let alarm = Scheduled(id: id, schedule: schedule, attributes: attributes, secondaryIntent: secondaryIntent)
        scheduleCalls.append(alarm)
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

    func cancel(id: Alarm.ID) throws {
        cancelledIDs.append(id)
        scheduled.removeAll { $0.id == id }
    }

    /// When set, `alarms()` throws it.
    var alarmsError: (any Error)?

    func alarms() throws -> [ScheduledAlarm] {
        if let alarmsError { throw alarmsError }
        return scheduled.map { ScheduledAlarm(id: $0.id, state: $0.state) }
    }

    var authorizationState = AlarmManager.AuthorizationState.notDetermined

    /// What the person answers when `requestAuthorization()` shows the prompt.
    var answer = AlarmManager.AuthorizationState.authorized
    private(set) var authorizationRequests = 0

    func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        authorizationRequests += 1
        if authorizationState == .notDetermined {
            authorizationState = answer
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

extension Collection {
    /// The one element, or `nil` if there are none or several.
    var only: Element? { count == 1 ? first : nil }
}

/// Stands in for ticket 21's app model: owns the engine and sends the alarm adapter's reports on
/// to it, as the real model will.
@MainActor
final class FakeAlarmEvents: AlarmAdapterEvents {
    var engine: Engine?
    private(set) var limitReports: [DeliveredNudge] = []
    private(set) var schedulingErrors: [any Error] = []

    func markAlarmLimitReached(_ reminderID: Reminder.ID, firingAt fireTime: Date) {
        limitReports.append(DeliveredNudge(reminderID: reminderID, fireTime: fireTime))
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
