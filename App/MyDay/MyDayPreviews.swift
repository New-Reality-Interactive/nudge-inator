#if DEBUG
import Foundation
import NudgeEngine

extension Engine {
    /// A day around the current minute, over an engine with no adapters: one of each outcome, a
    /// nudging row, a paused one and three still to come, with tags to filter by.
    static func myDayPreview() -> Engine {
        let now = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        let today = Calendar.current.startOfDay(for: now)
        func at(_ minutes: Double) -> Date { today.addingTimeInterval(minutes * 60) }
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        let home = Tag(name: "home"), health = Tag(name: "health"), work = Tag(name: "work")
        let reminders = [
            Reminder(title: "Morning meds", tagIDs: [health.id], dueTime: ago(300), repeatRule: .everyDay, strength: .gentle),
            Reminder(title: "Team stand-up", tagIDs: [work.id], dueTime: ago(240), strength: .relentless),
            Reminder(title: "Reply to Alex", dueTime: ago(40), strength: .firm),
            Reminder(title: "Stretch break", tagIDs: [health.id, work.id], dueTime: ago(120), repeatRule: .everyDay, strength: .firm),
            Reminder(title: "Call Grandma", dueTime: at(23 * 60 + 50), strength: .gentle),
            Reminder(title: "Water the plants", tagIDs: [home.id], dueTime: now.addingTimeInterval(30 * 60), strength: .gentle),
            Reminder(title: "Take the bins out", tagIDs: [home.id], dueTime: now.addingTimeInterval(90 * 60), strength: .firm),
        ]
        let clock = PreviewClock(now: ago(280))
        var engine = Engine(clock: clock, scheduler: PreviewScheduler())
        engine.update(tags: [home, health, work])
        engine.update(reminders: reminders)
        clock.now = ago(270)
        engine.markDone(reminders[0].id)
        clock.now = ago(100)
        engine.pause(reminders[3].id)
        clock.now = now
        engine.update(reminders: engine.reminders)
        return engine
    }
}
#endif
