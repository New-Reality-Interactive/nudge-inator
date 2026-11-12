import Foundation
import NudgeEngine

/// Who sent each received reminder (ticket 199), for its "From <name>" label on Now, My Day and
/// the Reminders tab: the name of the connection it came through, as the sharing store holds it.
struct Senders {
    /// Each connection's name, whatever its state: a copy still held after the other person ended
    /// the connection, before this person's own Remove or Keep (spec A8), keeps its sender's name.
    private let names: [UUID: String]

    /// No connections: a received reminder reads "From Someone". The shipped app until #216, and
    /// screens built with no app model.
    init() {
        names = [:]
    }

    init(connections: [SharingConnection]) {
        names = Dictionary(connections.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    /// The sender's name for a received reminder ("Riley Park"), or `nil` for the person's own. A
    /// connection the sharing store doesn't hold reads "Someone", as `label(of:)` does (ticket 200's
    /// "Someone owns this schedule.").
    func name(of reminder: Reminder) -> String? {
        guard let connectionID = reminder.receivedThrough else { return nil }
        return names[connectionID] ?? String(localized: "Someone", comment: "Who owns a received reminder, on its details and form, when the app doesn't know who sent it, as in \"Someone owns this schedule.\"")
    }

    /// "From Riley Park" for a received reminder, or `nil` for the person's own. A connection the
    /// sharing store doesn't hold (a store that won't open, the `received` seed set without the
    /// stand-in) reads "From Someone", as the mockup's `fromName` does: never no label at all.
    func label(of reminder: Reminder) -> LocalizedStringResource? {
        guard let connectionID = reminder.receivedThrough else { return nil }
        guard let name = names[connectionID] else {
            return LocalizedStringResource("From Someone", comment: "Under a received reminder's title on Now, My Day and the Reminders tab, when the app doesn't know who sent it.")
        }
        return LocalizedStringResource("From \(name)", comment: "Under a received reminder's title on Now, My Day and the Reminders tab. The placeholder is the sender's name, such as \"Riley Park\".")
    }
}
