#if DEBUG
import Foundation
import NudgeEngine

/// Forms for previews, over an engine with no adapters, so they need no app model.
extension ReminderForm {
    static func preview(tags: [String] = []) -> ReminderForm {
        var engine = Engine(clock: PreviewClock(), scheduler: PreviewScheduler())
        engine.update(tags: tags.map { Tag(name: $0) })
        return ReminderForm(engine: { engine }, now: { .now })
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

    private static func edit(_ reminder: Reminder) -> ReminderForm {
        var engine = Engine(clock: PreviewClock(), scheduler: PreviewScheduler())
        engine.update(reminders: [reminder])
        return ReminderForm(engine: { engine }, editing: reminder.id, now: { .now }) ?? preview()
    }
}

private struct PreviewClock: EngineClock {
    var now: Date { .now }
}

private struct PreviewScheduler: SchedulerAdapter {
    func apply(_ plan: SchedulePlan) {}
}
#endif
