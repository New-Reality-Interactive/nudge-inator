import Foundation

/// What a Now tab nudge card says about a reminder's open occurrence.
public struct NudgingStatus: Equatable, Sendable {
    public var dueTime: Date
    /// "Nudge 3 of 20", and how full the nudge meter is.
    public var nudgesSent: Int
    /// The nudges this occurrence sends before it closes as Missed: the give-up limit's count,
    /// fewer if its span or a take-over comes first. "Nudge 3 of 20" and the meter count out of it.
    public var nudgesInAll: Int
    /// The urgency of the latest nudge sent.
    public var urgency: Urgency
    /// The nudge still to come, or `nil` after the last one, or when the next occurrence of its
    /// repeat falls due first and takes over.
    public var nextNudge: NextNudge?
    /// When it closes as Missed, by its give-up limit or a take-over, unless it's Done first.
    public var missedAt: Date
}

/// The next nudge of an open occurrence: "Next nudge 9:45 (in 5 min): Notification · High".
public struct NextNudge: Equatable, Sendable {
    public var nudgeNumber: Int
    public var fireTime: Date
    public var urgency: Urgency
    public var delivery: NudgeDelivery
}

/// How a nudge reaches the phone, as the card's via label says it.
public enum NudgeDelivery: Equatable, Sendable {
    case alarm
    /// A notification, ordinary or Time Sensitive, with why it isn't the stronger kind its urgency
    /// asks for, if it isn't.
    case notification(weakerBecause: Reason?)
    /// Nothing can deliver it: notifications are off and it doesn't ring.
    case cannotArrive

    /// Why a nudge arrives as a weaker notification than its urgency asks for, as the mockup's
    /// `viaLabel` says it: "Notification: alarms are off". A fallback (GLOSSARY.md), or the
    /// reminder's own Break through Focus switch, which is the person's choice, not a fallback.
    public enum Reason: Equatable, Sendable {
        /// An Urgent nudge, with alarms not allowed.
        case alarmsOff
        /// An Urgent nudge, with alarms not allowed and Time Sensitive off, so it's ordinary.
        case alarmsAndTimeSensitiveOff
        /// A High nudge, ordinary because Time Sensitive is off.
        case timeSensitiveOff
        /// A High or Urgent nudge of a reminder whose Break through Focus is off.
        case breakThroughFocusOff
        /// An Urgent nudge past the alarm limit: "too many alarms scheduled".
        case pastAlarmLimit
    }
}

extension Engine {
    /// The reminder's open occurrence as its nudge card shows it, or `nil` if it has none.
    public func nudgingStatus(of reminderID: Reminder.ID) -> NudgingStatus? {
        guard let reminder = reminders.first(where: { $0.id == reminderID }),
              let occurrence = openOccurrence(for: reminderID),
              case let .nudging(nudgesSent) = occurrence.state
        else { return nil }
        let strength = reminder.strength
        let uncutNudgeTimes = reminder.nudgeTimes(from: occurrence.dueTime, within: giveUpLimit)
        let giveUpTime = reminder.giveUpTime(from: occurrence.dueTime, after: uncutNudgeTimes, within: giveUpLimit)
        // Open, so its next due time is after now and hasn't taken it over yet.
        let takeOverTime = reminder.nextDueTime(after: clock.now, calendar: calendar)
        let missedAt = min(giveUpTime, takeOverTime ?? giveUpTime)
        // Cut at the take-over, as the plan's ladder is.
        let nudgeTimes = nudgeTimes(of: reminder, dueAt: occurrence.dueTime, takenOverAt: takeOverTime)
        let nextNudge = nudgeTimes.indices.dropFirst(nudgesSent).first.map { index in
            let urgency = strength.urgency(ofNudge: index + 1)
            let delivery = nudgeDelivery(of: reminder, firingAt: nudgeTimes[index], urgency: urgency)
            return NextNudge(nudgeNumber: index + 1, fireTime: nudgeTimes[index], urgency: urgency, delivery: delivery)
        }
        return NudgingStatus(
            dueTime: occurrence.dueTime,
            nudgesSent: nudgesSent,
            nudgesInAll: nudgeTimes.count,
            urgency: strength.urgency(ofNudge: nudgesSent),
            nextNudge: nextNudge,
            missedAt: missedAt
        )
    }

    private func nudgeDelivery(of reminder: Reminder, firingAt fireTime: Date, urgency: Urgency) -> NudgeDelivery {
        Self.nudgeDelivery(
            delivery(of: reminder, firingAt: fireTime, urgency: urgency),
            urgency: urgency,
            breakThroughFocus: reminder.breaksThroughFocus,
            timeSensitive: permissions(firingAt: fireTime).timeSensitive
        )
    }

    /// The via label's delivery for a plan item's `delivery`, which says how it arrives but not why
    /// it is weaker than its urgency asks for. How It Nudges reads it too.
    static func nudgeDelivery(
        _ delivery: (kind: DeliveryKind, isPastAlarmLimit: Bool)?,
        urgency: Urgency,
        breakThroughFocus: Bool,
        timeSensitive: TimeSensitiveSetting
    ) -> NudgeDelivery {
        guard let delivery else { return .cannotArrive }
        if delivery.kind == .alarm { return .alarm }
        if delivery.isPastAlarmLimit { return .notification(weakerBecause: .pastAlarmLimit) }
        let timeSensitiveOff = timeSensitive == .off
        switch urgency {
        case .normal:
            return .notification(weakerBecause: nil)
        case _ where !breakThroughFocus:
            return .notification(weakerBecause: .breakThroughFocusOff)
        case .high:
            return .notification(weakerBecause: timeSensitiveOff ? .timeSensitiveOff : nil)
        // Urgent that doesn't ring, with the switch on and within the alarm limit: alarms are off.
        case .urgent:
            return .notification(weakerBecause: timeSensitiveOff ? .alarmsAndTimeSensitiveOff : .alarmsOff)
        }
    }
}
