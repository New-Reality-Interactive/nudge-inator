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

/// How the Reminders tab's list is ordered: the Sort menu's choice.
public struct RemindersSort: Equatable, Sendable {
    public var field: Field
    public var order: Order

    public enum Field: String, CaseIterable, Sendable {
        /// By creation date.
        case created
        /// By the due time each row shows.
        case dueDate
    }

    public enum Order: String, CaseIterable, Sendable {
        /// Oldest First, or Earliest First.
        case ascending
        /// Newest First, or Latest First.
        case descending
    }

    public init(field: Field, order: Order) {
        self.field = field
        self.order = order
    }

    /// Out of the box, and after Delete All Data.
    public static let createdOldestFirst = RemindersSort(field: .created, order: .ascending)
}

/// The Reminders tab's list: every reminder the engine holds, once, in the Sort menu's order.
public struct RemindersList: Equatable, Sendable {
    public var items: [Item]
    /// Every reminder the engine holds, the header row's "out of" number, however few are shown.
    public var total: Int

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

    /// The Reminders tab's list as it stands now, in `sort`'s order. Reminders that tie (1.2.0's,
    /// which share their migration instant, or two due at one time) keep the engine's order, which
    /// is the order they were added in, under both orders: Newest First isn't Oldest First reversed.
    public func remindersList(sortedBy sort: RemindersSort = .createdOldestFirst) -> RemindersList {
        let items = reminders.map(listItem(of:))
        let key: (RemindersList.Item) -> Date = switch sort.field {
        case .created: \.reminder.createdAt
        case .dueDate: \.dueTime
        }
        let ordered = items.enumerated().sorted { first, second in
            let (a, b) = (key(first.element), key(second.element))
            guard a != b else { return first.offset < second.offset }
            return sort.order == .ascending ? a < b : a > b
        }
        return RemindersList(items: ordered.map(\.element), total: reminders.count)
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
