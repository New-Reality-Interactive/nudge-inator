/// What a person chooses, when a connection ends, for the reminders they received through it
/// (spec #127, Disconnect). Whoever ends it chooses, and so does the other person, each for what
/// they received.
public enum DisconnectChoice: Equatable, Sendable {
    /// Deletes them and cancels their nudges and alarms. The default.
    case remove
    /// Keep as My Own Reminders: each stays, with the same content, schedule, history and tags,
    /// no longer from anyone.
    case keepAsMyOwnReminders
}
