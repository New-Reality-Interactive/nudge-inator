import Foundation

/// What the person has allowed, as the scheduler adapter reports it. App-wide, not per reminder.
public struct PermissionStates: Equatable, Sendable {
    public var notifications: NotificationPermission
    public var alarms: AlarmPermission
    /// The app's Time Sensitive setting, which the person can turn off on its own.
    public var timeSensitive: Bool

    /// The defaults are a fresh install before anything is denied, as in the mockup's `perm`.
    public init(
        notifications: NotificationPermission = .allowed,
        alarms: AlarmPermission = .notDetermined,
        timeSensitive: Bool = true
    ) {
        self.notifications = notifications
        self.alarms = alarms
        self.timeSensitive = timeSensitive
    }
}

public enum NotificationPermission: Equatable, Sendable {
    case allowed
    case denied
}

public enum AlarmPermission: Equatable, Sendable {
    case allowed
    case denied
    case notDetermined
}

/// What can still reach the person: how a nudge of each urgency arrives with Break through Focus
/// on, or `nil` if it can't arrive at all. The permission banners read it rather than the
/// permissions, so they say what the plan does.
public struct Reach: Equatable, Sendable {
    public var normal: DeliveryKind?
    public var high: DeliveryKind?
    public var urgent: DeliveryKind?

    public init(normal: DeliveryKind?, high: DeliveryKind?, urgent: DeliveryKind?) {
        self.normal = normal
        self.high = high
        self.urgent = urgent
    }
}
