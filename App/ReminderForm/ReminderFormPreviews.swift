#if DEBUG
import Foundation
import NudgeEngine

/// Forms for previews, over an engine with no adapters, so they need no app model.
extension ReminderForm {
    static func preview(tags: [String] = []) -> ReminderForm {
        var engine = Engine(clock: PreviewClock(), scheduler: NoOpScheduler())
        engine.update(tags: tags.map { Tag(name: $0) })
        return ReminderForm(engine: { engine }, now: { .now }, defaultPace: .shipped)
    }

    /// A New Reminder form with Send To over the stand-in's people, or with `seeded` false, no one.
    static func previewSendTo(seeded: Bool = true) -> ReminderForm {
        let engine = Engine(clock: PreviewClock(), scheduler: NoOpScheduler())
        return ReminderForm(engine: { engine }, now: { .now }, defaultPace: .shipped, sharing: StandInSharing.previewModel(seeded: seeded))
    }

    /// The Edit form of a Firm reminder that fell due ten minutes ago, so it is Nudging.
    static func previewNudging() -> ReminderForm {
        edit(Reminder(title: "Take the bins out", dueTime: .now.addingTimeInterval(-600), strength: .firm))
    }

    /// The Edit form of a reminder that repeats every 3 days, the mockup's custom example.
    static func previewCustom() -> ReminderForm {
        edit(Reminder(title: "Water the plants", dueTime: .now.addingTimeInterval(3600),
                      repeatRule: RepeatRule(frequency: .daily, interval: 3), strength: .gentle, breakThroughFocus: false))
    }

    /// A New Reminder form whose repeat is Custom, started from a preset.
    static func previewCustom(from preset: RepeatPreset) -> ReminderForm {
        let form = preview()
        form.repeatPreset = preset
        form.chooseCustomRepeat()
        return form
    }

    /// The Edit form of a reminder Maya Lee sent (ticket 200): only its tags can change.
    static func previewReceived() -> ReminderForm {
        let connectionID = UUID()
        let reminder = Reminder(
            title: "Take your allergy pill",
            notes: "The blue box, with food.",
            dueTime: .now.addingTimeInterval(3600),
            repeatRule: .everyDay,
            strength: .relentless,
            origin: .received(connectionID: connectionID, sendersReminderID: UUID(), revision: 0, state: .accepted)
        )
        return edit(reminder, senders: Senders(connections: [SharingConnection(id: connectionID, name: "Maya Lee", state: .connected)]))
    }

    private static func edit(_ reminder: Reminder, senders: Senders = Senders()) -> ReminderForm {
        var engine = Engine(clock: PreviewClock(), scheduler: NoOpScheduler())
        engine.update(reminders: [reminder])
        return ReminderForm(engine: { engine }, editing: reminder.id, now: { .now }, senders: senders) ?? preview()
    }
}
#endif
