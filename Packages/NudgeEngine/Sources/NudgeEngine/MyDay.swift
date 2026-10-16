import Foundation

/// Today's occurrences in time order, as the My Day tab lists them.
public struct MyDay: Equatable, Sendable {
    public var items: [Item]

    /// One reminder's due time today. Repeats are at most daily, so a reminder has one at most.
    public struct Item: Equatable, Sendable {
        public var reminderID: Reminder.ID
        public var dueTime: Date
        public var status: Status
    }

    public enum Status: Equatable, Sendable {
        /// Come due: the occurrence as it stands now.
        case due(OccurrenceState)
        /// Due later today.
        case left
        /// Due later today, but its reminder is paused, so it will be Skipped unless resumed first.
        case paused
    }

    /// How many items are in the count.
    public func count(of count: MyDayCount) -> Int {
        items.count { $0.count == count }
    }

    /// The list filtered to one count, when the person taps it.
    public func items(in count: MyDayCount) -> [Item] {
        items.filter { $0.count == count }
    }
}

/// My Day's counts, which double as a filter. Skipped and paused items are in none: a pause
/// isn't counted against the person as Missed is.
public enum MyDayCount: CaseIterable, Sendable {
    case done
    case nudging
    case missed
    case left
}

extension MyDay.Item {
    /// The count the item is in, or `nil` for Skipped and paused.
    public var count: MyDayCount? {
        switch status {
        case .due(.done): .done
        case .due(.nudging): .nudging
        case .due(.missed): .missed
        case .due(.skipped), .paused: nil
        case .left: .left
        }
    }
}

/// My Day's tag filter, as the mockup's `inDayFilter` applies it. It covers today only: filtering
/// every reminder by several tags is out of scope.
public enum TagFilter: Equatable, Sendable {
    /// Every item.
    case off
    /// Items whose reminder has every one of the tags. With none chosen, every item.
    case matchAll(Set<Tag.ID>)
    /// Items whose reminder has at least one of the tags. With none chosen, every item.
    case matchAny(Set<Tag.ID>)
    /// Items whose reminder has no tags.
    case noTags

    func includes(_ reminder: Reminder) -> Bool {
        switch self {
        case .off: true
        case .matchAll(let tagIDs): tagIDs.isSubset(of: reminder.tagIDs)
        case .matchAny(let tagIDs): tagIDs.isEmpty || !tagIDs.isDisjoint(with: reminder.tagIDs)
        case .noTags: reminder.tagIDs.isEmpty
        }
    }
}

extension Engine {
    /// My Day as it stands now, for the reminders `tagFilter` lets through. The counts cover every
    /// item the tag filter lets through, as in the mockup. "Today" is the local day, in the engine's
    /// time zone, that holds now. Ties in time go by title, as in the mockup's `todayItems`, then
    /// by ID so the order is fixed.
    public func myDay(tagFilter: TagFilter = .off) -> MyDay {
        let now = clock.now
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return MyDay(items: []) }
        let justBeforeStart = Date(timeIntervalSinceReferenceDate: start.timeIntervalSinceReferenceDate.nextDown)
        let items = reminders.filter(tagFilter.includes).compactMap { reminder -> (MyDay.Item, String)? in
            guard let dueTime = reminder.nextDueTime(after: justBeforeStart, calendar: calendar), dueTime < end else { return nil }
            let status: MyDay.Status
            if dueTime <= now, let occurrence = occurrence(of: reminder.id, dueAt: dueTime) {
                status = .due(occurrence.state)
            } else {
                status = isPaused(reminder.id) ? .paused : .left
            }
            return (MyDay.Item(reminderID: reminder.id, dueTime: dueTime, status: status), reminder.title)
        }
        return MyDay(items: items
            .sorted { ($0.0.dueTime, $0.1, $0.0.reminderID.uuidString) < ($1.0.dueTime, $1.1, $1.0.reminderID.uuidString) }
            .map(\.0))
    }
}
