import Foundation

/// What the person has allowed, as the scheduler adapter reports it. App-wide, not per reminder.
public struct PermissionStates: Equatable, Sendable {
    public var notifications: NotificationPermission
    public var alarms: AlarmPermission
    public var timeSensitive: TimeSensitiveSetting
    /// Only Settings' Badges row reads it: iOS shows no Icon badge while badges are off, so the
    /// plan is the same either way. A change still re-plans, as any permission change does.
    public var badges: BadgePermission

    /// The defaults are a fresh install before anything is denied, as in the mockup's `perm`.
    public init(
        notifications: NotificationPermission = .allowed,
        alarms: AlarmPermission = .notDetermined,
        timeSensitive: TimeSensitiveSetting = .on,
        badges: BadgePermission = .notDetermined
    ) {
        self.notifications = notifications
        self.alarms = alarms
        self.timeSensitive = timeSensitive
        self.badges = badges
    }
}

/// No not-determined state: until the person answers the prompt, nothing is denied, and the
/// engine plans the same as allowed.
public enum NotificationPermission: Equatable, Sendable {
    case allowed
    case denied
}

/// Not determined plans as allowed, since the alarm prompt may not have been shown yet (ticket 31).
public enum AlarmPermission: Equatable, Sendable {
    case allowed
    case denied
    case notDetermined
}

/// The app's Time Sensitive setting (`timeSensitiveSetting`), which the person can turn off on its
/// own after the first Time Sensitive notification, whatever they allowed at onboarding.
public enum TimeSensitiveSetting: Equatable, Sendable {
    case on
    case off
}

/// Whether the Icon badge may show, from the app's badge setting. Not determined covers both
/// before the prompt and an install upgraded from 1.1.0, whose prompt never asked for badges.
public enum BadgePermission: Equatable, Sendable {
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
