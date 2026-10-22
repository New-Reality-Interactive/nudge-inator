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
    /// On unless the person turns it off, as in the mockup's New Reminder form.
    public var breakThroughFocus: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        tagIDs: [Tag.ID] = [],
        dueTime: Date,
        repeatRule: RepeatRule? = nil,
        strength: Strength,
        pace: Pace = .escalating,
        breakThroughFocus: Bool = true
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
    }
}

extension Reminder {
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
