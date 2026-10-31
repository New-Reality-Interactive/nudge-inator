import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Reminders tab through `RemindersScreen`, read from the real app model on ticket 16's
/// fixture (13:00 on Friday 16 October). The fixture adds its reminders at one moment, so they tie
/// on creation date and keep the order they were added in. Layout and VoiceOver are screenshot and
/// device checks.
@MainActor
struct RemindersScreenTests {
    let fixture = MyDayScreenTests()

    @Test func everyReminderIsARowInTheOrderTheyWereAddedWithItsStatus() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = RemindersScreen(engine: day.model.engine)

        #expect(screen.rows.map(\.title) == [
            "Take the bins out", "Water the plants", "Call Grandma", "Send the status update", "Reply to Alex",
            "Stretch break", "Team stand-up", "Walk the dog", "Morning meds", "Dentist appointment",
        ])
        #expect(screen.rows.map(\.status) == [
            .comingUp, .comingUp, .paused, .comingUp, .nudging,
            .paused, .closed(.missed(reason: .giveUpLimit)), .comingUp, .comingUp, .comingUp,
        ])
        #expect(screen.emptyState == nil)
    }

    @Test func aRowShowsItsDueTimeAndDayAndItsTags() async throws {
        let day = try await fixture.dayAtOnePM()

        let screen = RemindersScreen(engine: day.model.engine)
        func row(_ reminder: Reminder) throws -> RemindersScreen.Row {
            try #require(screen.rows.first { $0.id == reminder.id })
        }

        let alex = try row(day.alex)
        #expect((alex.time, alex.day, alex.tags) == ("12:30\u{202F}PM", "Today", []))
        // Done this morning, so tomorrow's is next.
        let dog = try row(day.dog)
        #expect((dog.time, dog.day, dog.tags) == ("7:00\u{202F}AM", "Tomorrow", ["#home"]))
        // Given up, so its latest occurrence's.
        let standUp = try row(day.standUp)
        #expect((standUp.time, standUp.day, standUp.tags) == ("9:30\u{202F}AM", "Today", ["#work"]))
        let stretch = try row(day.stretch)
        #expect(stretch.tags == ["#health", "#work"])
    }

    @Test func doneChangesARowsStatusInPlace() async throws {
        let day = try await fixture.dayAtOnePM()
        let before = RemindersScreen(engine: day.model.engine).rows.map(\.id)

        day.model.markDone(day.alex.id)

        let after = RemindersScreen(engine: day.model.engine)
        #expect(after.rows.map(\.id) == before)
        #expect(after.rows.first { $0.id == day.alex.id }?.status == .closed(.done))
    }

    @Test func aNewReminderShowsLastAsTheNewestCreated() async throws {
        let day = try await fixture.dayAtOnePM()

        day.model.add(Reminder(title: "Renew the passport", dueTime: NewYork.local(2026, 10, 30), strength: .gentle))

        #expect(RemindersScreen(engine: day.model.engine).rows.last?.title == "Renew the passport")
    }

    @Test func withNoRemindersTheEmptyStateSaysThereAreNoneYet() async throws {
        let model = try await fixture.launchedModel()

        let screen = RemindersScreen(engine: model.engine)

        #expect(screen.rows.isEmpty)
        #expect(screen.emptyState == .noReminders)
    }
}
