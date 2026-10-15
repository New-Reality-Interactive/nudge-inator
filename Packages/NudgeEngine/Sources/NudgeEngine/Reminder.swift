import Foundation

/// Something the person wants to be nudged about.
public struct Reminder: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    /// Private to the app: never carried into a schedule plan.
    public var notes: String
    /// Private to the app: never carried into a schedule plan.
    public var tags: [String]
    public var dueTime: Date
    public var strength: Strength

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        tags: [String] = [],
        dueTime: Date,
        strength: Strength
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.tags = tags
        self.dueTime = dueTime
        self.strength = strength
    }
}

/// How hard a reminder nudges.
public enum Strength: Equatable, Sendable {
    case gentle
}
