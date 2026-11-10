#if DEBUG
import Foundation
import NudgeEngine

extension SeedSet {
    /// The Reminders tab's kept-order check (#325): sorted by due date, one already nudging reminder
    /// repeats every day, so Done moves its due time to tomorrow, which a fresh sort would put after
    /// "Due in 2 hours" and before "Due in 3 days". Nothing is relentless and none breaks through
    /// Focus, so no alarm is scheduled.
    static let keptOrder = SeedSet(
        name: "kept-order",
        settings: [.remindersSort: "dueDate.ascending"],
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(40), title: "Repeats daily, nudging", dueIn: -10 * minute, createdAgo: 5 * day, repeatRule: .everyDay),
            SeedReminder(id: SeedReminder.fixedID(41), title: "Due in 2 hours", dueIn: 2 * hour, createdAgo: 4 * day),
            SeedReminder(id: SeedReminder.fixedID(42), title: "Due in 3 days", dueIn: 3 * day, createdAgo: 3 * day),
            SeedReminder(id: SeedReminder.fixedID(43), title: "Due in a week", dueIn: 7 * day, createdAgo: 2 * day),
        ]
    )
}

private let minute: TimeInterval = 60
private let hour: TimeInterval = 3600
private let day: TimeInterval = 86400
#endif
