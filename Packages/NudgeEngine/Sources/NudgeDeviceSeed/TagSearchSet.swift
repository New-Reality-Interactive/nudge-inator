#if DEBUG
import Foundation

extension SeedSet {
    /// The Tags tab's search check (#141): a name with a diacritic, and a name that holds another,
    /// so a search narrows to one tag or to two. One tag has no reminders, and every due time is
    /// days away, so nothing rings during the check. Nothing is relentless and none breaks through
    /// Focus, so no alarm is scheduled.
    static let tagSearch = SeedSet(
        name: "tag-search",
        tags: ["café", "home", "homework", "travel"],
        reminders: [
            SeedReminder(
                id: SeedReminder.fixedID(17),
                title: "Book a table", tagNames: ["café"],
                dueIn: 4 * day, createdAgo: 3 * day
            ),
            SeedReminder(
                id: SeedReminder.fixedID(18),
                title: "Fix the gate", tagNames: ["home"],
                dueIn: 5 * day, createdAgo: 2 * day
            ),
            SeedReminder(
                id: SeedReminder.fixedID(19),
                title: "Read chapter 3", tagNames: ["homework"],
                dueIn: 6 * day, createdAgo: day
            ),
        ]
    )

    /// The check of the last tag going during a search (#141): one tag and no reminders, so a clean
    /// launch followed by this one leaves a list that deleting its only row empties.
    static let lastTag = SeedSet(
        name: "last-tag",
        tags: ["only"],
        reminders: []
    )
}

private let day: TimeInterval = 86400
#endif
