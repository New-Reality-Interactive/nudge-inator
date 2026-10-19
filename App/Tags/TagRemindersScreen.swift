import Foundation
import NudgeEngine

/// What a tag's screen shows, read from the engine at one moment: the reminders with the tag in
/// the mockup's sections (`remSections`). A value, so the tests and previews read it with no view.
struct TagRemindersScreen {
    let tag: Tag
    let sections: [Section]

    enum SectionKind: Hashable {
        /// Nudging, or due later today.
        case today
        case later
        case paused
        /// Nothing more is coming.
        case completed
    }

    struct Section: Identifiable {
        var kind: SectionKind
        var rows: [Row]

        var id: SectionKind { kind }
    }

    struct Row: Identifiable {
        var reminder: Reminder
        /// When it is next due, or nudging since. `nil` when paused or finished.
        var dueTime: Date?
        var time: String?
        /// "Today", "Tomorrow" or a short date, under the time.
        var day: String?
        /// The repeat summary, such as "Every day at 8:00 AM".
        var schedule: String
        /// The reminder's tags that the engine holds, this screen's tag in bold.
        var tags: [MyDayScreen.TagLabel]

        var id: Reminder.ID { reminder.id }
        var title: String { reminder.title }
    }

    var reminderCount: Int { sections.reduce(0) { $0 + $1.rows.count } }

    /// `nil` when the engine doesn't hold the tag: it was deleted while its screen was open.
    init?(engine: Engine, tagID: Tag.ID) {
        guard let tag = engine.tag(withID: tagID) else { return nil }
        self.tag = tag
        let dueToday = Set(engine.myDay().items.filter { $0.status == .left }.map(\.reminderID))
        var byKind: [SectionKind: [Row]] = [:]
        for reminder in engine.taggedReminders(tagID) {
            guard let details = ReminderDetails(engine: engine, id: reminder.id) else { continue }
            var dueTime: Date?
            let kind: SectionKind
            switch details.status {
            case .nudging:
                kind = .today
                dueTime = engine.openOccurrence(for: reminder.id)?.dueTime
            case .comingUp:
                dueTime = engine.comingUp().first { $0.reminderID == reminder.id }?.dueTime
                    ?? engine.upcomingDueTimes(of: reminder, count: 1).first
                kind = dueToday.contains(reminder.id) ? .today : .later
            case .paused: kind = .paused
            case .closed: kind = .completed
            }
            byKind[kind, default: []].append(Row(
                reminder: reminder,
                dueTime: dueTime,
                time: dueTime.map { engine.timeOfDay(of: $0) },
                day: dueTime.map { engine.dayLabel(of: $0) },
                schedule: engine.repeatSummary(of: reminder),
                tags: reminder.tagIDs.compactMap { id in
                    engine.tag(withID: id).map { MyDayScreen.TagLabel(text: $0.label, isChosen: id == tagID) }
                }
            ))
        }
        sections = [SectionKind.today, .later, .paused, .completed].compactMap { kind in
            guard var rows = byKind[kind] else { return nil }
            if kind == .today || kind == .later {
                rows.sort { ($0.dueTime ?? .distantFuture, $0.title) < ($1.dueTime ?? .distantFuture, $1.title) }
            }
            return Section(kind: kind, rows: rows)
        }
    }
}
