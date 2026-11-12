#if DEBUG
import Foundation
import NudgeEngine

extension SeedSet {
    /// The connection the stand-in sharing's Riley Park is (`NUDGE_SHARING_STANDIN=seeded`), so
    /// this set's reminders come from them.
    public static let standInConnectionID = UUID(uuid: (0x5E, 0xED, 0x00, 0x02, 0x00, 0x00, 0x40, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01))

    /// The notes on every reminder the stand-in's Riley Park sends (ticket 198). Removal finds a
    /// send by them once Keep as My Own Reminders has made it the person's own, with no connection
    /// left to find it by (#199's phone check).
    public static let standInSentNotes = "Sent from the stand-in."

    /// Disconnect's check (ticket 197): reminders received from the stand-in's Riley Park, to
    /// Remove or Keep as My Own Reminders. Two accepted, which Keep keeps, and one still waiting to
    /// be accepted, which goes either way, so Disconnect's sheet counts 2. The first nudges
    /// about 2 minutes after the load, so a check can see it still come after Keep. Gentle, as every
    /// set is, so no real alarm is scheduled.
    static let received = SeedSet(
        name: "received",
        reminders: [
            SeedReminder(
                id: SeedReminder.fixedID(44),
                title: "Take the pills",
                dueIn: 2 * minute,
                createdAgo: 3 * minute,
                repeatRule: .everyDay,
                origin: .received(connectionID: standInConnectionID, sendersReminderID: SeedReminder.fixedID(47), revision: 1, state: .accepted)
            ),
            SeedReminder(
                id: SeedReminder.fixedID(45),
                title: "Call the dentist",
                dueIn: 3 * 60 * minute,
                createdAgo: 2 * minute,
                origin: .received(connectionID: standInConnectionID, sendersReminderID: SeedReminder.fixedID(48), revision: 1, state: .accepted)
            ),
            SeedReminder(
                id: SeedReminder.fixedID(46),
                title: "Water the plants",
                dueIn: 60 * minute,
                createdAgo: minute,
                origin: .received(connectionID: standInConnectionID, sendersReminderID: SeedReminder.fixedID(49), revision: 1, state: .waiting)
            ),
        ]
    )
}

private let minute: TimeInterval = 60
#endif
