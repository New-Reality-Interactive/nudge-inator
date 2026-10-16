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

/// Why the engine turned down a Resume.
public enum ResumeError: Error, Equatable, Sendable {
    /// The reminder has no due time after now to resume at.
    case needsNewDueTime
}

/// A reminder field that can't be edited while the reminder is Nudging (ADR 0002).
public enum LockedField: Hashable, CaseIterable, Sendable {
    case dueTime
    case repeatRule
    case strength
    case breakThroughFocus

    /// Whether `edited` gives this field a different value from `current`.
    func isChanged(from current: Reminder, to edited: Reminder) -> Bool {
        switch self {
        case .dueTime: current.dueTime != edited.dueTime
        case .repeatRule: current.repeatRule != edited.repeatRule
        case .strength: current.strength != edited.strength
        case .breakThroughFocus: current.breakThroughFocus != edited.breakThroughFocus
        }
    }
}

/// Why the engine turned down an Edit.
public enum EditError: Error, Equatable, Sendable {
    /// The Edit changed these fields, which are Locked while the reminder is Nudging.
    case locked(Set<LockedField>)
}

/// The nudge engine: reminders and the clock in, occurrence state and a schedule plan out.
public struct Engine {
    let clock: any EngineClock
    private let scheduler: any SchedulerAdapter
    private let giveUpLimit: GiveUpLimit
    let calendar: Calendar
    /// Formats the times and dates in a repeat's summary.
    let locale: Locale
    private var permissions: PermissionStates
    /// Earlier permission states, oldest first, with when the app reported a change. A nudge that
    /// fired before the change was delivered under the old states, so its plan item keeps that
    /// delivery. App-wide, so not in a reminder's `History`.
    private var replacedPermissions: [ReplacedPermissions] = []
    private var reminders: [Reminder] = []
    /// What the engine records about each reminder because the clock can't work it out. Delete
    /// clears it in one go.
    private var histories: [Reminder.ID: History] = [:]

    private struct History {
        /// Occurrences whose state is fixed, by due time. Done is the one the clock can never work
        /// out. An occurrence already Missed or Skipped when an Edit is applied is fixed too, since
        /// the clock would now work it out from the edited fields. Keyed by due time, so Done on
        /// one day's occurrence of a repeat leaves the next day's open.
        var closedOccurrences: [Date: OccurrenceState] = [:]
        /// Every pause, oldest first, the last still open while it's paused. An occurrence still
        /// open during a pause is Skipped, so a due time that passed while paused never comes back
        /// as Nudging after Resume.
        var pauseSpans: [PauseSpan] = []
        /// Earlier titles, oldest first, with when an Edit replaced them. A nudge that fired before
        /// the Edit was delivered with the old title, so its plan item keeps it.
        var replacedTitles: [ReplacedTitle] = []
    }

    private struct ReplacedPermissions {
        var permissions: PermissionStates
        var replacedAt: Date
    }

    private struct ReplacedTitle {
        var title: String
        var replacedAt: Date
    }

    private struct PauseSpan {
        var start: Date
        /// `nil` until Resume.
        var end: Date?
    }

    /// `timeZone` is where repeats keep their local time of day. `locale` formats the times and
    /// dates in a repeat's summary, including the 12- or 24-hour clock.
    public init(
        clock: any EngineClock,
        scheduler: any SchedulerAdapter,
        timeZone: TimeZone = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        permissions: PermissionStates = PermissionStates()
    ) {
        self.init(
            clock: clock,
            scheduler: scheduler,
            giveUpLimit: .shipped,
            timeZone: timeZone,
            locale: locale,
            permissions: permissions
        )
    }

    /// Lets tests change the give-up limit. A shorter span is the only way to see it win over the
    /// nudge count with today's ladders, and a wider limit the only way to keep an every-day
    /// reminder Nudging until the next one takes over. Internal because the spec fixes the limit.
    init(
        clock: any EngineClock,
        scheduler: any SchedulerAdapter,
        giveUpLimit: GiveUpLimit,
        timeZone: TimeZone = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        permissions: PermissionStates = PermissionStates()
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
        self.permissions = permissions
    }

    /// Replaces the whole list: App opened, and the store's reload. It reports what is already
    /// true, so it isn't checked against the lock. The edit form sends `edit(_:)` instead.
    public mutating func update(reminders: [Reminder]) {
        self.reminders = reminders
        scheduler.apply(plan())
    }

    /// The permission states the scheduler adapter reports, at launch and whenever they change.
    /// Nudges not yet delivered take the new delivery; ones already delivered keep theirs. States
    /// that match the current ones change nothing, so they're ignored.
    public mutating func update(permissions: PermissionStates) {
        guard permissions != self.permissions else { return }
        replacedPermissions.append(ReplacedPermissions(permissions: self.permissions, replacedAt: clock.now))
        self.permissions = permissions
        scheduler.apply(plan())
    }

