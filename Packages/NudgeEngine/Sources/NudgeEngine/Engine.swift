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
    let giveUpLimit: GiveUpLimit
    private let alarmLimit: AlarmLimit
    let calendar: Calendar
    /// Formats the times and dates in a repeat's summary.
    let locale: Locale
    private var permissions: PermissionStates
    /// Earlier permission states, oldest first, with when the app reported a change. A nudge that
    /// fired before the change was delivered under the old states, so its plan item keeps that
    /// delivery. App-wide, so not in a reminder's `History`.
    private var replacedPermissions: [Replaced<PermissionStates>] = []
    public private(set) var reminders: [Reminder] = []
    /// Every tag, whether or not a reminder uses it.
    public internal(set) var tags: [Tag] = []
    /// What the engine records about each reminder because the clock can't work it out. Delete
    /// clears it in one go.
    private var histories: [Reminder.ID: History] = [:]

    private struct History {
        /// Occurrences whose state is fixed, by due time, with how they closed. Done is the one the
        /// clock can never work out. An occurrence already closed when an Edit is applied is fixed
        /// too, since the clock would now work it out from the edited fields: the latest, and every
        /// one the Now tab's Last 24 Hours can still list. Keyed by due time, so Done on one day's
        /// occurrence of a repeat leaves the next day's open. A fixed one stays even when an Edit
        /// moves the due times away from it.
        var closedOccurrences: [Date: Closing] = [:]
        /// The latest occurrence's due time when an Edit last changed the due time, repeat or
        /// strength. The Edit applies from the next occurrence, so the edited fields' due times up
        /// to this one never happened; the ones that did are in `closedOccurrences`. A due time the
        /// Edit moved to after it, even one already past, is the next occurrence (ticket 13).
        var editAppliesAfter: Date?
        /// Every pause, oldest first, the last still open while it's paused. An occurrence still
        /// open during a pause is Skipped, so a due time that passed while paused never comes back
        /// as Nudging after Resume.
        var pauseSpans: [PauseSpan] = []
        /// Earlier titles, oldest first, with when an Edit replaced them. A nudge that fired before
        /// the Edit was delivered with the old title, so its plan item keeps it.
        var replacedTitles: [Replaced<String>] = []
        /// Fire times of nudges whose alarm the system turned down with its alarm limit. Kept until
        /// they fire: ticket 02 couldn't show that an alarm that rang frees a slot.
        var reportedAlarmLimitFireTimes: Set<Date> = []
        /// Fire times of nudges past the engine's own cap when a plan was applied. The engine knows
        /// its own count, so ones yet to fire are worked out again for each plan; ones that fired
        /// keep the delivery they had.
        var alarmCapFireTimes: Set<Date> = []

        func isPastAlarmLimit(firingAt fireTime: Date) -> Bool {
            reportedAlarmLimitFireTimes.contains(fireTime) || alarmCapFireTimes.contains(fireTime)
        }
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

    /// Lets tests change the give-up limit and the alarm limit. A shorter span is the only way to
    /// see it win over the nudge count with today's ladders, and a wider limit the only way to keep
    /// an every-day reminder Nudging until the next one takes over. A small alarm limit is the only
    /// way to reach it without thousands of reminders. Internal because both limits are fixed.
    init(
        clock: any EngineClock,
        scheduler: any SchedulerAdapter,
        giveUpLimit: GiveUpLimit,
        alarmLimit: AlarmLimit = .shipped,
        timeZone: TimeZone = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        permissions: PermissionStates = PermissionStates()
    ) {
        self.clock = clock
        self.scheduler = scheduler
        self.giveUpLimit = giveUpLimit
        self.alarmLimit = alarmLimit
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
        applyPlan()
    }

    /// Replaces the whole tag list: App opened, and the store's reload. Like `update(reminders:)`,
    /// it reports what is already true, so the names aren't checked.
    public mutating func update(tags: [Tag]) {
        self.tags = tags
    }

    /// Removes the tag and takes it off every reminder, which stays. Returns how many reminders
    /// used it. The store makes the same change to what it saved (ticket 17). Tags never reach a
    /// schedule plan, so none is applied.
    @discardableResult
    public mutating func deleteTag(_ tagID: Tag.ID) -> Int {
        tags.removeAll { $0.id == tagID }
        var used = 0
        for index in reminders.indices where reminders[index].tagIDs.contains(tagID) {
            reminders[index].tagIDs.removeAll { $0 == tagID }
            used += 1
        }
        return used
    }

    /// The permission states the scheduler adapter reports, at launch and whenever they change.
    /// Nudges not yet delivered take the new delivery; ones already delivered keep theirs. States
    /// that match the current ones change nothing, so they're ignored. The change counts from when
    /// the app hears of it, not when the person made it in Settings, which the app can't know.
    public mutating func update(permissions: PermissionStates) {
        guard permissions != self.permissions else { return }
        // No plan item fires more than the give-up span before now, so older records can't apply.
        let oldestFireTime = clock.now - giveUpLimit.span
        replacedPermissions.removeAll { $0.replacedAt < oldestFireTime }
        replacedPermissions.append(Replaced(value: self.permissions, replacedAt: clock.now))
        self.permissions = permissions
        applyPlan()
    }

    /// The scheduler adapter's report that the alarm for the reminder's nudge firing at
    /// `fireTime` failed with the system's alarm limit (`maximumLimitReached`). That nudge falls
    /// back to a Time Sensitive notification marked `isPastAlarmLimit`; the rest of the ladder
    /// stays as it is. It stays a notification until it fires, even after other alarms ring, since
    /// ticket 02 couldn't show that a slot frees up. An Edit that moves the ladder forgets it. A report the
    /// plan has no alarm for (not held, already fallen back, already fired) is ignored, since the
    /// adapter can send one stale after a re-plan.
    public mutating func markAlarmLimitReached(_ reminderID: Reminder.ID, firingAt fireTime: Date) {
        guard fireTime > clock.now, plan().items.contains(where: {
            $0.reminderID == reminderID && $0.fireTime == fireTime && $0.deliveryKind == .alarm
        }) else { return }
        histories[reminderID, default: History()].reportedAlarmLimitFireTimes.insert(fireTime)
        applyPlan()
    }

    /// Closes the reminder's open occurrence as Done and cancels everything pending for it. Done
    /// with no open occurrence (not yet due, already Missed or Done) is ignored, as in the
    /// mockup's `ack`: it can race the give-up limit, or come from two places at once, and
    /// neither is something to tell the person about.
    public mutating func markDone(_ reminderID: Reminder.ID) {
        guard let occurrence = openOccurrence(for: reminderID),
              case let .nudging(nudgeNumber) = occurrence.state
        else { return }
        histories[reminderID, default: History()].closedOccurrences[occurrence.dueTime] = Closing(
            state: .done,
            closedAt: clock.now,
            nudgesSent: nudgeNumber
        )
        applyPlan()
    }

    /// Stops the reminder nudging without losing it. Its open occurrence, if any, closes as Skipped,
    /// and so does anything that falls due until Resume (the mockup's PAUSE_NOTE). With nothing
    /// open, Pause only marks the reminder paused. Pausing a paused reminder is ignored.
    public mutating func pause(_ reminderID: Reminder.ID) {
        guard !isPaused(reminderID) else { return }
        histories[reminderID, default: History()].pauseSpans.append(PauseSpan(start: clock.now))
        applyPlan()
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
        applyPlan()
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
        applyPlan()
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
        if [LockedField.dueTime, .repeatRule, .strength].contains(where: { $0.isChanged(from: current, to: edited) }) {
            let now = clock.now
            let latest = latestOccurrence(for: current.id)?.dueTime
            for dueTime in [latest].compactMap(\.self) + dueTimes(of: current, in: earliestListedDueTime...now) {
                if let closing = reading(of: current.id, dueAt: dueTime)?.closing {
                    histories[edited.id, default: History()].closedOccurrences[dueTime] = closing
                }
            }
            if let latest { histories[edited.id, default: History()].editAppliesAfter = latest }
            // The system's answer was about fire times the moved ladder no longer has. A new time
            // landing on an old one would otherwise come marked with no report.
            if let reported = histories[edited.id]?.reportedAlarmLimitFireTimes {
                histories[edited.id]?.reportedAlarmLimitFireTimes = reported.filter { $0 <= now }
            }
        }
        if edited.title != current.title {
            histories[edited.id, default: History()].replacedTitles.append(Replaced(value: current.title, replacedAt: clock.now))
        }
        reminders = reminders.map { $0.id == edited.id ? edited : $0 }
        applyPlan()
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

    /// Hands the plan to the scheduler, with the alarms past the engine's alarm limit fallen back.
    private mutating func applyPlan() {
        pruneAlarmLimitRecords()
        fallBackAlarmsPastTheCap()
        scheduler.apply(plan())
    }

    /// No plan item fires more than the give-up span before now, so older records can't apply.
    /// The cap's records for nudges yet to fire go too, for `fallBackAlarmsPastTheCap` to redo.
    private mutating func pruneAlarmLimitRecords() {
        let oldestFireTime = clock.now - giveUpLimit.span
        let now = clock.now
        for (id, history) in histories {
            histories[id]?.reportedAlarmLimitFireTimes = history.reportedAlarmLimitFireTimes.filter { $0 >= oldestFireTime }
            histories[id]?.alarmCapFireTimes = history.alarmCapFireTimes.filter { oldestFireTime <= $0 && $0 <= now }
        }
    }

    /// Keeps the soonest alarms yet to ring within the engine's alarm limit and records the rest.
    /// Ties go by reminder ID, so the order the store lists reminders in doesn't decide.
    private mutating func fallBackAlarmsPastTheCap() {
        let alarms = plan().items
            .filter { $0.deliveryKind == .alarm && $0.fireTime > clock.now }
            .sorted { ($0.fireTime, $0.reminderID.uuidString) < ($1.fireTime, $1.reminderID.uuidString) }
        for item in alarms.dropFirst(alarmLimit.pendingAlarms) {
            histories[item.reminderID, default: History()].alarmCapFireTimes.insert(item.fireTime)
        }
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
            guard let delivery = delivery(
                of: urgency,
                breakThroughFocus: reminder.breakThroughFocus,
                permissions: permissions(firingAt: fireTime),
                alarmLimitReached: histories[reminder.id]?.isPastAlarmLimit(firingAt: fireTime) ?? false
            ) else { return nil }
            return SchedulePlan.Item(
                reminderID: reminder.id,
                nudgeNumber: index + 1,
                fireTime: fireTime,
                urgency: urgency,
                title: title(of: reminder, firingAt: fireTime),
                deliveryKind: delivery.kind,
                isPastAlarmLimit: delivery.isPastAlarmLimit
            )
        }
    }

    /// The title a nudge firing at `fireTime` carries: the one it was delivered with if it fired
    /// before an Edit replaced it, otherwise the reminder's own.
    private func title(of reminder: Reminder, firingAt fireTime: Date) -> String {
        histories[reminder.id]?.replacedTitles.value(firingAt: fireTime) ?? reminder.title
    }

    /// The permission states a nudge firing at `fireTime` is delivered under: the ones in force
    /// when it fired, if a change came after, otherwise the current ones. A nudge firing exactly
    /// at a change counts as delivered, as with titles.
    private func permissions(firingAt fireTime: Date) -> PermissionStates {
        replacedPermissions.value(firingAt: fireTime) ?? permissions
    }

    /// The spec's Delivery by urgency rule, with the weaker fallbacks for denied permissions and
    /// the alarm limit, or `nil` when nothing can deliver the nudge. It lives here rather than on
    /// the plan item because the fallbacks depend on system state the engine knows and an item
    /// doesn't. Break through Focus off changes only the delivery kind: the urgency, and so the
    /// notification text, stays on the ladder. Alarms not determined plan as allowed, since the
    /// prompt may not have been shown yet. Past the alarm limit, an Urgent nudge takes the
    /// alarms-denied fallback, so it also follows notifications denied and Time Sensitive off. It
    /// is marked only when it would otherwise ring: with alarms denied or the switch off, that is
    /// the reason it's a notification, and the screens say so instead.
    private func delivery(
        of urgency: Urgency,
        breakThroughFocus: Bool,
        permissions: PermissionStates,
        alarmLimitReached: Bool
    ) -> (kind: DeliveryKind, isPastAlarmLimit: Bool)? {
        if breakThroughFocus, urgency == .urgent, permissions.alarms != .denied {
            guard alarmLimitReached else { return (.alarm, false) }
            return notificationKind(of: urgency, breakThroughFocus: breakThroughFocus, permissions: permissions)
                .map { ($0, true) }
        }
        return notificationKind(of: urgency, breakThroughFocus: breakThroughFocus, permissions: permissions)
            .map { ($0, false) }
    }

    /// How a nudge that doesn't ring arrives, or `nil` with notifications denied.
    private func notificationKind(of urgency: Urgency, breakThroughFocus: Bool, permissions: PermissionStates) -> DeliveryKind? {
        guard permissions.notifications == .allowed else { return nil }
        guard breakThroughFocus else { return .notification }
        switch urgency {
        case .normal: return .notification
        // Urgent that falls back takes High's delivery, ordinary if Time Sensitive is off.
        case .high, .urgent: return permissions.timeSensitive == .on ? .timeSensitiveNotification : .notification
        }
    }

    /// What can still reach the person with the permissions they've given, whatever reminders the
    /// engine holds, as the banners say it (ticket 31).
    public var reach: Reach {
        Reach(
            normal: delivery(of: .normal, breakThroughFocus: true, permissions: permissions, alarmLimitReached: false)?.kind,
            high: delivery(of: .high, breakThroughFocus: true, permissions: permissions, alarmLimitReached: false)?.kind,
            urgent: delivery(of: .urgent, breakThroughFocus: true, permissions: permissions, alarmLimitReached: false)?.kind
        )
    }

    /// The next `count` due times at or after now, fewer if the repeat ends: what the Custom page
    /// previews (the mockup's `upcoming`). The reminder needn't be one the engine holds, so a
    /// draft can be previewed.
    public func upcomingDueTimes(of reminder: Reminder, count: Int) -> [Date] {
        var dueTimes: [Date] = []
        var after = clock.now.justBefore
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
        guard let reminder = reminder(reminderID) else { return nil }
        let now = clock.now
        let computed = reminder.latestDueTime(atOrBefore: now, calendar: calendar).flatMap { isBeforeScheduleChange($0, of: reminderID) ? nil : $0 }
        let recorded = histories[reminderID]?.closedOccurrences.keys.filter { $0 <= now }.max()
        guard let dueTime = [computed, recorded].compactMap(\.self).max() else { return nil }
        // Its next due time is after now by definition, so nothing has taken it over yet.
        return occurrence(of: reminder, dueAt: dueTime, takenOverAt: nil).occurrence
    }

    /// The reminder's due times in `range`, its fields' and the fixed ones', oldest first. Read
    /// each with `reading(of:dueAt:)`, which drops the ones an Edit means never happened.
    func dueTimes(of reminder: Reminder, in range: ClosedRange<Date>) -> [Date] {
        var dueTimes = Set(histories[reminder.id]?.closedOccurrences.keys.filter(range.contains) ?? [])
        var after = range.lowerBound.justBefore
        while let dueTime = reminder.nextDueTime(after: after, calendar: calendar), dueTime <= range.upperBound {
            dueTimes.insert(dueTime)
            after = dueTime
        }
        return dueTimes.sorted()
    }

    /// The due time of the earliest occurrence the Now tab's Last 24 Hours can list. An occurrence
    /// closes within the give-up span of its due time, so one due earlier closed before then.
    var earliestListedDueTime: Date {
        clock.now - 24 * 60 * 60 - giveUpLimit.span
    }

    private func isBeforeScheduleChange(_ dueTime: Date, of reminderID: Reminder.ID) -> Bool {
        histories[reminderID]?.editAppliesAfter.map { dueTime <= $0 } ?? false
    }

    /// The reminder's occurrence due at `dueTime`, as it stands now, or `nil` if `dueTime` isn't
    /// one of its due times or hasn't come yet. `latestOccurrence(for:)` gives only the newest,
    /// so this is how an earlier one, such as one the next took over, is read back.
    public func occurrence(of reminderID: Reminder.ID, dueAt dueTime: Date) -> Occurrence? {
        reading(of: reminderID, dueAt: dueTime)?.occurrence
    }

    /// `occurrence(of:dueAt:)` with how it closed, `nil` while it is Nudging. Done's is recorded;
    /// the others' come from the clock.
    func reading(of reminderID: Reminder.ID, dueAt dueTime: Date) -> (occurrence: Occurrence, closing: Closing?)? {
        guard dueTime <= clock.now, let reminder = reminder(reminderID) else { return nil }
        let isFixed = histories[reminderID]?.closedOccurrences[dueTime] != nil
        guard isFixed || (reminder.latestDueTime(atOrBefore: dueTime, calendar: calendar) == dueTime
            && !isBeforeScheduleChange(dueTime, of: reminderID))
        else { return nil }
        let next = reminder.nextDueTime(after: dueTime, calendar: calendar)
        return occurrence(of: reminder, dueAt: dueTime, takenOverAt: next.flatMap { $0 <= clock.now ? $0 : nil })
    }

    /// The occurrence's state from the clock, and how it closed. `takeOverTime` is when the next
    /// occurrence fell due, or `nil` if it hasn't yet (or the repeat has no next).
    private func occurrence(
        of reminder: Reminder,
        dueAt dueTime: Date,
        takenOverAt takeOverTime: Date?
    ) -> (occurrence: Occurrence, closing: Closing?) {
        func closed(_ closing: Closing) -> (occurrence: Occurrence, closing: Closing?) {
            (Occurrence(dueTime: dueTime, state: closing.state), closing)
        }
        if let closing = histories[reminder.id]?.closedOccurrences[dueTime] {
            return closed(closing)
        }
        let nudgeTimes = reminder.strength.nudgeTimes(from: dueTime, within: giveUpLimit)
        let giveUpTime = reminder.strength.giveUpTime(from: dueTime, after: nudgeTimes, within: giveUpLimit)
        // The first pause that ends at or after the due time is the first the occurrence could be
        // open in. If it hadn't closed by then, it's Skipped: the Nudging one that Pause closes, any
        // due while paused, and one an edit while paused moved to before the pause.
        // It closes when the pause starts, or at its due time if that came while paused.
        if let pause = histories[reminder.id]?.pauseSpans.first(where: { dueTime <= $0.end ?? .distantFuture }),
           min(giveUpTime, takeOverTime ?? giveUpTime) > pause.start {
            // Nothing was sent if it fell due while paused.
            let sent = dueTime > pause.start ? 0 : nudgeTimes.count { $0 <= pause.start }
            return closed(Closing(state: .skipped(reason: .paused), closedAt: max(dueTime, pause.start), nudgesSent: sent))
        }
        // A tie goes to the next occurrence, as in the mockup's `simulate` (`takeover: t >= until`).
        if let takeOverTime, takeOverTime <= giveUpTime {
            // The plan stops its ladder before the take-over.
            let sent = nudgeTimes.count { $0 < takeOverTime }
            return closed(Closing(state: .missed(reason: .nextTookOver), closedAt: takeOverTime, nudgesSent: sent))
        }
        if clock.now >= giveUpTime {
            return closed(Closing(state: .missed(reason: .giveUpLimit), closedAt: giveUpTime, nudgesSent: nudgeTimes.count))
        }
        let sent = nudgeTimes.filter { $0 <= clock.now }.count
        return (Occurrence(dueTime: dueTime, state: .nudging(nudgeNumber: sent)), nil)
    }
}

/// How an occurrence closed: its state, when, and after how many nudges.
struct Closing {
    var state: OccurrenceState
    var closedAt: Date
    var nudgesSent: Int
}

/// A value a change replaced, and when. A nudge firing at or before `replacedAt` was delivered with it.
private struct Replaced<Value> {
    var value: Value
    var replacedAt: Date
}

private extension Array {
    /// The value in force when a nudge fired at `fireTime`: the first one replaced at or after it,
    /// so a nudge firing exactly at a change keeps the old value. `nil` if no change came after.
    func value<Value>(firingAt fireTime: Date) -> Value? where Element == Replaced<Value> {
        first { fireTime <= $0.replacedAt }?.value
    }
}
