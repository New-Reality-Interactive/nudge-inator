import Foundation

/// An occurrence with the reminder it belongs to, for lists that mix reminders.
public struct ReminderOccurrence: Equatable, Sendable {
    public var reminderID: Reminder.ID
    public var occurrence: Occurrence
}

/// A reminder's next due time, for Coming Up.
public struct ComingUpItem: Equatable, Sendable {
    public var reminderID: Reminder.ID
    public var dueTime: Date
}

/// An occurrence that closed, with when, for the Last 24 Hours.
public struct ClosedOccurrence: Equatable, Sendable {
    public var reminderID: Reminder.ID
    public var occurrence: Occurrence
    public var closedAt: Date
    /// How many nudges it sent before it closed: "Done after 3 nudges".
    public var nudgesSent: Int
}

extension Engine {
    /// The Now tab's Coming Up: each unpaused reminder's next due time after now, soonest first, up to and
    /// including the same local time 7 days later. Counted in local days, not 7 × 24 hours as the
    /// mockup does, so across a DST change day 7's due time at this time of day is still in.
    public func comingUp() -> [ComingUpItem] {
        let now = clock.now
        guard let end = calendar.date(byAdding: .day, value: 7, to: now) else { return [] }
        let titles = titles
        return reminders
            .filter { !isPaused($0.id) }
            .compactMap { reminder in
                reminder.nextDueTime(after: now, calendar: calendar)
                    .flatMap { $0 <= end ? ComingUpItem(reminderID: reminder.id, dueTime: $0) : nil }
            }
            .inTimeOrder(titles: titles, at: \.dueTime, of: \.reminderID)
    }

    /// The Now tab's nudging cards: every open occurrence, oldest due time first, as the mockup's
    /// `openOccs`.
    public func nudgingOccurrences() -> [ReminderOccurrence] {
        let titles = titles
        return reminders
            .compactMap { reminder in
                openOccurrence(for: reminder.id).map { ReminderOccurrence(reminderID: reminder.id, occurrence: $0) }
            }
            .inTimeOrder(titles: titles, at: \.occurrence.dueTime, of: \.reminderID)
    }

    /// The Now tab's Last 24 Hours: occurrences that closed (Done, Missed or Skipped) from 24 hours
    /// before now up to now, both ends in, newest first. Measured in hours, not local days, so a
    /// DST change doesn't stretch or shrink it.
    public func closedInLast24Hours() -> [ClosedOccurrence] {
        let now = clock.now
        let windowStart = now - 24 * 60 * 60
        let titles = titles
        return reminders
            .flatMap { reminder in
                dueTimes(of: reminder, in: earliestListedDueTime...now).compactMap { dueTime in
                    closedOccurrence(of: reminder.id, dueAt: dueTime)
                        .flatMap { windowStart <= $0.closedAt && $0.closedAt <= now ? $0 : nil }
                }
            }
            .inTimeOrder(titles: titles, at: \.closedAt, of: \.reminderID)
            .reversed()
    }

    /// The reminder's occurrence due at `dueTime` with how it closed, or `nil` while it is Nudging
    /// or if `dueTime` isn't one of its past due times: what a Done row on My Day shows.
    public func closedOccurrence(of reminderID: Reminder.ID, dueAt dueTime: Date) -> ClosedOccurrence? {
        guard let (occurrence, closing) = reading(of: reminderID, dueAt: dueTime), let closing else { return nil }
        return ClosedOccurrence(reminderID: reminderID, occurrence: occurrence, closedAt: closing.closedAt, nudgesSent: closing.nudgesSent)
    }

    /// Each held reminder's title, for putting lists in time order.
    var titles: [Reminder.ID: String] {
        Dictionary(reminders.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
    }
}

extension Array {
    /// In time order, ties by title as in the mockup's `todayItems`, then by reminder ID so the
    /// order never depends on the store's.
    func inTimeOrder(titles: [Reminder.ID: String], at time: (Element) -> Date, of reminderID: (Element) -> Reminder.ID) -> [Element] {
        func key(_ element: Element) -> (Date, String, String) {
            let id = reminderID(element)
            return (time(element), titles[id] ?? "", id.uuidString)
        }
        return sorted { key($0) < key($1) }
    }
}

extension Date {
    /// The instant before this one, for "next due time at or after" from an "after" search.
    var justBefore: Date {
        Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.nextDown)
    }
}
