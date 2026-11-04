#if DEBUG
import Foundation

extension SeedSet {
    /// The swipe tile's shape check (#126): two Nudging reminders at the extremes of a row's height,
    /// so the tiles can be compared on Now, My Day and Reminders. One has as little as a reminder
    /// can, and one a title, tags and a note long enough to wrap. Nothing is relentless and none
    /// breaks through Focus, so no alarm is scheduled.
    static let swipeTiles = SeedSet(
        name: "swipe-tiles",
        tags: ["home", "errands", "appointments", "family"],
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(15), title: "Bins", dueIn: -10 * minute, createdAgo: 2 * minute),
            SeedReminder(
                id: SeedReminder.fixedID(16),
                title: "Pick up the prescription and the dry cleaning on the way back from the school run",
                notes: "The pharmacy closes early on Wednesdays, and the dry cleaner needs the ticket from the kitchen drawer before they will hand anything over.",
                tagNames: ["home", "errands", "appointments", "family"],
                dueIn: -5 * minute,
                createdAgo: minute
            ),
        ]
    )
}

private let minute: TimeInterval = 60
#endif
