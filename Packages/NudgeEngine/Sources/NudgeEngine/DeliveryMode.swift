import Foundation

/// A recipient's choice, per connection, of how a received reminder starts (GLOSSARY.md, Delivery
/// mode). A change applies to reminders sent afterwards.
public enum DeliveryMode: Equatable, Sendable, CaseIterable {
    /// It starts nudging as soon as it arrives. The default.
    case startRightAway
    /// It waits for the recipient to accept it, and sends no nudge until they do (spec #127, A9).
    case askMeFirst
}
