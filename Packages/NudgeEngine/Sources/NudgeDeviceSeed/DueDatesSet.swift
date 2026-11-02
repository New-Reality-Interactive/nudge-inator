#if DEBUG
import Foundation

extension SeedSet {
    /// The Reminders tab's Due Date check (#114): due times over a month, so a range has days to
    /// include and leave out, where `search`'s all fall within three days. Sorted by due date so the
    /// days read in order. Nothing is relentless and none breaks through Focus, so no alarm is
    /// scheduled.
    static let dueDates = SeedSet(
        name: "due-dates",
        settings: [.remindersSort: "dueDate.ascending"],
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(8), title: "Already nudging", dueIn: -10 * minute, createdAgo: 7 * day),
            SeedReminder(id: SeedReminder.fixedID(9), title: "Due tomorrow", dueIn: day, createdAgo: 6 * day),
            SeedReminder(id: SeedReminder.fixedID(10), title: "Due in 2 days", dueIn: 2 * day, createdAgo: 5 * day),
            SeedReminder(id: SeedReminder.fixedID(11), title: "Due in 3 days", dueIn: 3 * day, createdAgo: 4 * day),
            SeedReminder(id: SeedReminder.fixedID(12), title: "Due in a week", dueIn: 7 * day, createdAgo: 3 * day),
            SeedReminder(id: SeedReminder.fixedID(13), title: "Due in two weeks", dueIn: 14 * day, createdAgo: 2 * day),
            SeedReminder(id: SeedReminder.fixedID(14), title: "Due in a month", dueIn: 30 * day, createdAgo: day),
        ]
    )
}

private let minute: TimeInterval = 60
private let day: TimeInterval = 86400
#endif
