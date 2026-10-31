import Foundation

/// A reminder's status as its status label says it: the details page's hero and the Reminders
/// tab's rows.
public enum ReminderStatus: Equatable, Sendable {
    case nudging
    case paused
    /// Not due yet: its next due time is ahead.
    case comingUp
    /// Nothing more is coming, so how the latest occurrence closed.
    case closed(OccurrenceState)
}

/// The Reminders tab's list: every reminder the engine holds, once, in creation-date order.
public struct RemindersList: Equatable, Sendable {
    public var items: [Item]

    public struct Item: Equatable, Sendable {
        public var reminder: Reminder
        public var status: ReminderStatus
        /// The open occurrence's due time while Nudging, else the next due time (a paused
        /// reminder's is the one it would be Skipped at), else the latest occurrence's.
        public var dueTime: Date
    }
}

extension Engine {
    /// The reminder's status now, or `nil` if the engine doesn't hold it. Nudging while an
    /// occurrence is; Paused while the reminder is; Coming up while a due time is ahead;
    /// otherwise how its latest occurrence closed.
    public func status(of reminderID: Reminder.ID) -> ReminderStatus? {
        reminder(reminderID).map { listItem(of: $0).status }
    }

    /// The Reminders tab's list as it stands now. Oldest creation date first; reminders created at
    /// the same moment (1.2.0's, which share their migration instant) keep the engine's order,
    /// which is the order they were added in.
    public func remindersList() -> RemindersList {
        let ordered = reminders.enumerated().sorted { ($0.element.createdAt, $0.offset) < ($1.element.createdAt, $1.offset) }
        return RemindersList(items: ordered.map { listItem(of: $0.element) })
    }

    /// The next due time after the open occurrence's, if any. The engine reads "at or after now",
    /// so a second is asked for in case the first is the open occurrence's own.
    public func nextDueTime(of reminder: Reminder) -> Date? {
        let openDueTime = openOccurrence(for: reminder.id)?.dueTime ?? .distantPast
        return upcomingDueTimes(of: reminder, count: 2).first { $0 > openDueTime }
    }

    private func listItem(of reminder: Reminder) -> RemindersList.Item {
        let reminderID = reminder.id
        let open = openOccurrence(for: reminderID)
        let next = nextDueTime(of: reminder)
        let latest = latestOccurrence(for: reminderID)
        let status: ReminderStatus
        if open != nil {
            status = .nudging
        } else if isPaused(reminderID) {
            status = .paused
        } else if next != nil {
            status = .comingUp
        } else {
            status = latest.map { .closed($0.state) } ?? .comingUp
        }
        // A reminder with no occurrence and nothing coming (a repeat that ended before its Start)
        // shows its Start.
        let dueTime = open?.dueTime ?? next ?? latest?.dueTime ?? reminder.dueTime
        return RemindersList.Item(reminder: reminder, status: status, dueTime: dueTime)
    }
}
