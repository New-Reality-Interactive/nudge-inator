import Foundation

/// The alarms and notifications that should be pending.
public struct SchedulePlan: Equatable, Sendable {
    public var items: [Item]

    /// One planned nudge. It carries only the reminder's title, never its notes or tags.
    public struct Item: Equatable, Sendable {
        public var reminderID: Reminder.ID
        public var nudgeNumber: Int
        public var fireTime: Date
        public var urgency: Urgency
        public var title: String

        /// How the nudge reaches the phone. Gentle never reaches Urgent, so it is never an alarm.
        /// Ticket 05 adds Break through Focus off; until then this is the switch-on mapping.
        public var deliveryKind: DeliveryKind {
            switch urgency {
            case .normal: .notification
            case .high: .timeSensitiveNotification
            }
        }

        /// The notification body, for example "Nudge 3 of 20 · High".
        public var body: String {
            "Nudge \(nudgeNumber) of \(GiveUpLimit.nudgeCount) · \(urgency.name)"
        }
    }
}

/// How a nudge reaches the phone.
public enum DeliveryKind: Equatable, Sendable {
    /// An ordinary notification, which a Focus can hold.
    case notification
    case timeSensitiveNotification
}

/// A nudge's place on its strength's ladder.
public enum Urgency: Equatable, Sendable {
    case normal
    case high

    /// The word shown in a notification.
    public var name: String {
        switch self {
        case .normal: "Normal"
        case .high: "High"
        }
    }
}
