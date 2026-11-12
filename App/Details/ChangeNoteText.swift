import Foundation
import NudgeEngine

/// A received reminder's change note in words (ticket 204, GLOSSARY.md, Change note): one line per
/// changed field with its old and new value, such as "Due time changed from 8:00 AM to 9:00 AM", on
/// its details, and the same lines after "<name> changed this:" in its notification. The engine
/// returns the values; the words, the times and the lists are the app's, in the person's locale.
struct ChangeNoteText {
    /// Words the engine's times, days and repeats in the person's locale.
    private let engine: Engine
    private let changes: [ReceivedChange]
    /// The copy's due time, the time of day of a repeat's words when the note doesn't move it.
    private let dueTime: Date

    init(_ note: ReceivedChangeNote, dueTime: Date, engine: Engine) {
        self.engine = engine
        self.dueTime = dueTime
        changes = note.changes
    }

    /// One line per change, in the order the engine returned them.
    var lines: [LocalizedStringResource] {
        changes.map(line)
    }

    /// The details' heading: "Alex Morgan changed this · Today at 8:02 AM".
    func heading(from name: String, at date: Date) -> LocalizedStringResource {
        let when = Self.dayAndTime(of: date, engine: engine)
        return LocalizedStringResource("\(name) changed this · \(when)", comment: "Reminder details: heading of the note on a received reminder its sender changed. 1: the sender's name. 2: when the change arrived, such as \"Today at 8:02 AM\".")
    }

    /// The notification's body: "Alex Morgan changed this: due time changed from 8:30 AM to 9:00 AM".
    /// The lines read as one sentence after the colon, so each starts in lower case.
    func notificationBody(from name: String) -> String {
        let sentences = lines.map { String(localized: $0) }.map { $0.prefix(1).lowercased() + $0.dropFirst() }
        let list = sentences.formatted(.list(type: .and))
        return String(localized: "\(name) changed this: \(list)", comment: "Body of the notification that the sender changed a reminder they sent. 1: the sender's name. 2: what changed, such as \"due time changed from 8:30 AM to 9:00 AM\", or several joined as a list.")
    }

    private func line(for change: ReceivedChange) -> LocalizedStringResource {
        switch change {
        case let .title(from, to):
            LocalizedStringResource("Title changed from “\(from)” to “\(to)”", comment: "Change note line: the sender renamed a reminder. 1: the old title. 2: the new title.")
        case .notes:
            LocalizedStringResource("Notes changed", comment: "Change note line: the sender changed a reminder's notes, which are shown above, so the old and new text aren't repeated.")
        case let .dueTime(from, to):
            LocalizedStringResource("Due time changed from \(moment(from, besides: to)) to \(moment(to, besides: from))", comment: "Change note line: the sender moved a reminder's due time. 1: the old time, such as \"8:00 AM\", or with its day, such as \"Today at 8:00 AM\", when the day changed too. 2: the new time, in the same style.")
        case let .repeatRule(from, to):
            LocalizedStringResource("Repeat changed from \(repeatSummary(from, atOldDueTime: true)) to \(repeatSummary(to, atOldDueTime: false))", comment: "Change note line: the sender changed how a reminder repeats. 1: the old repeat in words, such as \"Every day at 8:30 AM\", or \"Never\". 2: the new one.")
        case let .strength(from, to):
            LocalizedStringResource("Strength changed from \(String(localized: from.title)) to \(String(localized: to.title))", comment: "Change note line: the sender changed a reminder's strength. 1: the old strength, such as \"Gentle\". 2: the new one.")
        case let .pace(from, to):
            LocalizedStringResource("Pace changed from \(String(localized: from.title)) to \(String(localized: to.title))", comment: "Change note line: the sender changed a reminder's pace. 1: the old pace, such as \"Escalating\". 2: the new one, such as \"Consistent · 30 min\".")
        case let .breakThroughFocus(_, to):
            to
                ? LocalizedStringResource("Break Through Focus turned on", comment: "Change note line: the sender turned a reminder's Break Through Focus switch on.")
                : LocalizedStringResource("Break Through Focus turned off", comment: "Change note line: the sender turned a reminder's Break Through Focus switch off.")
        }
    }

    /// The time of day alone when both ends of the change are on one day, else with its day.
    private func moment(_ date: Date, besides other: Date) -> String {
        guard engine.dayLabel(of: date) != engine.dayLabel(of: other) else { return engine.timeOfDay(of: date) }
        return Self.dayAndTime(of: date, engine: engine)
    }

    private static func dayAndTime(of date: Date, engine: Engine) -> String {
        String(localized: "\(engine.dayLabel(of: date)) at \(engine.timeOfDay(of: date))", comment: "A day and a time of day, such as \"Today at 8:02 AM\". 1: the day, such as \"Today\" or \"Tue, Oct 20\". 2: the time.")
    }

    /// The rule in words, or "Never". It carries a time of day, which is the reminder's due time: the
    /// old rule's is the old due time if the same change moved it.
    private func repeatSummary(_ rule: RepeatRule?, atOldDueTime isOld: Bool) -> String {
        guard let rule else { return String(localized: "Never", comment: "Change note line: a reminder that doesn't repeat, as the old or new repeat.") }
        let moved = changes.lazy.compactMap { change -> Date? in
            if case let .dueTime(from, to) = change { isOld ? from : to } else { nil }
        }.first
        return engine.repeatSummary(of: Reminder(title: "", dueTime: moved ?? dueTime, repeatRule: rule, strength: .gentle))
    }
}
