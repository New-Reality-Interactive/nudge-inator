import Foundation

/// A status as the sender reads it, in the words of the status label (GLOSSARY.md, Status label).
/// Not `StatusLabel`: that is the app's view of the same words.
public enum ReportedStatus: Equatable, Sendable {
    case nudging
    /// Not due yet.
    case comingUp
    case paused
    case done
    case missed
    /// Closed without Done, and not counted as Missed: a pause, a copy still waiting to be accepted
    /// or a sender's revision closed it.
    case skipped
    /// The recipient removed the copy. The engine no longer holds it, so `statusReport(of:)` never
    /// returns it: the sender's side says it, from what the recipient's app reported.
    case removed
}

extension ReportedStatus {
    init(_ status: ReminderStatus) {
        switch status {
        case .nudging: self = .nudging
        case .paused: self = .paused
        // A waiting copy reports what is coming: the sender's side says Waiting from the receipt
        // (#188). `statusReport(of:)` reads `scheduledStatus(of:)`, so a one-off past its due time
        // reports how that closed.
        case .comingUp, .waiting: self = .comingUp
        // A canceled copy is never reported: the sender deleted it, and says so from its own side.
        case .canceled: self = .skipped
        case .closed(let state): self.init(state)
        }
    }

    init(_ state: OccurrenceState) {
        switch state {
        case .nudging: self = .nudging
        case .done: self = .done
        case .missed: self = .missed
        case .skipped: self = .skipped
        }
    }
}

/// What the engine reports about a received reminder for its sender: its status now, and each
/// occurrence's for today and the 7 days before.
public struct StatusReport: Equatable, Sendable {
    /// The reminder's status now.
    public var label: ReportedStatus
    /// The occurrences due today or in the 7 days before, oldest first. A repeating reminder has
    /// one for each of those days it falls due on; a one-off has its own, if it falls in them.
    public var occurrences: [OccurrenceStatus]

    public init(label: ReportedStatus, occurrences: [OccurrenceStatus]) {
        self.label = label
        self.occurrences = occurrences
    }

    /// One occurrence's status on the day it falls due.
    public struct OccurrenceStatus: Equatable, Sendable {
        public var dueTime: Date
        /// The day `dueTime` falls on, in the engine's calendar.
        public var day: CalendarDay
        public var label: ReportedStatus

        public init(dueTime: Date, day: CalendarDay, label: ReportedStatus) {
            self.dueTime = dueTime
            self.day = day
            self.label = label
        }
    }
}

extension Engine {
    /// How many days before today the report's occurrences reach back.
    static let statusReportDays = 7

    /// The status report of a received reminder, or `nil` for a reminder of the person's own, or one
    /// the engine doesn't hold. Statuses read as the engine reads them for the person: an occurrence
    /// still Nudging reads Missed once it is asked after its give-up limit, however much later.
    /// "Today" and the days before are the local days, in the engine's time zone.
    public func statusReport(of reminderID: Reminder.ID) -> StatusReport? {
        guard let reminder = reminder(reminderID), reminder.isReceived else { return nil }
        let label = ReportedStatus(scheduledStatus(of: reminder))
        let now = clock.now
        let today = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -Self.statusReportDays, to: today),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
        else { return StatusReport(label: label, occurrences: []) }
        let occurrences = dueTimes(of: reminder, in: windowStart...tomorrow.justBefore).compactMap { dueTime in
            occurrenceLabel(of: reminderID, dueAt: dueTime, now: now).map {
                StatusReport.OccurrenceStatus(dueTime: dueTime, day: calendarDay(of: dueTime), label: $0)
            }
        }
        return StatusReport(label: label, occurrences: occurrences)
    }

    /// The label of the occurrence due at `dueTime`: Coming up, or Paused if the reminder is, while
    /// it is ahead; otherwise as the engine reads the occurrence. `nil` for a due time an Edit
    /// means never happened.
    private func occurrenceLabel(of reminderID: Reminder.ID, dueAt dueTime: Date, now: Date) -> ReportedStatus? {
        if dueTime > now { return isPaused(reminderID) ? .paused : .comingUp }
        return occurrence(of: reminderID, dueAt: dueTime).map { ReportedStatus($0.state) }
    }
}
