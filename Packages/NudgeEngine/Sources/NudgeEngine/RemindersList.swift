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

/// What the Reminders tab's list is narrowed by. Nothing chosen narrows nothing.
public struct RemindersFilter: Equatable, Sendable {
    public var tags: TagFilter
    /// The statuses a reminder may have to be shown: it matches any chosen.
    public var statuses: Set<Status>
    /// The strengths a reminder may have to be shown: it matches any chosen.
    public var strengths: Set<Strength>
    /// The first day a reminder may be due to be shown, that day included. `nil` has no first day.
    public var dueFrom: CalendarDay?
    /// The last day a reminder may be due to be shown, that day included. `nil` has no last day.
    public var dueTo: CalendarDay?
    /// The phrase a reminder's title or notes must contain, without leading or trailing whitespace,
    /// so a space typed after a word doesn't change the filter. Empty narrows nothing.
    public var search: String {
        didSet { search = Self.trimmed(search) }
    }

    /// A status as its status label says it, whatever closed the occurrence. In the sheet's order.
    public enum Status: CaseIterable, Sendable {
        case nudging
        case comingUp
        case paused
        case done
        case missed
        case skipped
    }

    public init(
        tags: TagFilter = .off,
        statuses: Set<Status> = [],
        strengths: Set<Strength> = [],
        dueFrom: CalendarDay? = nil,
        dueTo: CalendarDay? = nil,
        search: String = ""
    ) {
        self.tags = tags
        self.statuses = statuses
        self.strengths = strengths
        self.dueFrom = dueFrom
        self.dueTo = dueTo
        self.search = Self.trimmed(search)
    }

    /// Whether the filter sheet is narrowing the list. Search isn't part of it.
    public var hasSheetFilters: Bool {
        tags != .off || !statuses.isEmpty || !strengths.isEmpty || dueFrom != nil || dueTo != nil
    }

    func matches(_ item: RemindersList.Item, tagIDs: Set<Tag.ID>, dueDay: CalendarDay) -> Bool {
        matches(item.status) && matchesStrength(item.reminder) && tags.includes(tagIDs)
            && matchesDueDate(dueDay) && matchesSearch(item.reminder)
    }

    private func matchesDueDate(_ dueDay: CalendarDay) -> Bool {
        (dueFrom.map { $0 <= dueDay } ?? true) && (dueTo.map { dueDay <= $0 } ?? true)
    }

    private func matches(_ status: ReminderStatus) -> Bool {
        statuses.isEmpty || statuses.contains(Status(status))
    }

    private func matchesStrength(_ reminder: Reminder) -> Bool {
        strengths.isEmpty || strengths.contains(reminder.strength)
    }

    /// Ignores case and diacritics. A tag's name isn't searched.
    private func matchesSearch(_ reminder: Reminder) -> Bool {
        search.isEmpty || reminder.title.localizedStandardContains(search) || reminder.notes.localizedStandardContains(search)
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension RemindersFilter.Status {
    init(_ status: ReminderStatus) {
        switch status {
        case .nudging, .closed(.nudging): self = .nudging
        case .paused: self = .paused
        case .comingUp: self = .comingUp
        case .closed(.done): self = .done
        case .closed(.missed): self = .missed
        case .closed(.skipped): self = .skipped
        }
    }
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
        /// reminder's is the one it would be Skipped at), else the latest occurrence's. The Due Date
        /// filter tests this one.
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
    /// is the order they were added in, under Oldest First and Earliest First. Newest First and
    /// Latest First are those orders exactly reversed, ties included: last-added first (spec #104,
    /// Decision 54).
    /// Only reminders `filter` matches are listed, even one just made (spec #104, Decision 20).
    public func remindersList(
        sortedBy sort: RemindersSort = .createdOldestFirst,
        filteredBy filter: RemindersFilter = RemindersFilter()
    ) -> RemindersList {
        // The store may hand back a deleted tag's ID; it is no tag.
        let existingTagIDs = Set(tags.map(\.id))
        let items = reminders.map(listItem(of:)).filter {
            filter.matches($0, tagIDs: existingTagIDs.intersection($0.reminder.tagIDs), dueDay: calendarDay(of: $0.dueTime))
        }
        let key: (RemindersList.Item) -> Date = switch sort.field {
        case .created: \.reminder.createdAt
        case .dueDate: \.dueTime
        }
        let ascending = sort.order == .ascending
        let ordered = items.enumerated().sorted { first, second in
            let (a, b) = (key(first.element), key(second.element))
            guard a != b else { return ascending ? first.offset < second.offset : first.offset > second.offset }
            return ascending ? a < b : a > b
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
        // A reminder with no occurrence and nothing coming shows its Start (spec #104, Decision 60).
        // A defensive fallback: a repeat that ended before its Start still has that Start coming,
        // since a rule's first due time always counts. The one state found that reaches it is a
        // one-off whose due time has passed, with `editAppliesAfter` read back from the store at or
        // after that due time and no closing recorded for it.
        let dueTime = open?.dueTime ?? next ?? latest?.dueTime ?? reminder.dueTime
        return RemindersList.Item(reminder: reminder, status: status, dueTime: dueTime)
    }
}
