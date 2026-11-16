#if DEBUG
import Foundation
import NudgeEngine

extension SeedSet {
    /// #429's phone check of Mine's swipes, with `NUDGE_SHARING_STANDIN=sent` for Sent's: two
    /// reminders of the person's own, one Nudging (Done, Edit and Delete) and one Coming up (Edit
    /// and Delete), and one received from the stand-in's Riley Park (Remove alone). Gentle, as every
    /// set is, so no real alarm is scheduled.
    static let rowSwipes = SeedSet(
        name: "row-swipes",
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(57), title: "Stretch break", dueIn: -5 * minute, createdAgo: 3 * minute),
            SeedReminder(id: SeedReminder.fixedID(58), title: "Book the car service", dueIn: 2 * 60 * minute, createdAgo: 2 * minute),
            SeedReminder(
                id: SeedReminder.fixedID(59),
                title: "Take the vitamins",
                dueIn: 3 * 60 * minute,
                createdAgo: minute,
                origin: .received(connectionID: standInConnectionID, sendersReminderID: SeedReminder.fixedID(60), revision: 1, state: .accepted)
            ),
        ]
    )
}

private let minute: TimeInterval = 60
#endif
