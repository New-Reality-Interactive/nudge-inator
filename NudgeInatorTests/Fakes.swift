import Foundation
import NudgeEngine
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
    private(set) var doneReminderIDs: [Reminder.ID] = []

    private(set) var schedulingErrors: [any Error] = []

    func markDone(_ reminderID: Reminder.ID) {
        doneReminderIDs.append(reminderID)
    }

    func schedulingFailed(_ error: any Error) {
        schedulingErrors.append(error)
    }
}
