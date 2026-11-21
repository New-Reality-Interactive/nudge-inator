#if DEBUG
import Foundation

extension SeedSet {
    /// #369's Missed note check: one Firm reminder due 3 hours before the load, with quiet hours
    /// over the hour after its due time, turned off at the load. Firm nudges at 0, 30, 45, 52½ and
    /// 57½ minutes, so quiet hours held those 5, and it gave up after its 20th nudge, about 2¼ hours
    /// after it was due: Missed, "Quiet hours held 5 of its 20 nudges.", on Now's Last 24 Hours, My
    /// Day and its details. Load it after 3 AM, so it was due today. Break Through Focus is off, so
    /// nothing rings, and being closed it schedules nothing.
    static let missedNote = SeedSet(
        name: "missed-note",
        quietHoursBefore: SeedQuietSpan(startIn: -3 * hour, length: hour),
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(66), title: "Feed the cat", dueIn: -3 * hour, createdAgo: 4 * hour, strength: .firm),
        ]
    )
}

private let hour: TimeInterval = 60 * 60
#endif
