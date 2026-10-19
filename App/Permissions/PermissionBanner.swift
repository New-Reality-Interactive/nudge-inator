import NudgeEngine

/// One banner per permission that's missing (DESIGN.md's Permission banner, the mockup's
/// `permBanner`), from `Engine.reach` so it says what the plan does. Not asked yet shows none:
/// onboarding asks.
enum PermissionBanner: Hashable {
    /// Replaces the others, since it already says what can still reach the person.
    case notificationsOff(urgentStillRings: Bool)
    case alarmsOff(urgentIsTimeSensitive: Bool)
    /// Follows the app's Time Sensitive setting, which the person can turn off at any time, not
    /// what they allowed at onboarding.
    case timeSensitiveOff

    static func banners(for reach: Reach) -> [PermissionBanner] {
        guard reach.normal != nil else { return [.notificationsOff(urgentStillRings: reach.urgent == .alarm)] }
        var banners: [PermissionBanner] = []
        if reach.urgent != .alarm {
            banners.append(.alarmsOff(urgentIsTimeSensitive: reach.urgent == .timeSensitiveNotification))
        }
        if reach.high == .notification {
            banners.append(.timeSensitiveOff)
        }
        return banners
    }

    /// Where Open Settings goes: ticket 30's choice, made for this banner alone.
    var openSettings: SettingsStatus.OpenSettings {
        switch self {
        case .alarmsOff: .appSettings
        case .notificationsOff, .timeSensitiveOff: .notificationSettings
        }
    }

    /// Red for notifications off, which means nothing may reach the person; orange otherwise.
    var isNegative: Bool {
        if case .notificationsOff = self { true } else { false }
    }
}
