import Foundation

/// Something the person wants to be nudged about.
public struct Reminder: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    /// Private to the app: never carried into a schedule plan.
    public var notes: String
    /// Private to the app: never carried into a schedule plan.
    public var tags: [String]
    /// The first due time. A repeating reminder's later due times are worked out from it.
    public var dueTime: Date
    /// `nil` repeats Never.
    public var repeatRule: RepeatRule?
    public var strength: Strength
    /// On unless the person turns it off, as in the mockup's New Reminder form.
    public var breakThroughFocus: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        tags: [String] = [],
        dueTime: Date,
        repeatRule: RepeatRule? = nil,
        strength: Strength,
        breakThroughFocus: Bool = true
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.tags = tags
        self.dueTime = dueTime
        self.repeatRule = repeatRule
        self.strength = strength
        self.breakThroughFocus = breakThroughFocus
    }
}

/// How hard a reminder nudges.
public enum Strength: Equatable, Sendable {
    case gentle
    case firm
    case relentless
}
