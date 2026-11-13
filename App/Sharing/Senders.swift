import Foundation
import NudgeEngine

/// Who sent each received reminder (ticket 199), for its "From <name>" label on Now, My Day and
/// the Reminders tab: the name of the connection it came through, as the sharing store holds it.
struct Senders {
    /// Each connection's name, whatever its state: a copy still held after the other person ended
    /// the connection, before this person's own Remove or Keep (spec A8), keeps its sender's name.
    private let names: [UUID: String]
    /// What the sharing store holds, for whether a copy is Waiting to sync (ticket 211).
    private let sharing: SharingData

    /// No connections: a received reminder reads "From Someone". The shipped app until #216, and
    /// screens built with no app model.
    init() {
        names = [:]
        sharing = SharingData()
    }

    init(connections: [SharingConnection]) {
        self.init(sharing: SharingData(connections: connections))
    }

    init(sharing: SharingData) {
        names = Dictionary(sharing.connections.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        self.sharing = sharing
    }

    /// The From line of a received reminder: "From Riley Park", and whether what this person's app
    /// tells the sender about it is Waiting to sync. `nil` for the person's own.
    func fromLine(of reminder: Reminder) -> FromLine? {
        guard let label = label(of: reminder) else { return nil }
        return FromLine(label: label, waitsToSync: sharing.waitsToSync(received: reminder))
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

/// What a received reminder shows under its title (DESIGN.md, "From <name>" label and Sync states):
/// who sent it, and Waiting to sync while its receipt or status hasn't gone through iCloud.
struct FromLine: Equatable {
    var label: LocalizedStringResource
    var waitsToSync = false

    /// What VoiceOver reads for the line: "From Riley Park", then Waiting to sync when it shows.
    var spoken: String {
        let label = String(localized: label)
        guard waitsToSync else { return label }
        return String(localized: "\(label), Waiting to sync", comment: "VoiceOver, on a received reminder's row or card: who sent it, then that what this person's app tells them hasn't gone through iCloud yet. The placeholder is such as \"From Riley Park\".")
    }
}
