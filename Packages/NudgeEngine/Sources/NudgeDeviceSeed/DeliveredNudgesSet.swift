#if DEBUG
import Foundation

extension SeedSet {
    /// #156's check that a delete removes a reminder's delivered notifications: two Gentle
    /// reminders due about two minutes after the load, so each sends its first nudge then and both
    /// notifications are in Notification Center together. Nothing is relentless and none breaks
    /// through Focus, so no alarm is scheduled.
    static let deliveredNudges = SeedSet(
        name: "delivered-nudges",
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(20), title: "Water the plants", dueIn: 150, createdAgo: 2 * minute),
            SeedReminder(id: SeedReminder.fixedID(21), title: "Email the landlord", dueIn: 150, createdAgo: minute),
        ]
    )
}

private let minute: TimeInterval = 60
#endif
