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
    private let clock: any EngineClock
    private let scheduler: any SchedulerAdapter
    private let giveUpSpan: TimeInterval
    private var reminders: [Reminder] = []
    /// Done is the one occurrence fact the clock can't work out, so the engine records it. An
    /// occurrence is its reminder at one due time, which is what repeats will need.
    private var doneOccurrences: Set<OccurrenceKey> = []

    private struct OccurrenceKey: Hashable {
        var reminderID: Reminder.ID
        var dueTime: Date
    }

    public init(clock: any EngineClock, scheduler: any SchedulerAdapter) {
        self.init(clock: clock, scheduler: scheduler, giveUpSpan: GiveUpLimit.span)
    }

    /// Lets tests shorten the give-up span, the only way to see it win over the nudge count with
    /// today's ladders. Internal because the spec fixes the limit.
    init(clock: any EngineClock, scheduler: any SchedulerAdapter, giveUpSpan: TimeInterval) {
        self.clock = clock
        self.scheduler = scheduler
        self.giveUpSpan = giveUpSpan
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
        guard openOccurrence(for: reminderID) != nil,
              let reminder = reminders.first(where: { $0.id == reminderID })
        else { return }
        doneOccurrences.insert(OccurrenceKey(reminderID: reminderID, dueTime: reminder.dueTime))
        scheduler.apply(plan())
    }

    /// Every reminder's whole ladder, even before it is due. The app gets no callback when a
    /// notification or alarm fires, so the chain must already be pending for nudging to go on
    /// while the app stays closed. A closed occurrence (Done or Missed) has nothing left to send.
    private func plan() -> SchedulePlan {
        SchedulePlan(items: reminders.flatMap { reminder -> [SchedulePlan.Item] in
            switch latestOccurrence(for: reminder.id)?.state {
            case .missed, .done: return []
            case .nudging, nil: break
            }
            return reminder.strength.nudgeTimes(from: reminder.dueTime, within: giveUpSpan).enumerated().map { index, fireTime in
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
        })
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
              clock.now >= reminder.dueTime
        else { return nil }
        if doneOccurrences.contains(OccurrenceKey(reminderID: reminderID, dueTime: reminder.dueTime)) {
            return Occurrence(state: .done)
        }
        let nudgeTimes = reminder.strength.nudgeTimes(from: reminder.dueTime, within: giveUpSpan)
        if clock.now >= reminder.strength.giveUpTime(from: reminder.dueTime, within: giveUpSpan) {
            return Occurrence(state: .missed(reason: .giveUpLimit))
        }
        let sent = nudgeTimes.filter { $0 <= clock.now }.count
        return Occurrence(state: .nudging(nudgeNumber: sent))
    }
}
