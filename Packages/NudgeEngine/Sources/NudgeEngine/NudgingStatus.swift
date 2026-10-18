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
        let nudgeTimes = strength.nudgeTimes(from: occurrence.dueTime, within: giveUpLimit)
        let giveUpTime = strength.giveUpTime(from: occurrence.dueTime, after: nudgeTimes, within: giveUpLimit)
        // Open, so the next due time is after now and hasn't taken it over yet.
        let missedAt = min(giveUpTime, reminder.nextDueTime(after: clock.now, calendar: calendar) ?? giveUpTime)
        // A nudge at the take-over time is the next occurrence's, as in the plan.
        let nextNudge = nudgeTimes.indices.dropFirst(nudgesSent).first.flatMap { nudgeTimes[$0] < missedAt ? $0 : nil }.map { index in
            let urgency = strength.urgency(ofNudge: index + 1)
            let delivery = nudgeDelivery(of: reminder, firingAt: nudgeTimes[index], urgency: urgency)
            return NextNudge(nudgeNumber: index + 1, fireTime: nudgeTimes[index], urgency: urgency, delivery: delivery)
        }
        return NudgingStatus(
            dueTime: occurrence.dueTime,
            nudgesSent: nudgesSent,
            // `nudgeTimes` already stops at the span; a take-over stops it sooner.
            nudgesInAll: nudgeTimes.count { $0 < missedAt },
            urgency: strength.urgency(ofNudge: nudgesSent),
            nextNudge: nextNudge,
            missedAt: missedAt
        )
    }

    private func nudgeDelivery(of reminder: Reminder, firingAt fireTime: Date, urgency: Urgency) -> NudgeDelivery {
        guard let delivery = delivery(of: reminder, firingAt: fireTime, urgency: urgency) else { return .cannotArrive }
        if delivery.kind == .alarm { return .alarm }
        if delivery.isPastAlarmLimit { return .notification(weakerBecause: .pastAlarmLimit) }
        let timeSensitiveOff = permissions(firingAt: fireTime).timeSensitive == .off
        switch urgency {
        case .normal:
            return .notification(weakerBecause: nil)
        case _ where !reminder.breakThroughFocus:
            return .notification(weakerBecause: .breakThroughFocusOff)
        case .high:
            return .notification(weakerBecause: timeSensitiveOff ? .timeSensitiveOff : nil)
        // Urgent that doesn't ring, with the switch on and within the alarm limit: alarms are off.
        case .urgent:
            return .notification(weakerBecause: timeSensitiveOff ? .alarmsAndTimeSensitiveOff : .alarmsOff)
        }
    }
}
