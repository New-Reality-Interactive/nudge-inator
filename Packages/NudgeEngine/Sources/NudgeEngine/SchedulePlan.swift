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

        /// How the nudge reaches the phone. Adapters act on this, not on the urgency.
        public var deliveryKind: DeliveryKind

        /// The nudge would have rung as an alarm, but it is past the alarm limit (the system's,
        /// which the adapter reports, or the engine's own cap), so it falls back to a
        /// notification. The screens say so ("Notification: too many alarms scheduled"); the
        /// notification itself carries only the title and body.
        public var isPastAlarmLimit: Bool

        /// The notification body, for example "Nudge 3 of 20 · High".
        public var body: String {
            "Nudge \(nudgeNumber) of \(GiveUpLimit.shipped.nudgeCount) · \(urgency.name)"
        }
    }
}

/// How a nudge reaches the phone.
public enum DeliveryKind: Equatable, Sendable {
    /// An ordinary notification, which a Focus can hold.
    case notification
    case timeSensitiveNotification
    /// An AlarmKit alarm, which sounds through silent mode and Focus.
    case alarm
}

/// A nudge's place on its strength's ladder.
public enum Urgency: Equatable, Sendable {
    case normal
    case high
    case urgent

    /// The word shown in a notification.
    public var name: String {
        switch self {
        case .normal: "Normal"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }
}
