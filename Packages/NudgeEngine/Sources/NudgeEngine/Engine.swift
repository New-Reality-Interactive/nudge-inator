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
    private var reminders: [Reminder] = []

    public init(clock: any EngineClock, scheduler: any SchedulerAdapter) {
        self.clock = clock
        self.scheduler = scheduler
    }

    public mutating func update(reminders: [Reminder]) {
        self.reminders = reminders
        scheduler.apply(plan())
    }

    /// Every reminder's whole ladder, even before it is due. The app gets no callback when a
    /// notification or alarm fires, so the chain must already be pending for nudging to go on
    /// while the app stays closed.
    private func plan() -> SchedulePlan {
        SchedulePlan(items: reminders.flatMap { reminder in
            reminder.strength.nudgeTimes(from: reminder.dueTime).enumerated().map { index, fireTime in
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
        guard let reminder = reminders.first(where: { $0.id == reminderID }),
              clock.now >= reminder.dueTime
        else { return nil }
        let sent = reminder.strength.nudgeTimes(from: reminder.dueTime).filter { $0 <= clock.now }.count
        return Occurrence(state: .nudging(nudgeNumber: sent))
    }
}