    /// Closes the reminder's open occurrence as Done and cancels everything pending for it. Done
    /// with no open occurrence (not yet due, already Missed or Done) is ignored, as in the
    /// mockup's `ack`: it can race the give-up limit, or come from two places at once, and
    /// neither is something to tell the person about.
    public mutating func markDone(_ reminderID: Reminder.ID) {
        guard let occurrence = openOccurrence(for: reminderID) else { return }
        histories[reminderID, default: History()].closedOccurrences[occurrence.dueTime] = .done
        scheduler.apply(plan())
    }

    /// Stops the reminder nudging without losing it. Its open occurrence, if any, closes as Skipped,
    /// and so does anything that falls due until Resume (the mockup's PAUSE_NOTE). With nothing
    /// open, Pause only marks the reminder paused. Pausing a paused reminder is ignored.
    public mutating func pause(_ reminderID: Reminder.ID) {
        guard !isPaused(reminderID) else { return }
        histories[reminderID, default: History()].pauseSpans.append(PauseSpan(start: clock.now))
        scheduler.apply(plan())
    }

    /// Brings a paused reminder back at its next due time after now. Due times that passed while it
    /// was paused stay Skipped. With no future due time (a Never whose due time has passed, or a
    /// repeat that ended) it throws `needsNewDueTime` and the reminder stays paused: a paused
    /// reminder isn't locked, so the screen sends the person to edit the due time, and Resume then
    /// succeeds (ADR 0002). Resume on a reminder that isn't paused is ignored.
    public mutating func resume(_ reminderID: Reminder.ID) throws(ResumeError) {
        guard isPaused(reminderID), let reminder = reminder(reminderID), let last = histories[reminderID]?.pauseSpans.indices.last
        else { return }
        guard reminder.nextDueTime(after: clock.now, calendar: calendar) != nil else { throw .needsNewDueTime }
        let now = clock.now
        histories[reminderID]?.pauseSpans[last].end = now
        scheduler.apply(plan())
    }

    /// Removes the reminder and cancels everything pending for it. Its occurrences go with it, not
    /// left as Missed, as the mockup's `deleteReminder` drops them. Its history goes too (Done,
    /// pauses, earlier titles), so a reminder that comes back under the same ID inherits no Done,
    /// Skipped, Paused or old title. It goes even when the engine no longer holds the reminder, since `update(reminders:)` may
    /// have dropped it first; with nothing to remove from the plan, no plan is re-applied.
    public mutating func delete(_ reminderID: Reminder.ID) {
        histories[reminderID] = nil
        guard reminder(reminderID) != nil else { return }
        reminders.removeAll { $0.id == reminderID }
        scheduler.apply(plan())
    }

    /// Applies the person's changes to a reminder the engine holds. An Edit that changes a Locked
    /// field is rejected whole, naming the fields it changed, so nothing is half applied. An
    /// accepted Edit applies from the next occurrence: one that has already closed stays as it
    /// closed, even if a slower strength would still be nudging it. Edit of a reminder the engine
    /// doesn't hold is ignored.
    public mutating func edit(_ edited: Reminder) throws(EditError) {
        guard let current = reminder(edited.id) else { return }
        let changed = lockedFields(of: edited.id).filter { $0.isChanged(from: current, to: edited) }
        guard changed.isEmpty else { throw .locked(changed) }
        if let latest = latestOccurrence(for: edited.id), latest.state.isClosed {
            histories[edited.id, default: History()].closedOccurrences[latest.dueTime] = latest.state
        }
        if edited.title != current.title {
            histories[edited.id, default: History()].replacedTitles.append(ReplacedTitle(title: current.title, replacedAt: clock.now))
        }
        reminders = reminders.map { $0.id == edited.id ? edited : $0 }
        scheduler.apply(plan())
    }

    /// The fields an Edit can't change now: all four while the reminder has a Nudging occurrence,
    /// none otherwise. The form and the details screen read the lock from here, not their own rule.
    public func lockedFields(of reminderID: Reminder.ID) -> Set<LockedField> {
        openOccurrence(for: reminderID) == nil ? [] : Set(LockedField.allCases)
    }

    private func reminder(_ reminderID: Reminder.ID) -> Reminder? {
        reminders.first { $0.id == reminderID }
    }

    /// Whether the reminder is paused, so the screen offers Resume rather than Pause.
    public func isPaused(_ reminderID: Reminder.ID) -> Bool {
        histories[reminderID]?.pauseSpans.last.map { $0.end == nil } ?? false
    }

