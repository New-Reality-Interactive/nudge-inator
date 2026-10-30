import Foundation
import Testing
@testable import NudgeEngine

/// The Reminders tab's list: every reminder once, with its status and due time, in creation-date
/// order (spec #104, Reminders list). At 13:00 on Friday 16 October 2026 in New York.
struct RemindersListTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 16, 13))
    let scheduler = FakeScheduler()

    func engine(holding reminders: [Reminder]) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return engine
    }

    func reminder(_ title: String, createdAt: Date, dueTime: Date = NewYork.local(2026, 10, 20)) -> Reminder {
        Reminder(title: title, dueTime: dueTime, strength: .gentle, createdAt: createdAt)
    }

    @Test func theListIsInCreationDateOrderOldestFirstWithTiesInTheOrderTheyWereAdded() {
        // 1.2.0's reminders share one migration instant, so they tie and keep their list order.
        let migrated = NewYork.local(2026, 10, 10)
        let engine = engine(holding: [
            reminder("Made yesterday", createdAt: NewYork.local(2026, 10, 15)),
            reminder("Migrated first", createdAt: migrated),
            reminder("Migrated second", createdAt: migrated),
            reminder("Made this morning", createdAt: NewYork.local(2026, 10, 16, 8)),
            reminder("Migrated third", createdAt: migrated),
        ])

        let titles = engine.remindersList().items.map(\.reminder.title)

        #expect(titles == ["Migrated first", "Migrated second", "Migrated third", "Made yesterday", "Made this morning"])
    }

    /// One reminder in each status at 13:00, made one after another so the list is in this order.
    struct OneOfEach {
        var engine: Engine
        /// Due at 12:30 today and not Done.
        let alex: Reminder
        /// Every day at 10:00, paused at 13:00.
        let stretch: Reminder
        /// Due tomorrow at 13:15.
        let dentist: Reminder
        /// Every day at 7:00, today's Done, so tomorrow's is next.
        let dog: Reminder
        /// Due at 9:00 today, Done at 9:10.
        let meds: Reminder
        /// Due at 9:00 on Wednesday 14 October, given up a day later.
        let carService: Reminder
        /// Every day at 9:00 from Wednesday to today, paused over today's, so it ended Skipped. A
        /// pause span that ended with nothing left to resume at comes only from the store.
        let physio: Reminder
    }

    func oneOfEach() -> OneOfEach {
        func made(_ minute: Int) -> Date { NewYork.local(2026, 10, 1, 8, minute) }
        let alex = Reminder(title: "Reply to Alex", dueTime: NewYork.local(2026, 10, 16, 12, 30), strength: .firm, createdAt: made(0))
        let stretch = Reminder(title: "Stretch break", dueTime: NewYork.local(2026, 10, 1, 10), repeatRule: .everyDay, strength: .firm, createdAt: made(1))
        let dentist = Reminder(title: "Dentist appointment", dueTime: NewYork.local(2026, 10, 17, 13, 15), strength: .firm, createdAt: made(2))
        let dog = Reminder(title: "Walk the dog", dueTime: NewYork.local(2026, 10, 1, 7), repeatRule: .everyDay, strength: .gentle, createdAt: made(3))
        let meds = Reminder(title: "Morning meds", dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle, createdAt: made(4))
        let carService = Reminder(title: "Book the car service", dueTime: NewYork.local(2026, 10, 14, 9), strength: .gentle, createdAt: made(5))
        let physio = Reminder(
            title: "Physio exercises",
            dueTime: NewYork.local(2026, 10, 14, 9),
            repeatRule: RepeatRule(.daily, end: .untilDate(year: 2026, month: 10, day: 16)),
            strength: .gentle,
            createdAt: made(6)
        )
        clock.now = NewYork.local(2026, 10, 16, 7, 10)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        // Paused the evening before its last due time and resumed after it, as the store hands back.
        engine.update(histories: [physio.id: ReminderHistory(pauseSpans: [PauseSpan(start: NewYork.local(2026, 10, 15, 20), end: NewYork.local(2026, 10, 16, 12))])])
        engine.update(reminders: [alex, stretch, dentist, dog, meds, carService, physio])
        engine.markDone(dog.id)
        clock.now = NewYork.local(2026, 10, 16, 9, 10)
        engine.markDone(meds.id)
        clock.now = NewYork.local(2026, 10, 16, 13)
        engine.pause(stretch.id)
        return OneOfEach(engine: engine, alex: alex, stretch: stretch, dentist: dentist, dog: dog, meds: meds, carService: carService, physio: physio)
    }

    @Test func eachRowHasTheDetailsHeroStatus() {
        let day = oneOfEach()

        #expect(day.engine.remindersList().items.map(\.status) == [
            .nudging,
            .paused,
            .comingUp,
            .comingUp,
            .closed(.done),
            .closed(.missed(reason: .giveUpLimit)),
            .closed(.skipped(reason: .paused)),
        ])
        #expect(day.engine.status(of: day.alex.id) == .nudging)
        #expect(day.engine.status(of: UUID()) == nil)
    }

    @Test func eachRowsDueTimeIsTheOpenOnesElseTheNextElseTheLatest() {
        let day = oneOfEach()

        #expect(day.engine.remindersList().items.map(\.dueTime) == [
            NewYork.local(2026, 10, 16, 12, 30),
            // A paused reminder's next due time: the one it would be Skipped at.
            NewYork.local(2026, 10, 17, 10),
            NewYork.local(2026, 10, 17, 13, 15),
            NewYork.local(2026, 10, 17, 7),
            NewYork.local(2026, 10, 16, 9),
            NewYork.local(2026, 10, 14, 9),
            NewYork.local(2026, 10, 16, 9),
        ])
    }

    @Test func doneMissedPauseAndResumeNeverMoveARow() throws {
        var day = oneOfEach()
        let before = day.engine.remindersList().items.map(\.reminder.id)

        day.engine.markDone(day.alex.id)
        try day.engine.resume(day.stretch.id)
        day.engine.pause(day.dentist.id)
        clock.now = NewYork.local(2026, 10, 18, 13)
        day.engine.update(reminders: day.engine.reminders)

        #expect(day.engine.remindersList().items.map(\.reminder.id) == before)
    }

    /// The tab reads the list again each minute; the clock alone moves a row on.
    @Test func aRowTurnsNudgingAtItsDueTimeAndMissedAtTheGiveUpLimit() {
        let day = oneOfEach()
        func dentist() -> RemindersList.Item? {
            day.engine.remindersList().items.first { $0.reminder.id == day.dentist.id }
        }

        clock.now = NewYork.local(2026, 10, 17, 13, 14)
        #expect(dentist()?.status == .comingUp)
        clock.now = NewYork.local(2026, 10, 17, 13, 15)
        #expect(dentist()?.status == .nudging)
        clock.now = NewYork.local(2026, 10, 18, 13, 15)
        #expect(dentist()?.status == .closed(.missed(reason: .giveUpLimit)))
        #expect(dentist()?.dueTime == NewYork.local(2026, 10, 17, 13, 15))
    }
}
