#if DEBUG
import Foundation
import NudgeEngine

extension SeedSet {
    /// #375's phone check of My Day's other days. Morning meds repeats daily from 3 days back, so
    /// the range starts 3 days ago and each past day lists it, Missed, since nobody marked it Done;
    /// Stretch break is Nudging today, so its Done swipe can be checked. Water the plants (weekly)
    /// and Call the dentist and Take the bins out (once) fall on coming days, two of them tagged,
    /// so a tag filter has something to keep on each. Gentle,
    /// as every set is, so no real alarm is scheduled. Load it at least 2 hours before midnight.
    static let myDayDays = SeedSet(
        name: "my-day-days",
        tags: ["home", "health"],
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(73), title: "Morning meds", tagNames: ["health"], dueIn: -3 * day - 2 * hour, createdAgo: 3 * day + 3 * hour, repeatRule: .everyDay),
            SeedReminder(id: SeedReminder.fixedID(74), title: "Stretch break", dueIn: -5 * minute, createdAgo: 10 * minute),
            SeedReminder(id: SeedReminder.fixedID(75), title: "Water the plants", tagNames: ["home"], dueIn: 2 * day + hour, createdAgo: 3 * day, repeatRule: .everyWeek),
            SeedReminder(id: SeedReminder.fixedID(76), title: "Call the dentist", tagNames: ["health"], dueIn: day + hour, createdAgo: 2 * day),
            SeedReminder(id: SeedReminder.fixedID(77), title: "Take the bins out", tagNames: ["home"], dueIn: 5 * day, createdAgo: day),
        ]
    )
}

private let minute: TimeInterval = 60
private let hour: TimeInterval = 60 * minute
private let day: TimeInterval = 24 * hour
#endif
