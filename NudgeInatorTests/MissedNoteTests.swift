import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Missed note (#369): an occurrence that closed as Missed, and that quiet hours held a nudge
/// of, says how many of its nudges were held, on Now's Last 24 Hours, its My Day row and the
/// reminder details' Last occurrence row (the mockup `docs/mockups/2026-11-21-missed-note/`). Read
/// from the app model over the fakes; which nudges the engine holds is #367's. A class so `deinit`
/// removes the defaults each test wrote, even when it fails.
@MainActor
final class MissedNoteTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let center = FakeNotificationCenter()
    let manager = FakeAlarmManager()
    let suiteName = "MissedNoteTests.\(UUID().uuidString)"
    let storeFile = TemporaryStoreFile()

    /// Thursday 15 October 2026 at 9:00, once, Relentless: nudges at 9:00, 9:10, 9:15 and 9:17:30,
    /// then every 2 minutes to nudge 20 at 9:49:30, and gives up at 9:51:30. The 9:12 to 9:18
    /// window holds nudges 3 and 4.
    let cat = Reminder(title: "Feed the cat", dueTime: NewYork.local(2026, 10, 15, 9), strength: .relentless)
    /// The same ladder an hour later, outside the window: Missed at 10:51:30 with nothing held.
    let stretch = Reminder(title: "Stretch break", dueTime: NewYork.local(2026, 10, 15, 10), strength: .relentless)
    /// Due at 9:14 inside the window, Done at 9:30.
    let walk = Reminder(title: "Walk the dog", dueTime: NewYork.local(2026, 10, 15, 9, 14), strength: .relentless)
    /// Due at 9:13 inside the window, paused at 9:16: Skipped.
    let call = Reminder(title: "Call Grandma", dueTime: NewYork.local(2026, 10, 15, 9, 13), strength: .relentless)

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    func launchedModel(clock: FakeClock? = nil) async throws -> AppModel {
        let clock = clock ?? self.clock
        let store = try ReminderStore(location: .file(storeFile.url))
        let model = AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: center, clock: clock),
            alarms: AlarmAdapter(manager: manager, clock: clock),
            settingsRecords: .temporary(quietHours: QuietHoursRecord(defaults: try #require(UserDefaults(suiteName: suiteName)))),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
        await model.launch()
        return model
    }

    func window(from start: TimeOfDay, to end: TimeOfDay) throws -> QuietHours {
        QuietHours(schedules: [try QuietHoursSchedule(start: start, end: end, days: [.thursday])])
    }

    /// Quiet hours 9:12 to 9:18, the four reminders added, and the clock at 11:00 once all have closed.
    func modelAtEleven() async throws -> AppModel {
        let model = try await launchedModel()
        model.quietHours = try window(from: TimeOfDay(hour: 9, minute: 12), to: TimeOfDay(hour: 9, minute: 18))
        for reminder in [cat, stretch, walk, call] { model.add(reminder) }
        clock.now = NewYork.local(2026, 10, 15, 9, 16)
        await model.appOpened()
        model.pause(call.id)
        clock.now = NewYork.local(2026, 10, 15, 9, 30)
        await model.appOpened()
        model.markDone(walk.id)
        clock.now = NewYork.local(2026, 10, 15, 11)
        await model.appOpened()
        await model.waitUntilApplied()
        return model
    }

    /// The note on each of the three screens, by reminder title.
    struct Notes: Equatable {
        var now: MissedNote?
        var myDay: MissedNote?
        var details: MissedNote?
    }

    func notes(of reminder: Reminder, in model: AppModel) throws -> Notes {
        let now = NowScreen(engine: model.engine).lastDay.first { $0.reminder.id == reminder.id }
        let myDay = MyDayScreen(engine: model.engine, filter: MyDayFilter(), now: clock.now).items.first { $0.reminder.id == reminder.id }
        let details = try #require(ReminderDetails(engine: model.engine, id: reminder.id))
        #expect(now != nil && myDay != nil && details.lastOccurrence != nil)
        return Notes(now: now?.missedNote, myDay: myDay?.missedNote, details: details.lastOccurrence?.missedNote)
    }

    func plain(_ resource: LocalizedStringResource) -> String {
        String(AttributedString(localized: resource).characters)
    }

    /// Criterion 2: a Missed occurrence with held nudges shows the held count and the total on
    /// all three screens.
    @Test func aMissedOccurrenceWithHeldNudgesShowsTheNoteOnEveryScreen() async throws {
        let model = try await modelAtEleven()

        let note = MissedNote(held: 2, total: 20)
        #expect(try notes(of: cat, in: model) == Notes(now: note, myDay: note, details: note))
        #expect(plain(note.text) == "Quiet hours held 2 of its 20 nudges.")
    }

    /// Criterion 2: Done, Skipped, and Missed with nothing held show no note.
    @Test(arguments: ["Stretch break", "Walk the dog", "Call Grandma"])
    func anOccurrenceThatIsNotMissedWithHeldNudgesShowsNoNote(title: String) async throws {
        let model = try await modelAtEleven()
        let reminder = try #require([stretch, walk, call].first { $0.title == title })

        #expect(try notes(of: reminder, in: model) == Notes())
    }

    /// Criterion 3: removing the window, or widening it over every nudge, leaves the note as it was.
    @Test func editingTheSchedulesLaterLeavesTheNoteAsItWas() async throws {
        let model = try await modelAtEleven()

        model.quietHours = QuietHours()
        let note = MissedNote(held: 2, total: 20)
        #expect(try notes(of: cat, in: model) == Notes(now: note, myDay: note, details: note))

        model.quietHours = try window(from: TimeOfDay(hour: 8), to: TimeOfDay(hour: 11, minute: 30))
        #expect(try notes(of: cat, in: model) == Notes(now: note, myDay: note, details: note))
        #expect(try notes(of: stretch, in: model) == Notes())
    }

    /// Criterion 3, after a relaunch: the schedules the edit replaced are read back, so the count
    /// is still the one the nudges were held under.
    @Test func theNoteIsTheSameAfterAnEditAndARelaunch() async throws {
        let model = try await modelAtEleven()
        model.quietHours = QuietHours()

        let relaunched = try await launchedModel()
        let note = MissedNote(held: 2, total: 20)
        #expect(try notes(of: cat, in: relaunched) == Notes(now: note, myDay: note, details: note))
    }

    #if DEBUG
    /// Criterion 6's seed set: loaded through the model, its reminder shows "5 of its 20" on its
    /// details, and `clean` takes the quiet span away, leaving the schedules as they were. The seed
    /// counts from the real clock, so the model's clock is set to it.
    @Test func theMissedNoteSeedSetShowsFiveOfTwentyHeldAndCleanRemovesItsSpan() async throws {
        let model = try await launchedModel(clock: FakeClock(now: Date()))
        let target = ModelSeedTarget(model: model)
        let record = UserDefaultsSeedRecordStore(defaults: try #require(UserDefaults(suiteName: suiteName)))
        let set = try #require(SeedSet.all.first { $0.name == "missed-note" })
        let seeded = try #require(set.reminders.first)

        #expect(DeviceSeed.run(command: set.name, sets: SeedSet.all, on: target, record: record) == .loaded(set.name))
        let details = try #require(ReminderDetails(engine: model.engine, id: seeded.id))
        #expect(details.lastOccurrence?.state == .missed(reason: .giveUpLimit))
        #expect(details.lastOccurrence?.missedNote == MissedNote(held: 5, total: 20))
        #expect(model.quietHours == QuietHours())

        #expect(DeviceSeed.run(command: "clean", sets: SeedSet.all, on: target, record: record) == .cleaned)
        #expect(model.engine.replacedQuietHours.isEmpty)
        #expect(QuietHoursRecord(defaults: try #require(UserDefaults(suiteName: suiteName))).replacedQuietHours.isEmpty)
    }
    #endif

    /// Criterion 4: the total has plural forms.
    @Test(arguments: [
        (1, 1, "Quiet hours held 1 of its 1 nudge."),
        (1, 20, "Quiet hours held 1 of its 20 nudges."),
        (20, 20, "Quiet hours held 20 of its 20 nudges."),
    ])
    func theNoteSaysTheHeldCountAndTheTotal(held: Int, total: Int, text: String) {
        #expect(plain(MissedNote(held: held, total: total).text) == text)
    }
}
