import Foundation

/// The current time, as the engine sees it. Tests swap in a fake.
public protocol EngineClock {
    var now: Date { get }
}

/// Applies a schedule plan to the system. The app's adapters talk to AlarmKit and the
/// notification center; tests swap in a fake that records the plan.
public protocol SchedulerAdapter {
    func apply(_ plan: SchedulePlan)
}

/// The nudge engine: reminders and the clock in, occurrence state and a schedule plan out.
public struct Engine {
    let clock: any EngineClock
    private let scheduler: any SchedulerAdapter
    private let giveUpLimit: GiveUpLimit
    let calendar: Calendar
    /// Formats the times and dates in a repeat's summary.
    let locale: Locale
    private var reminders: [Reminder] = []
    /// Done is the one occurrence fact the clock can't work out, so the engine records it. An
    /// occurrence is its reminder at one due time, so Done on one day's occurrence of a repeat
    /// leaves the next day's open.
    private var doneOccurrences: Set<OccurrenceKey> = []

    private struct OccurrenceKey: Hashable {
        var reminderID: Reminder.ID
        var dueTime: Date
    }

    /// `timeZone` is where repeats keep their local time of day. `locale` formats the times and
    /// dates in a repeat's summary, including the 12- or 24-hour clock.
    public init(
        clock: any EngineClock,
        scheduler: any SchedulerAdapter,
        timeZone: TimeZone = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) {
        self.init(clock: clock, scheduler: scheduler, giveUpLimit: .shipped, timeZone: timeZone, locale: locale)
    }

    /// Lets tests change the give-up limit. A shorter span is the only way to see it win over the
    /// nudge count with today's ladders, and a wider limit the only way to keep an every-day
    /// reminder Nudging until the next one takes over. Internal because the spec fixes the limit.
    init(
        clock: any EngineClock,
        scheduler: any SchedulerAdapter,
        giveUpLimit: GiveUpLimit,
        timeZone: TimeZone = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) {
        self.clock = clock
        self.scheduler = scheduler
        self.giveUpLimit = giveUpLimit
        // Gregorian whatever the person's own calendar, because RRULE (RFC 5545) is: in, say, the
        // Hebrew calendar Every Month would fall on different days.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.locale = locale
    }

    public mutating func update(reminders: [Reminder]) {
        self.reminders = reminders
        scheduler.apply(plan())
    }

    /// Closes the reminder's open occurrence as Done and cancels everything pending for it. Done
    /// with no open occurrence (not yet due, already Missed or Done) is ignored, as in the
    /// mockup's `ack`: it can race the give-up limit, or come from two places at once, and
    /// neither is something to tell the person about.
    public mutating func markDone(_ reminderID: Reminder.ID) {
        guard let occurrence = openOccurrence(for: reminderID) else { return }
        doneOccurrences.insert(OccurrenceKey(reminderID: reminderID, dueTime: occurrence.dueTime))
        scheduler.apply(plan())
    }

    /// The whole ladder of each reminder's open occurrence and of its next one, even before they
    /// are due. The app gets no callback when a notification or alarm fires, so the chain must
    /// already be pending for nudging to go on, and for the next occurrence to start, while the
    /// app stays closed. A closed occurrence (Done or Missed) has nothing left to send. Each ladder
    /// stops where the occurrence after it falls due and takes over.
    private func plan() -> SchedulePlan {
        SchedulePlan(items: reminders.flatMap { reminder -> [SchedulePlan.Item] in
            var items: [SchedulePlan.Item] = []
            let next = reminder.nextDueTime(after: clock.now, calendar: calendar)
            if let open = openOccurrence(for: reminder.id) {
                items += ladder(of: reminder, dueAt: open.dueTime, takenOverAt: next)
            }
            if let next {
                items += ladder(of: reminder, dueAt: next, takenOverAt: reminder.nextDueTime(after: next, calendar: calendar))
            }
            return items
        })
    }

    /// An occurrence's ladder, stopped where the next occurrence takes over (the mockup's
    /// `simulate` with `until`), so the plan never nudges about two occurrences at once.
    /// `takeOverTime` is the next due time, `nil` if the repeat has none.
    private func ladder(of reminder: Reminder, dueAt dueTime: Date, takenOverAt takeOverTime: Date?) -> [SchedulePlan.Item] {
        let nudgeTimes = reminder.strength.nudgeTimes(from: dueTime, within: giveUpLimit)
        return nudgeTimes.prefix { $0 < takeOverTime ?? .distantFuture }.enumerated().map { index, fireTime in
            let urgency = reminder.strength.urgency(ofNudge: index + 1)
            return SchedulePlan.Item(
                reminderID: reminder.id,
                nudgeNumber: index + 1,
                fireTime: fireTime,
                urgency: urgency,
                title: reminder.title,
                deliveryKind: deliveryKind(of: urgency, for: reminder)
            )
        }
    }

