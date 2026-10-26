#if DEBUG
import Foundation
import NudgeEngine
import SwiftUI

extension ReminderDetails {
    /// Details over an engine with no adapters, so previews need no app model. `pausedAt` is how
    /// many minutes from now the reminder was paused, if it was (negative is in the past).
    static func preview(
        _ reminder: Reminder = Reminder(title: "Take the bins out", notes: "Green one too", dueTime: .now, strength: .firm),
        tags: [String] = ["home", "weekly"],
        pausedAt: Double? = nil
    ) -> ReminderDetails {
        let now = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        let clock = PreviewClock(now: now)
        var reminder = reminder
        let engineTags = tags.map { Tag(name: $0) }
        reminder.tagIDs = engineTags.map(\.id)
        var engine = Engine(clock: clock, scheduler: NoOpScheduler())
        engine.update(tags: engineTags)
        engine.update(reminders: [reminder])
        if let pausedAt {
            clock.now = now.addingTimeInterval(pausedAt * 60)
            engine.pause(reminder.id)
            clock.now = now
        }
        guard let details = ReminderDetails(engine: engine, id: reminder.id) else { preconditionFailure("The preview's reminder is in its engine") }
        return details
    }

    static func previewNudging() -> ReminderDetails {
        preview(Reminder(title: "Take the bins out", notes: "Green one too", dueTime: .now.addingTimeInterval(-40 * 60), strength: .firm))
    }

    /// A custom repeat that is paused after its latest occurrence was skipped.
    static func previewPaused() -> ReminderDetails {
        preview(Reminder(title: "Water the plants", dueTime: .now.addingTimeInterval(-20 * 60),
                         repeatRule: RepeatRule(frequency: .daily, interval: 3), strength: .gentle, breakThroughFocus: false),
                tags: ["garden"], pausedAt: -5)
    }

    static func previewComingUp() -> ReminderDetails {
        preview(Reminder(title: "Pay rent", dueTime: .now.addingTimeInterval(2 * 24 * 3600), strength: .relentless), tags: [])
    }
}

#Preview("Nudging") {
    NavigationStack { ReminderDetailsView(id: UUID(), preview: .previewNudging()) }
}

#Preview("Nudging, dark") {
    NavigationStack { ReminderDetailsView(id: UUID(), preview: .previewNudging()) }
        .preferredColorScheme(.dark)
}

#Preview("Nudging, largest text") {
    NavigationStack { ReminderDetailsView(id: UUID(), preview: .previewNudging()) }
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Nudging, landscape", traits: .landscapeLeft) {
    NavigationStack { ReminderDetailsView(id: UUID(), preview: .previewNudging()) }
}

#Preview("Paused") {
    NavigationStack { ReminderDetailsView(id: UUID(), preview: .previewPaused()) }
}

#Preview("Coming up") {
    NavigationStack { ReminderDetailsView(id: UUID(), preview: .previewComingUp()) }
}

#Preview("Not found") {
    NavigationStack { ReminderDetailsView(id: UUID()) }
}
#endif
