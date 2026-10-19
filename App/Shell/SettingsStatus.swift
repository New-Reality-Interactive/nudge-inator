import NudgeEngine
import UIKit

/// What Settings' rows say about the permissions the adapters last read, and where its one
/// Open iOS Settings row goes. Nothing here asks the system: the states come from the adapters.
struct SettingsStatus: Equatable {
    let notifications: NotificationsStatus
    let alarms: AlarmsStatus
    let openSettings: OpenSettings?
    let canSendTestNudge: Bool

    init(_ states: PermissionStates) {
        switch (states.notifications, states.timeSensitive) {
        case (.denied, _): notifications = .off
        case (.allowed, .off): notifications = .timeSensitiveOff
        case (.allowed, .on): notifications = .on
        }
        switch states.alarms {
        case .allowed: alarms = .on
        case .denied: alarms = .off
        case .notDetermined: alarms = .notSet
        }
        // Alarms first: only the app's page in Settings reaches them, and it links on to Notifications.
        if alarms == .off {
            openSettings = .appSettings
        } else if notifications.isOff {
            openSettings = .notificationSettings
        } else {
            openSettings = nil
        }
        canSendTestNudge = states.notifications == .allowed
    }

    /// Where the Open iOS Settings row goes.
    enum OpenSettings: Equatable {
        /// The app's notification settings, where the notification and Time Sensitive switches are.
        case notificationSettings
        /// The app's own page in Settings, which is where to turn alarms back on.
        case appSettings

        var urlString: String {
            switch self {
            case .notificationSettings: UIApplication.openNotificationSettingsURLString
            case .appSettings: UIApplication.openSettingsURLString
            }
        }
    }
}

enum NotificationsStatus: Equatable {
    case on
    /// Notifications are allowed but Time Sensitive is switched off.
    case timeSensitiveOff
    case off

    var isOff: Bool { self != .on }
}

enum AlarmsStatus: Equatable {
    case on
    case off
    /// The person hasn't been asked yet, which isn't a problem to flag (ticket 31 asks).
    case notSet

    var isOff: Bool { self == .off }
}

/// One sentence of the footer under Settings' Nudges rows.
enum FooterSentence: Hashable {
    case normalIsOrdinary
    case highIsTimeSensitive
    case highIsOrdinary
    case urgentRingsAsAlarms
    case urgentIsTimeSensitive
    case urgentIsOrdinary
    case allowInFocus
    case changeInSettings
}

extension SettingsStatus {
    /// What the engine says reaches the person with Break Through Focus on (the mockup's footer),
    /// one sentence per urgency, from `Engine.reach` rather than the permissions again. With
    /// notifications off only the way to change that is left.
    static func footer(for reach: Reach) -> [FooterSentence] {
        guard reach.normal != nil else { return [.changeInSettings] }
        var sentences: [FooterSentence] = [.normalIsOrdinary]
        sentences.append(reach.high == .timeSensitiveNotification ? .highIsTimeSensitive : .highIsOrdinary)
        switch reach.urgent {
        case .alarm: sentences.append(.urgentRingsAsAlarms)
        case .timeSensitiveNotification: sentences.append(.urgentIsTimeSensitive)
        case .notification, nil: sentences.append(.urgentIsOrdinary)
        }
        return sentences + [.allowInFocus, .changeInSettings]
    }
}