    /// The whole ladder of each reminder's open occurrence and of its next one, even before they
    /// are due. The app gets no callback when a notification or alarm fires, so the chain must
    /// already be pending for nudging to go on, and for the next occurrence to start, while the
    /// app stays closed. A closed occurrence (Done or Missed) has nothing left to send. Each ladder
    /// stops where the occurrence after it falls due and takes over.
    private func plan() -> SchedulePlan {
        SchedulePlan(items: reminders.flatMap { reminder -> [SchedulePlan.Item] in
            if isPaused(reminder.id) { return [] }
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
        return nudgeTimes.prefix { $0 < takeOverTime ?? .distantFuture }.enumerated().compactMap { index, fireTime in
            let urgency = reminder.strength.urgency(ofNudge: index + 1)
            guard let deliveryKind = deliveryKind(of: urgency, breakThroughFocus: reminder.breakThroughFocus, permissions: permissions(firingAt: fireTime)) else { return nil }
            return SchedulePlan.Item(
                reminderID: reminder.id,
                nudgeNumber: index + 1,
                fireTime: fireTime,
                urgency: urgency,
                title: title(of: reminder, firingAt: fireTime),
                deliveryKind: deliveryKind
            )
        }
    }

    /// The title a nudge firing at `fireTime` carries: the one it was delivered with if it fired
    /// before an Edit replaced it, otherwise the reminder's own.
    private func title(of reminder: Reminder, firingAt fireTime: Date) -> String {
        histories[reminder.id]?.replacedTitles.first { fireTime <= $0.replacedAt }?.title ?? reminder.title
    }

    /// The permission states a nudge firing at `fireTime` is delivered under: the ones in force
    /// when it fired, if a change came after, otherwise the current ones. A nudge firing exactly
    /// at a change counts as delivered, as with titles.
    private func permissions(firingAt fireTime: Date) -> PermissionStates {
        replacedPermissions.first { fireTime <= $0.replacedAt }?.permissions ?? permissions
    }

    /// The spec's Delivery by urgency rule, with the weaker fallbacks for denied permissions, or
    /// `nil` when nothing can deliver the nudge. It lives here rather than on the plan item because
    /// the fallbacks depend on system state the engine knows and an item doesn't. Break through
    /// Focus off changes only the delivery kind: the urgency, and so the notification text, stays
    /// on the ladder. Alarms not determined plan as allowed, since the prompt may not have been
    /// shown yet.
    private func deliveryKind(of urgency: Urgency, breakThroughFocus: Bool, permissions: PermissionStates) -> DeliveryKind? {
        if breakThroughFocus, urgency == .urgent, permissions.alarms != .denied { return .alarm }
        guard permissions.notifications == .allowed else { return nil }
        guard breakThroughFocus else { return .notification }
        switch urgency {
        case .normal: return .notification
        // Urgent with alarms denied falls back to High's delivery, ordinary if Time Sensitive is off.
        case .high, .urgent: return permissions.timeSensitive ? .timeSensitiveNotification : .notification
        }
    }

    /// What can still reach the person with the permissions they've given, whatever reminders the
    /// engine holds, as the banners say it (ticket 31).
    public var reach: Reach {
        Reach(
            normal: deliveryKind(of: .normal, breakThroughFocus: true, permissions: permissions),
            high: deliveryKind(of: .high, breakThroughFocus: true, permissions: permissions),
            urgent: deliveryKind(of: .urgent, breakThroughFocus: true, permissions: permissions)
        )
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
        guard let reminder = reminder(reminderID),
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
              let reminder = reminder(reminderID),
              reminder.latestDueTime(atOrBefore: dueTime, calendar: calendar) == dueTime
        else { return nil }
        let next = reminder.nextDueTime(after: dueTime, calendar: calendar)
        return occurrence(of: reminder, dueAt: dueTime, takenOverAt: next.flatMap { $0 <= clock.now ? $0 : nil })
    }

    /// The occurrence's state from the clock. `takeOverTime` is when the next occurrence fell
    /// due, or `nil` if it hasn't yet (or the repeat has no next).
    private func occurrence(of reminder: Reminder, dueAt dueTime: Date, takenOverAt takeOverTime: Date?) -> Occurrence {
        if let closed = histories[reminder.id]?.closedOccurrences[dueTime] {
            return Occurrence(dueTime: dueTime, state: closed)
        }
        let nudgeTimes = reminder.strength.nudgeTimes(from: dueTime, within: giveUpLimit)
        let giveUpTime = reminder.strength.giveUpTime(from: dueTime, after: nudgeTimes, within: giveUpLimit)
        // The first pause that ends at or after the due time is the first the occurrence could be
        // open in. If it hadn't closed by then, it's Skipped: the Nudging one that Pause closes, any
        // due while paused, and one an edit while paused moved to before the pause.
        if let pause = histories[reminder.id]?.pauseSpans.first(where: { dueTime <= $0.end ?? .distantFuture }),
           min(giveUpTime, takeOverTime ?? giveUpTime) > pause.start {
            return Occurrence(dueTime: dueTime, state: .skipped(reason: .paused))
        }
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
