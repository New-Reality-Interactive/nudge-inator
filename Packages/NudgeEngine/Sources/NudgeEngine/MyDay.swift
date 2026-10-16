import Foundation

/// Today's occurrences in time order, as the My Day tab lists them.
public struct MyDay: Equatable, Sendable {
    public var items: [Item]

    /// One reminder's due time today. Repeats are at most daily, so a reminder has one, unless an
    /// Edit moved it after an occurrence today had closed.
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

    public func count(of count: MyDayCount) -> Int {
        items.count { $0.countedIn == count }
    }

    /// The list filtered to one count, when the person taps it.
    public func items(countedIn count: MyDayCount) -> [Item] {
        items.filter { $0.countedIn == count }
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
    public var countedIn: MyDayCount? {
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
    case off
    /// Items whose reminder has every one of the tags. With none chosen, every item.
    case matchAll(Set<Tag.ID>)
    /// Items whose reminder has at least one of the tags. With none chosen, every item.
    case matchAny(Set<Tag.ID>)
    /// Items whose reminder has no tags.
    case noTags

    /// Whether a reminder with `tagIDs`, the ones of its tags that still exist, passes.
    func includes(_ tagIDs: Set<Tag.ID>) -> Bool {
        switch self {
        case .off: true
        case .matchAll(let chosen): chosen.isSubset(of: tagIDs)
        case .matchAny(let chosen): chosen.isEmpty || !chosen.isDisjoint(with: tagIDs)
        case .noTags: tagIDs.isEmpty
        }
    }
}

extension Engine {
    /// My Day as it stands now, for the reminders `tagFilter` lets through. The counts cover every
    /// item the tag filter lets through, as in the mockup. "Today" is the local day, in the engine's
    /// time zone, that holds now.
    public func myDay(tagFilter: TagFilter = .off) -> MyDay {
        let now = clock.now
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return MyDay(items: []) }
        // The store may hand back a deleted tag's ID; it is no tag.
        let tagIDs = Set(tags.map(\.id))
        let items = reminders.filter { tagFilter.includes(tagIDs.intersection($0.tagIDs)) }.flatMap { reminder in
            dueTimes(of: reminder, in: start...end.justBefore).compactMap { dueTime -> MyDay.Item? in
                let status: MyDay.Status
                if dueTime > now {
                    status = isPaused(reminder.id) ? .paused : .left
                } else if let occurrence = occurrence(of: reminder.id, dueAt: dueTime) {
                    status = .due(occurrence.state)
                } else {
                    return nil
                }
                return MyDay.Item(reminderID: reminder.id, dueTime: dueTime, status: status)
            }
        }
        return MyDay(items: items.inTimeOrder(titles: titles, at: \.dueTime, of: \.reminderID))
    }
}
