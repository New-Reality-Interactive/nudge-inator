#if DEBUG
import Foundation

extension SeedSet {
    /// The Tags tab's and the form's name-order check (#335): tags that show the locale's order. In
    /// English "éclair" sits between "apple" and "Eve" (it is an accented e), and "Tag 2" comes before
    /// "Tag 10"; by code point "éclair" would come last. Every due time is days away, so nothing
    /// rings, and nothing is relentless or breaks through Focus, so no alarm is scheduled. The first
    /// reminder has two tags and the rest one, so the Reminders sort has a tie to break by name.
    static let nameOrder = SeedSet(
        name: "name-order",
        tags: ["zoo", "éclair", "Eve", "apple", "Tag 10", "Tag 2"],
        reminders: [
            SeedReminder(
                id: SeedReminder.fixedID(63),
                title: "Plan the week", tagNames: ["zoo", "apple"],
                dueIn: 4 * day, createdAgo: 3 * day
            ),
            SeedReminder(
                id: SeedReminder.fixedID(64),
                title: "Bake something", tagNames: ["éclair"],
                dueIn: 5 * day, createdAgo: 2 * day
            ),
            SeedReminder(
                id: SeedReminder.fixedID(65),
                title: "Call Eve", tagNames: ["Eve"],
                dueIn: 6 * day, createdAgo: day
            ),
        ]
    )
}

private let day: TimeInterval = 86400
#endif
