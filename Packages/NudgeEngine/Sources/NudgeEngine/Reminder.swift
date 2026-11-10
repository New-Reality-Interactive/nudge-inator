import Foundation

/// Something the person wants to be nudged about.
public struct Reminder: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    /// Private to the app: never carried into a schedule plan.
    public var notes: String
    /// The reminder's tags, by ID, so a rename reaches every reminder with the tag. Private to the
    /// app: never carried into a schedule plan.
    public var tagIDs: [Tag.ID]
    /// The first due time. A repeating reminder's later due times are worked out from it.
    public var dueTime: Date
    /// `nil` repeats Never.
    public var repeatRule: RepeatRule?
    public var strength: Strength
    /// How the waits between its nudges are spaced.
    public var pace: Pace
    /// On unless the person turns it off, as in the mockup's New Reminder form. Relentless ignores
    /// it but keeps it, so switching back to Firm or Gentle gives it back: read
    /// `breaksThroughFocus` for how the reminder acts.
    public var breakThroughFocus: Bool
    /// The moment the reminder was added: `Engine.add(_:)` sets it from the engine's clock, and
    /// nothing changes it afterwards. `.distantPast` until then (GLOSSARY.md, Creation date).
    public var createdAt: Date
    /// Whose reminder it is: the person's own, or a copy received from someone. Nothing but the
    /// store and the sharing code sets it; the engine plans a received reminder as its own.
    public var origin: ReminderOrigin

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        tagIDs: [Tag.ID] = [],
        dueTime: Date,
        repeatRule: RepeatRule? = nil,
        strength: Strength,
        pace: Pace = .escalating,
        breakThroughFocus: Bool = true,
        createdAt: Date = .distantPast,
        origin: ReminderOrigin = .mine
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.tagIDs = tagIDs
        self.dueTime = dueTime
        self.repeatRule = repeatRule
        self.strength = strength
        self.pace = pace
        self.breakThroughFocus = breakThroughFocus
        self.createdAt = createdAt
        self.origin = origin
    }
}

extension Reminder {
    /// Whether it is a copy received from someone, not the person's own.
    public var isReceived: Bool {
        if case .received = origin { true } else { false }
    }

    /// Whether its nudges break through Focus: its switch, or always for Relentless (ADR 0004).
    public var breaksThroughFocus: Bool {
        strength.breaksThroughFocus(switchedOn: breakThroughFocus)
    }

    /// The latest occurrence's due time at or before `date`, or `nil` before the first one.
    func latestDueTime(atOrBefore date: Date, calendar: Calendar) -> Date? {
        guard let repeatRule else { return date >= dueTime ? dueTime : nil }
        return repeatRule.latestDueTime(atOrBefore: date, firstDueTime: dueTime, calendar: calendar)
    }

    /// The next occurrence's due time after `date`, or `nil` if there is none.
    func nextDueTime(after date: Date, calendar: Calendar) -> Date? {
        guard let repeatRule else { return date < dueTime ? dueTime : nil }
        return repeatRule.nextDueTime(after: date, firstDueTime: dueTime, calendar: calendar)
    }
}

/// How hard a reminder nudges.
public enum Strength: Equatable, Sendable {
    case gentle
    case firm
    case relentless
}

extension Strength {
    /// Whether a reminder of this strength with its Break Through Focus switch `switchedOn` breaks
    /// through Focus. Relentless always does, so a stored `false` can't make it quieter than Firm
    /// (ADR 0004). The one place the rule lives: the plan, the nudge card and How It Nudges read it.
    public func breaksThroughFocus(switchedOn: Bool) -> Bool {
        self == .relentless || switchedOn
    }
}

/// Whose a reminder is. A reminder saved before sharing existed has no origin and reads back as
/// `mine`, so nothing about it changes (docs/agents/release.md, Backwards compatible).
public enum ReminderOrigin: Equatable, Sendable {
    /// The person made it, and it never leaves the iPhone.
    case mine
    /// The recipient's copy of a reminder someone sent them (GLOSSARY.md, Received reminder).
    /// `connectionID` names the connection it came through and `sendersReminderID` the sender's own
    /// reminder, so a later revision finds its copy. `revision` counts the sender's changes.
    case received(connectionID: UUID, sendersReminderID: Reminder.ID, revision: Int, state: ReceivedState)

    /// Whether a received reminder has started (Delivery mode). Held here for the sharing code;
    /// the engine plans a `waiting` copy as it does an `accepted` one until Ask me first lands (#186).
    public enum ReceivedState: Equatable, Sendable {
        case accepted
        /// Waiting for the recipient to accept it.
        case waiting
    }
}

/// A received reminder's field that only its sender can change: everything but its tags.
public enum ReceivedContentField: Hashable, CaseIterable, Sendable {
    case title
    case notes
    case dueTime
    case repeatRule
    case strength
    case pace
    case breakThroughFocus

    /// Whether `edited` gives this field a different value from `current`.
    func isChanged(from current: Reminder, to edited: Reminder) -> Bool {
        switch self {
        case .title: current.title != edited.title
        case .notes: current.notes != edited.notes
        case .dueTime: current.dueTime != edited.dueTime
        case .repeatRule: current.repeatRule != edited.repeatRule
        case .strength: current.strength != edited.strength
        case .pace: current.pace != edited.pace
        case .breakThroughFocus: current.breakThroughFocus != edited.breakThroughFocus
        }
    }
}