    /// The spec's Delivery by urgency rule. It lives here rather than on the plan item because
    /// the alarms-denied and alarm-limit fallbacks (tickets 14 and 15) depend on system state the
    /// engine knows and an item doesn't. Break through Focus off changes only the delivery kind:
    /// the urgency, and so the notification text, stays on the ladder.
    private func deliveryKind(of urgency: Urgency, for reminder: Reminder) -> DeliveryKind {
        guard reminder.breakThroughFocus else { return .notification }
        switch urgency {
        case .normal: return .notification
        case .high: return .timeSensitiveNotification
        case .urgent: return .alarm
        }
    }

    /// The next `count` due times at or after now, fewer if the repeat ends: what the Custom page
    /// previews (the mockup's `upcoming`). The reminder needn't be one the engine holds, so a
    /// draft can be previewed.
    public func upcomingDueTimes(of reminder: Reminder, count: Int) -> [Date] {
        var dueTimes: [Date] = []
        var after = Date(timeIntervalSinceReferenceDate: clock.now.timeIntervalSinceReferenceDate.nextDown)
        while dueTimes.count < count, let next = reminder.nextDueTime(after: after, calendar: calendar) {
            dueTimes.append(next)
            after = next
        }
        return dueTimes
    }

    /// The reminder's open occurrence, or `nil` if it has none.
    public func openOccurrence(for reminderID: Reminder.ID) -> Occurrence? {
        guard let occurrence = latestOccurrence(for: reminderID),
              case .nudging = occurrence.state
        else { return nil }
        return occurrence
    }

    /// The reminder's latest occurrence, open or closed, or `nil` before its first due time.
    public func latestOccurrence(for reminderID: Reminder.ID) -> Occurrence? {
        guard let reminder = reminders.first(where: { $0.id == reminderID }),
              let dueTime = reminder.latestDueTime(atOrBefore: clock.now, calendar: calendar)
        else { return nil }
        // Its next due time is after now by definition, so nothing has taken it over yet.
        return occurrence(of: reminder, dueAt: dueTime, takenOverAt: nil)
    }

    /// The reminder's occurrence due at `dueTime`, as it stands now, or `nil` if `dueTime` isn't
    /// one of its due times or hasn't come yet. `latestOccurrence(for:)` gives only the newest,
    /// so this is how an earlier one, such as one the next took over, is read back.
    public func occurrence(of reminderID: Reminder.ID, dueAt dueTime: Date) -> Occurrence? {
        guard dueTime <= clock.now,
              let reminder = reminders.first(where: { $0.id == reminderID }),
              reminder.latestDueTime(atOrBefore: dueTime, calendar: calendar) == dueTime
        else { return nil }
        let next = reminder.nextDueTime(after: dueTime, calendar: calendar)
        return occurrence(of: reminder, dueAt: dueTime, takenOverAt: next.flatMap { $0 <= clock.now ? $0 : nil })
    }

    /// The occurrence's state from the clock. `takeOverTime` is when the next occurrence fell
    /// due, or `nil` if it hasn't yet (or the repeat has no next).
    private func occurrence(of reminder: Reminder, dueAt dueTime: Date, takenOverAt takeOverTime: Date?) -> Occurrence {
        if doneOccurrences.contains(OccurrenceKey(reminderID: reminder.id, dueTime: dueTime)) {
            return Occurrence(dueTime: dueTime, state: .done)
        }
        let nudgeTimes = reminder.strength.nudgeTimes(from: dueTime, within: giveUpLimit)
        let giveUpTime = reminder.strength.giveUpTime(from: dueTime, after: nudgeTimes, within: giveUpLimit)
        // A tie goes to the next occurrence, as in the mockup's `simulate` (`takeover: t >= until`).
        if let takeOverTime, takeOverTime <= giveUpTime {
            return Occurrence(dueTime: dueTime, state: .missed(reason: .nextTookOver))
        }
        if clock.now >= giveUpTime {
            return Occurrence(dueTime: dueTime, state: .missed(reason: .giveUpLimit))
        }
        let sent = nudgeTimes.filter { $0 <= clock.now }.count
        return Occurrence(dueTime: dueTime, state: .nudging(nudgeNumber: sent))
    }
}
