import UserNotifications

/// The parts of `UNNotificationSettings` the adapter reads. Tests can't make a
/// `UNNotificationSettings` ("You don't create instances of this class directly").
struct NotificationSettingsSnapshot: Equatable, Sendable {
    var authorizationStatus: UNAuthorizationStatus
    var timeSensitiveSetting: UNNotificationSetting
    /// `notSupported` before the prompt, and after one that didn't ask for badges.
    var badgeSetting: UNNotificationSetting = .notSupported
}

/// The calls the notification adapter makes on `UNUserNotificationCenter`, so tests can swap in a
/// fake. `@MainActor` because the adapter and the app model that owns it are.
@MainActor
protocol UserNotificationCenter: AnyObject {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    /// Delete All Data (ticket 30): everything of the app's, pending or already shown.
    func removeAllPendingNotificationRequests()
    func removeAllDeliveredNotifications()
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    /// The center holds its delegate weakly, so the caller must keep it.
    func setDelegate(_ delegate: any UNUserNotificationCenterDelegate)
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func notificationSettings() async -> NotificationSettingsSnapshot
    /// The Icon badge. Zero hides it.
    func setBadgeCount(_ count: Int) async throws
}

/// The real center.
@MainActor
final class SystemNotificationCenter: UserNotificationCenter {
    private let center = UNUserNotificationCenter.current()

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeAllPendingNotificationRequests() {
        center.removeAllPendingNotificationRequests()
    }

    func removeAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        center.setNotificationCategories(categories)
    }

    func setDelegate(_ delegate: any UNUserNotificationCenterDelegate) {
        center.delegate = delegate
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func setBadgeCount(_ count: Int) async throws {
        try await center.setBadgeCount(count)
    }

    func notificationSettings() async -> NotificationSettingsSnapshot {
        let settings = await center.notificationSettings()
        return NotificationSettingsSnapshot(
            authorizationStatus: settings.authorizationStatus,
            timeSensitiveSetting: settings.timeSensitiveSetting,
            badgeSetting: settings.badgeSetting
        )
    }
}
