#if DEBUG
import Foundation
import NudgeEngine

extension SeedSet {
    /// #457's phone check of the details page's Sound row: one Firm reminder two days away, with
    /// Break Through Focus off, as every seeded reminder has, so it has no row until the check turns
    /// the switch on in Edit. `clean` deletes it, which cancels the alarms that schedules.
    static let detailsSound = SeedSet(
        name: "details-sound",
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(61), title: "Water the plants", notes: "The ferns on the balcony too.", dueIn: 2 * 86_400, createdAgo: 86_400, strength: .firm),
        ]
    )
}
#endif
