import Foundation

/// An occurrence with the reminder it belongs to, for lists that mix reminders.
public struct ReminderOccurrence: Equatable, Sendable {
    public var reminderID: Reminder.ID
    public var occurrence: Occurrence
}

/// A reminder's next due time, for Coming Up.
public struct UpcomingDueTime: Equatable, Sendable {
    public var reminderID: Reminder.ID
    public var dueTime: Date
}

/// An occurrence that closed, with when, for the Last 24 Hours.
public struct ClosedOccurrence: Equatable, Sendable {
    public var reminderID: Reminder.ID
    public var occurrence: Occurrence
    public var closedAt: Date
}

extension Engine {
    /// The Now tab's Coming Up: each unpaused reminder's next due time after now, soonest first, up to and
    /// including the same local time 7 days later. Counted in local days, not 7 × 24 hours as the
    /// mockup does, so across a DST change day 7's due time at this time of day is still in.
    public func comingUp() -> [UpcomingDueTime] {
        let now = clock.now
        guard let end = calendar.date(byAdding: .day, value: 7, to: now) else { return [] }
        return reminders
            .filter { !isPaused($0.id) }
            .compactMap { reminder in
                reminder.nextDueTime(after: now, calendar: calendar)
                    .flatMap { $0 <= end ? UpcomingDueTime(reminderID: reminder.id, dueTime: $0) : nil }
            }
            .sorted { ($0.dueTime, $0.reminderID.uuidString) < ($1.dueTime, $1.reminderID.uuidString) }
    }

    /// The Now tab's nudging cards: every open occurrence, oldest due time first, as the mockup's
    /// `openOccs`. Ties go by reminder ID so the order is fixed.
    public func nudgingOccurrences() -> [ReminderOccurrence] {
        reminders
            .compactMap { reminder in
                openOccurrence(for: reminder.id).map { ReminderOccurrence(reminderID: reminder.id, occurrence: $0) }
            }
            .sorted { ($0.occurrence.dueTime, $0.reminderID.uuidString) < ($1.occurrence.dueTime, $1.reminderID.uuidString) }
    }

    /// The Now tab's Last 24 Hours: occurrences that closed (Done, Missed or Skipped) from 24 hours
    /// before now up to now, both ends in, newest first. Measured in hours, not local days, so a
    /// DST change doesn't stretch or shrink it.
    public func closedInLast24Hours() -> [ClosedOccurrence] {
        let now = clock.now
        let windowStart = now - 24 * 60 * 60
        // An occurrence closes within the give-up span of its due time, so one due earlier closed
        // before the window.
        let earliestDueTime = Date(timeIntervalSinceReferenceDate: (windowStart - giveUpLimit.span).timeIntervalSinceReferenceDate.nextDown)
        return reminders
            .flatMap { reminder in
                var closed: [ClosedOccurrence] = []
                var after = earliestDueTime
                while let dueTime = reminder.nextDueTime(after: after, calendar: calendar), dueTime <= now {
                    if let (occurrence, closedAt) = occurrenceWithCloseTime(of: reminder.id, dueAt: dueTime),
                       let closedAt, windowStart <= closedAt, closedAt <= now {
                        closed.append(ClosedOccurrence(reminderID: reminder.id, occurrence: occurrence, closedAt: closedAt))
                    }
                    after = dueTime
                }
                return closed
            }
            .sorted { ($0.closedAt, $0.reminderID.uuidString) > ($1.closedAt, $1.reminderID.uuidString) }
    }
}
