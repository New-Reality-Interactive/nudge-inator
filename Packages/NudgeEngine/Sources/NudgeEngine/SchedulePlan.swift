import Foundation

/// The alarms and notifications that should be pending.
public struct SchedulePlan: Equatable, Sendable {
    public var items: [Item]

    /// Public so the app's adapter tests can hand an adapter a plan without running the engine.
    public init(items: [Item]) {
        self.items = items
    }

    /// One planned nudge. It carries only the reminder's title, never its notes or tags.
    public struct Item: Equatable, Sendable {
        public var reminderID: Reminder.ID
        public var nudgeNumber: Int
        /// The nudges its occurrence sends in all, the "of 20" in its body: the give-up limit's
        /// count, fewer if the span or a take-over comes first.
        public var nudgesInAll: Int
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

        public init(
            reminderID: Reminder.ID,
            nudgeNumber: Int,
            nudgesInAll: Int,
            fireTime: Date,
            urgency: Urgency,
            title: String,
            deliveryKind: DeliveryKind,
            isPastAlarmLimit: Bool = false
        ) {
            self.reminderID = reminderID
            self.nudgeNumber = nudgeNumber
            self.nudgesInAll = nudgesInAll
            self.fireTime = fireTime
            self.urgency = urgency
            self.title = title
            self.deliveryKind = deliveryKind
            self.isPastAlarmLimit = isPastAlarmLimit
        }

        /// The notification body, for example "Nudge 3 of 20 · High", in the app's language.
        public var body: String {
            let urgency = urgency.name
            return String(localized: "Nudge \(nudgeNumber) of \(nudgesInAll) · \(urgency)", bundle: .module,
                          comment: "Notification body: never the notes or tags. 1: which nudge this is. 2: how many nudges its occurrence sends in all. 3: the urgency, such as High.")
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

    /// The urgency's word, in the app's language, as a notification and the screens show it.
    public var name: String {
        switch self {
        case .normal: String(localized: "Normal", bundle: .module, comment: "Urgency: a nudge on the first rung of its ladder, as in \"Nudge 1 of 20 · Normal\".")
        case .high: String(localized: "High", bundle: .module, comment: "Urgency: a nudge that has escalated, as in \"Nudge 3 of 20 · High\".")
        case .urgent: String(localized: "Urgent", bundle: .module, comment: "Urgency: a nudge at the top of its ladder, which may ring as an alarm, as in \"Nudge 4 of 20 · Urgent\".")
        }
    }
}
