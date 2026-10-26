#if DEBUG
import Foundation
import NudgeEngine

extension NowScreen {
    /// The mockup's kind of morning, around the current minute, over an engine with no adapters:
    /// three cards (High next, ringing, and Gentle), two Coming Up and one of each closing.
    static func preview() -> NowScreen {
        let now = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        let home = Tag(name: "home")
        let reminders = [
            Reminder(title: "Take the bins out", tagIDs: [home.id], dueTime: ago(40), strength: .firm),
            Reminder(title: "Call the bank", dueTime: ago(20), strength: .relentless),
            Reminder(title: "Morning meds", dueTime: ago(120), repeatRule: .everyDay, strength: .gentle),
            Reminder(title: "Pay rent", dueTime: ago(-2 * 24 * 60), strength: .relentless),
            Reminder(title: "Water the plants", dueTime: ago(-24 * 60), repeatRule: RepeatRule(frequency: .daily, interval: 3),
                     strength: .gentle, breakThroughFocus: false),
            Reminder(title: "Walk the dog", dueTime: ago(180), strength: .gentle),
            Reminder(title: "Tidy the desk", dueTime: ago(300), strength: .firm),
            Reminder(title: "Stretch break", dueTime: ago(60), strength: .firm),
        ]
        let clock = PreviewClock(now: ago(170))
        var engine = Engine(clock: clock, scheduler: NoOpScheduler())
        engine.update(tags: [home])
        engine.update(reminders: reminders)
        engine.markDone(reminders[5].id)
        clock.now = ago(30)
        engine.pause(reminders[7].id)
        clock.now = now
        return NowScreen(engine: engine)
    }
}
#endif
