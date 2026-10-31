import Foundation
import NudgeEngine

/// What the Reminders tab shows, read from the engine at one moment: every reminder once, in the
/// engine's order, with its status, due time and tags. A value, so the tests and previews read it
/// with no view.
struct RemindersScreen {
    let rows: [Row]
    /// Which empty state the tab shows in place of the list, or `nil` when it has rows.
    let emptyState: EmptyState?

    enum EmptyState: Equatable {
        /// The engine holds no reminder at all.
        case noReminders
    }

    struct Row: Identifiable {
        var reminder: Reminder
        var status: ReminderStatus
        /// The time of day of the row's due time, such as "9:00 AM".
        var time: String
        /// "Today", "Tomorrow", "Yesterday" or a short date, under the time.
        var day: String
        /// The reminder's tags that the engine holds, as "#home".
        var tags: [String]

        var id: Reminder.ID { reminder.id }
        var title: String { reminder.title }
        /// Done is offered only while Nudging (DESIGN.md, Swipe actions). Every row offers Delete.
        var offersDone: Bool { status == .nudging }
    }

    init(engine: Engine) {
        rows = engine.remindersList().items.map { item in
            Row(
                reminder: item.reminder,
                status: item.status,
                time: engine.timeOfDay(of: item.dueTime),
                day: engine.dayLabel(of: item.dueTime),
                tags: engine.tagLabels(for: item.reminder.tagIDs)
            )
        }
        emptyState = engine.reminders.isEmpty ? .noReminders : nil
    }
}
