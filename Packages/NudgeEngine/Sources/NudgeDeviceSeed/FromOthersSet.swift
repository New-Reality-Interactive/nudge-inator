#if DEBUG
import Foundation
import NudgeEngine

extension SeedSet {
    /// The From others filter's check (ticket 209): reminders of the person's own, some tagged,
    /// beside ones the stand-in's Riley Park sent (`NUDGE_SHARING_STANDIN=seeded`), all due later
    /// today, on My Day and the Reminders tab. Five tags, so checking them all on My Day fills the
    /// tokens' rows and the From others token's own row shows under them. The first is due 30
    /// minutes after the load, so nothing nudges during the check: load it at least 3½ hours before
    /// midnight. Gentle, as every set is, so no real alarm is scheduled.
    static let fromOthers = SeedSet(
        name: "from-others",
        tags: ["home", "health", "errands", "appointments", "family"],
        reminders: [
            SeedReminder(
                id: SeedReminder.fixedID(50),
                title: "Walk the dog", tagNames: ["home"],
                dueIn: 30 * minute, createdAgo: 5 * minute
            ),
            SeedReminder(
                id: SeedReminder.fixedID(51),
                title: "Stretch", tagNames: ["health"],
                dueIn: 90 * minute, createdAgo: 4 * minute
            ),
            SeedReminder(
                id: SeedReminder.fixedID(52),
                title: "Take the bins out",
                dueIn: 150 * minute, createdAgo: 3 * minute
            ),
            SeedReminder(
                id: SeedReminder.fixedID(53),
                title: "Take the pills",
                dueIn: 60 * minute,
                createdAgo: 2 * minute,
                origin: .received(connectionID: standInConnectionID, sendersReminderID: SeedReminder.fixedID(55), revision: 1, state: .accepted)
            ),
            SeedReminder(
                id: SeedReminder.fixedID(54),
                title: "Call Grandma",
                dueIn: 120 * minute,
                createdAgo: minute,
                origin: .received(connectionID: standInConnectionID, sendersReminderID: SeedReminder.fixedID(56), revision: 1, state: .accepted)
            ),
        ]
    )
}

private let minute: TimeInterval = 60
#endif
