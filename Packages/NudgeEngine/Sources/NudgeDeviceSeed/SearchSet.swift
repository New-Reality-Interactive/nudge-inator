#if DEBUG
import Foundation

extension SeedSet {
    /// The Reminders tab's search check (#112): titles and notes with different case, diacritics and
    /// word order, a tag whose name appears nowhere in a title or its notes, and a mix of statuses.
    /// Sorted by due date so the sort and the search act together. Nothing is relentless and
    /// none breaks through Focus, so no alarm is scheduled.
    static let search = SeedSet(
        name: "search",
        tags: ["errands", "health"],
        settings: [.remindersSort: "dueDate.ascending"],
        reminders: [
            SeedReminder(
                id: SeedReminder.fixedID(1),
                title: "Take Pills", tagNames: ["health"],
                dueIn: 3 * hour, createdAgo: 7 * day
            ),
            SeedReminder(
                id: SeedReminder.fixedID(2),
                title: "Café meeting with Sam", notes: "Bring the signed contract",
                dueIn: day, createdAgo: 6 * day, strength: .firm
            ),
            SeedReminder(
                id: SeedReminder.fixedID(3),
                title: "Buy milk today", tagNames: ["errands"],
                dueIn: 2 * hour, createdAgo: 5 * day
            ),
            SeedReminder(
                id: SeedReminder.fixedID(4),
                title: "Milk: buy", notes: "Check the date on the carton", tagNames: ["errands"],
                dueIn: 5 * hour, createdAgo: 4 * day
            ),
            SeedReminder(
                id: SeedReminder.fixedID(5),
                title: "Call the dentist", notes: "Ask for the Tuesday slot", tagNames: ["health"],
                dueIn: -10 * minute, createdAgo: 3 * day
            ),
            SeedReminder(
                id: SeedReminder.fixedID(6),
                title: "Stretch", tagNames: ["health"],
                dueIn: 2 * day, createdAgo: 2 * day
            ),
            SeedReminder(
                id: SeedReminder.fixedID(7),
                title: "Pay rent", notes: "Transfer from savings",
                dueIn: 3 * day, createdAgo: day, strength: .firm
            ),
        ]
    )
}

private let minute: TimeInterval = 60
private let hour: TimeInterval = 3600
private let day: TimeInterval = 86400
#endif
