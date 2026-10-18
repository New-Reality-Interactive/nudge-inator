import Foundation
import NudgeEngine

/// What the reminder details screen shows, read from the engine at one moment. A value, so the
/// tests and previews read it with no view.
struct ReminderDetails {
    var reminder: Reminder
    /// The reminder's tags as "#home". Only tags the engine holds, as the tag filters do.
    var tags: [String]
    var status: Status
    /// The Nudging Now card, with its Done, while the reminder is nudging.
    var card: NudgeCard?
    /// How the latest occurrence closed and when, once one has. A Nudging one has no row: the
    /// card says it.
    var lastOccurrence: LastOccurrence?
    /// The Schedule's Repeats row: the engine's summary, for presets and custom rules alike.
    var repeats: String
    /// The Schedule's Next row.
    var next: Next
    /// Pause for a reminder that can still nudge, Resume for a paused one, nothing for one that
    /// has finished (the mockup's `pauseRow`).
    var pauseAction: PauseAction?
    /// Whether the Schedule section ends with the lock note: some field is Locked (ticket 13).
    var showsLockNote: Bool

    var title: String { reminder.title }
    var notes: String { reminder.notes }
    var strength: Strength { reminder.strength }
    /// Done is shown only while the reminder is Nudging.
    var offersDone: Bool { card != nil }

    /// The tags as VoiceOver reads them, a list in the engine's words, or `nil` with none.
    var tagsVoiceOverLabel: LocalizedStringResource? {
        guard !tags.isEmpty else { return nil }
        let list = tags.formatted(.list(type: .and))
        return LocalizedStringResource("Tags: \(list)", comment: "VoiceOver label of a reminder's tags on its details. The placeholder lists them, such as \"#home and #errands\".")
    }

    /// The hero's status word, from DESIGN.md's Status label.
    enum Status: Equatable {
        case nudging
        case paused
        /// Not due yet: its next due time is ahead.
        case comingUp
        /// Nothing more is coming, so how the latest occurrence closed.
        case closed(OccurrenceState)
    }

    /// A closed occurrence, for the Schedule's last occurrence row.
    struct LastOccurrence: Equatable {
        var state: OccurrenceState
        /// When it closed: "Today", "Yesterday" or a short date, and the time.
        var day: String
        var time: String
    }

    enum Next: Equatable {
        /// The next due time, as the engine's day label and time of day.
        case at(day: String, time: String)
        case paused
        /// Nothing is left: a one-off that has come due, or a repeat that ended.
        case none
    }

    enum PauseAction: Equatable {
        case pause
        case resume
    }

    /// `nil` when the engine doesn't hold the reminder: an ID that was never one, or a reminder
    /// that was deleted while its details were open. The screen then says it wasn't found.
    init?(engine: Engine, id: Reminder.ID) {
        guard let reminder = engine.reminders.first(where: { $0.id == id }) else { return nil }
        self.reminder = reminder
        tags = engine.tagLabels(for: reminder.tagIDs)
        card = NudgeCard(engine: engine, reminder: reminder)
        let latest = engine.latestOccurrence(for: id)
        lastOccurrence = latest
            .flatMap { engine.closedOccurrence(of: id, dueAt: $0.dueTime) }
            .map { LastOccurrence(state: $0.occurrence.state, day: engine.dayLabel(of: $0.closedAt), time: engine.timeOfDay(of: $0.closedAt)) }
        repeats = engine.repeatSummary(of: reminder)
        showsLockNote = !engine.lockedFields(of: id).isEmpty

        // The open occurrence's own due time isn't "next", whatever the clock says. The engine
        // reads "at or after now", so a second time is asked for in case the first is that one.
        let openDueTime = engine.openOccurrence(for: id)?.dueTime ?? .distantPast
        let nextDueTime = engine.upcomingDueTimes(of: reminder, count: 2).first { $0 > openDueTime }
        let isPaused = engine.isPaused(id)
        if card != nil {
            status = .nudging
        } else if isPaused {
            status = .paused
        } else if nextDueTime != nil {
            status = .comingUp
        } else {
            status = latest.map { .closed($0.state) } ?? .comingUp
        }
        if isPaused {
            next = .paused
        } else {
            next = nextDueTime.map { .at(day: engine.dayLabel(of: $0), time: engine.timeOfDay(of: $0)) } ?? .none
        }
        pauseAction = isPaused ? .resume : (card != nil || nextDueTime != nil ? .pause : nil)
    }
}
