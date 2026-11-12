import Foundation
import NudgeEngine

/// What the reminder details screen shows, read from the engine at one moment. A value, so the
/// tests and previews read it with no view.
struct ReminderDetails {
    var reminder: Reminder
    /// The reminder's tags as "#home". Only tags the engine holds, as the tag filters do.
    var tags: [String]
    /// The hero's status word, the engine's, as the Reminders tab's rows show it.
    var status: ReminderStatus
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
    /// The reminder's ladder with its own Break Through Focus switch (ticket 31).
    var howItNudges: HowItNudges
    /// What a received reminder's details add (ticket 200), or `nil` for the person's own.
    var received: Received?

    var title: String { reminder.title }
    var notes: String { reminder.notes }
    var strength: Strength { reminder.strength }
    /// The Schedule's Pace row.
    var pace: Pace { reminder.pace }
    /// Done is shown only while the reminder is Nudging.
    var offersDone: Bool { card != nil }
    /// A received copy waiting to be accepted (ticket 203): the waiting note, Accept and Remove in
    /// place of Pause and Remove Reminder.
    var isWaiting: Bool { status == .waiting }

    /// The tags as VoiceOver reads them, a list in the engine's words, or `nil` with none.
    var tagsVoiceOverLabel: LocalizedStringResource? {
        guard !tags.isEmpty else { return nil }
        let list = tags.formatted(.list(type: .and))
        return LocalizedStringResource("Tags: \(list)", comment: "VoiceOver label of a reminder's tags on its details. The placeholder lists them, such as \"#home and #errands\".")
    }

    /// A received reminder's sender and strength, and the person's choice to keep its status from
    /// them (ticket 200): the sender owns everything but the tags.
    struct Received: Equatable {
        /// "From Alex Morgan", as Now, My Day and the Reminders tab label it.
        var from: LocalizedStringResource
        /// Who owns its content, for "Alex Morgan owns this schedule."
        var senderName: String
        /// "Firm: rings as an alarm from nudge 4", under the strength badge.
        var strengthLine: StrengthLine
        /// The "Don't share this one" switch, or `nil` when the person's Status sharing for the
        /// connection is off, so there's nothing to hold back (the mockup's `viewReceived`). Its
        /// effect on what the sender sees is the status tickets'.
        var notSharingThisOne: Bool?
        /// What the sender's latest change did, or `nil` while nobody has changed the copy (ticket 204).
        var changeNote: ChangeNote?
    }

    /// A received reminder's change note as the details show it (the mockup's `noteCard`): the
    /// heading says who changed it and when, a line each field.
    struct ChangeNote: Equatable {
        var heading: LocalizedStringResource
        var lines: [LocalizedStringResource]
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
    ///
    /// `sharing` names a received reminder's sender and holds its "Don't share this one"; with none
    /// (previews, the shipped app until #216) it reads "From Someone", with no switch.
    init?(engine: Engine, id: Reminder.ID, sharing: SharingData = SharingData()) {
        guard let reminder = engine.reminders.first(where: { $0.id == id }), let status = engine.status(of: id) else { return nil }
        self.reminder = reminder
        self.status = status
        tags = engine.tagLabels(for: reminder.tagIDs)
        let senders = Senders(connections: sharing.connections)
        let from = senders.label(of: reminder)
        card = NudgeCard(engine: engine, reminder: reminder, from: from)
        let latest = engine.latestOccurrence(for: id)
        lastOccurrence = latest
            .flatMap { engine.closedOccurrence(of: id, dueAt: $0.dueTime) }
            .map { LastOccurrence(state: $0.occurrence.state, day: engine.dayLabel(of: $0.closedAt), time: engine.timeOfDay(of: $0.closedAt)) }
        repeats = engine.repeatSummary(of: reminder)
        showsLockNote = !engine.lockedFields(of: id).isEmpty
        let howItNudges = engine.howItNudges(reminder.strength, pace: reminder.pace, breakThroughFocus: reminder.breakThroughFocus)
        self.howItNudges = howItNudges
        received = from.map { from in
            let connection = sharing.connections.first { $0.id == reminder.receivedThrough }
            let syncState = sharing.receivedSyncStates.first { $0.reminderID == reminder.id }
            return Received(
                from: from,
                senderName: senders.name(of: reminder) ?? "",
                strengthLine: StrengthLine(reminder.strength, howItNudges),
                notSharingThisOne: connection?.mine.sharesStatus == true ? syncState?.notSharingThisOne ?? false : nil,
                changeNote: syncState?.changeNote.map {
                    let words = ChangeNoteText($0, dueTime: reminder.dueTime, engine: engine)
                    return ChangeNote(heading: words.heading(from: senders.name(of: reminder) ?? "", at: $0.at), lines: words.lines)
                }
            )
        }

        let nextDueTime = engine.nextDueTime(of: reminder)
        let isPaused = engine.isPaused(id)
        if reminder.isWaiting {
            // A one-off past its due time shows that time, as the mockup's `viewReceived` does. It
            // can't be paused (the engine ignores it): Accept or Remove.
            let due = nextDueTime ?? reminder.dueTime
            next = .at(day: engine.dayLabel(of: due), time: engine.timeOfDay(of: due))
            pauseAction = nil
        } else if isPaused {
            next = .paused
            pauseAction = .resume
        } else {
            next = nextDueTime.map { .at(day: engine.dayLabel(of: $0), time: engine.timeOfDay(of: $0)) } ?? .none
            pauseAction = card != nil || nextDueTime != nil ? .pause : nil
        }
    }
}
