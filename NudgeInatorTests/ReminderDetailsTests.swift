import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The reminder details screen through `ReminderDetails`, what it draws, read from the real app
/// model (in-memory store, real adapters over the fakes). Layout, the confirmation dialog, the
/// Edit sheet, VoiceOver and Dynamic Type are screenshot and device checks.
@MainActor
struct ReminderDetailsTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 16, 7))
    let center = FakeNotificationCenter()
    let manager = FakeAlarmManager()

    /// Today at 9:00, once, Firm, with notes.
    let bins = Reminder(title: "Take the bins out", notes: "Green one too", dueTime: NewYork.local(2026, 10, 16, 9), strength: .firm)

    /// Every day at 8:00 since 1 October, Gentle.
    let meds = Reminder(title: "Morning meds", dueTime: NewYork.local(2026, 10, 1, 8), repeatRule: .everyDay, strength: .gentle)

    func launchedModel(store: ReminderStore? = nil) async throws -> AppModel {
        let store = try store ?? ReminderStore(location: .inMemory)
        let model = AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: center, clock: clock),
            alarms: AlarmAdapter(manager: manager, clock: clock),
            timeZone: NewYork.timeZone
        )
        await model.launch()
        return model
    }

    /// How It Nudges (ticket 31) follows the reminder's own strength and Break Through Focus
    /// switch: Firm's nudges 4–20 ring, unless the switch is off.
    @Test(arguments: [
        (true, NudgeDelivery.alarm),
        (false, .notification(weakerBecause: .breakThroughFocusOff)),
    ])
    func howItNudgesFollowsTheRemindersSwitch(breakThroughFocus: Bool, urgent: NudgeDelivery) async throws {
        let model = try await launchedModel()
        var reminder = bins
        reminder.breakThroughFocus = breakThroughFocus
        model.add(reminder)

        let rows = try #require(ReminderDetails(engine: model.engine, id: reminder.id)).howItNudges.rows
        #expect(rows.map(\.nudges) == [1...1, 2...2, 3...3, 4...20])
        #expect(rows.last?.delivery == urgent)
    }

    @Test func aReminderTheEngineDoesntHoldHasNoDetails() async throws {
        let model = try await launchedModel()

        #expect(ReminderDetails(engine: model.engine, id: UUID()) == nil)
    }

    /// The mockup's hero: the title, the notes, the strength, and the tags as "#name". Only tags
    /// the engine holds, as the cards do.
    @Test func theHeroShowsTheTitleNotesStrengthAndTags() async throws {
        let model = try await launchedModel()
        let home = try #require(try model.createTag(named: "home"))
        var tagged = bins
        tagged.tagIDs = [home.id, UUID()]
        model.add(tagged)

        let details = try #require(ReminderDetails(engine: model.engine, id: bins.id))

        #expect(details.title == "Take the bins out")
        #expect(details.notes == "Green one too")
        #expect(details.strength == .firm)
        #expect(details.tags == ["#home"])
    }

    /// Criterion 1: Done is shown only while Nudging. The card, with its Done, appears at the due
    /// time and goes when the occurrence closes.
    @Test func doneIsOfferedOnlyWhileTheReminderIsNudging() async throws {
        let model = try await launchedModel()
        model.add(bins)

        let before = try #require(ReminderDetails(engine: model.engine, id: bins.id))
        #expect(before.status == .comingUp)
        #expect(!before.offersDone)

        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        await model.appOpened()
        let nudging = try #require(ReminderDetails(engine: model.engine, id: bins.id))
        #expect(nudging.status == .nudging)
        #expect(nudging.offersDone)
        #expect(nudging.card?.title == "Take the bins out")

        model.markDone(bins.id)
        let after = try #require(ReminderDetails(engine: model.engine, id: bins.id))
        #expect(after.status == .closed(.done))
        #expect(!after.offersDone)
    }

    /// Criterion 2: Pause on a Nudging reminder closes its occurrence as Skipped, not Missed. The
    /// hero says Paused, and the Schedule's last occurrence says how and when it closed.
    @Test func pausingANudgingReminderShowsItsOccurrenceAsSkipped() async throws {
        let model = try await launchedModel()
        model.add(bins)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        await model.appOpened()

        clock.now = NewYork.local(2026, 10, 16, 9, 40)
        model.pause(bins.id)

        let details = try #require(ReminderDetails(engine: model.engine, id: bins.id))
        #expect(details.status == .paused)
        #expect(details.lastOccurrence?.state == .skipped(reason: .paused))
        #expect(details.lastOccurrence?.day == "Today")
        #expect(details.lastOccurrence?.time == "9:40\u{202F}AM")
        #expect(!details.offersDone)
    }

    /// Criterion 2, the second half: Resume returns the reminder at its next future time, and the
    /// morning it was paused through stays Skipped. Next reads Paused while it is paused.
    @Test func resumingBringsTheReminderBackAtItsNextFutureTime() async throws {
        let model = try await launchedModel()
        model.add(meds)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        await model.appOpened()
        model.pause(meds.id)
        let paused = try #require(ReminderDetails(engine: model.engine, id: meds.id))
        #expect(paused.next == .paused)
        #expect(paused.pauseAction == .resume)

        clock.now = NewYork.local(2026, 10, 16, 10)
        try model.resume(meds.id)

        let resumed = try #require(ReminderDetails(engine: model.engine, id: meds.id))
        #expect(resumed.status == .comingUp)
        #expect(resumed.next == .at(day: "Tomorrow", time: "8:00\u{202F}AM"))
        #expect(resumed.pauseAction == .pause)
        #expect(resumed.lastOccurrence?.state == .skipped(reason: .paused))
    }

    /// A one-off that came due while it was paused has no future time to resume at. Resume is
    /// turned down, the reminder stays paused, and the screen sends the person to Edit.
    @Test func resumingAOneOffWithNoTimeLeftIsTurnedDownAndStaysPaused() async throws {
        let model = try await launchedModel()
        model.add(bins)
        model.pause(bins.id)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        await model.appOpened()

        #expect(throws: ResumeError.needsNewDueTime) { try model.resume(bins.id) }

        let details = try #require(ReminderDetails(engine: model.engine, id: bins.id))
        #expect(details.status == .paused)
        #expect(details.pauseAction == .resume)
        #expect(details.lastOccurrence?.state == .skipped(reason: .paused))
    }

    /// Criterion 3: the Schedule section ends with the lock note while the reminder is nudging,
    /// and only then, as the engine's lock says. Edit itself is always there.
    @Test func theLockNoteShowsOnlyWhileTheReminderIsNudging() async throws {
        let model = try await launchedModel()
        model.add(bins)
        #expect(try #require(ReminderDetails(engine: model.engine, id: bins.id)).showsLockNote == false)

        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        await model.appOpened()
        #expect(try #require(ReminderDetails(engine: model.engine, id: bins.id)).showsLockNote)

        model.pause(bins.id)
        #expect(try #require(ReminderDetails(engine: model.engine, id: bins.id)).showsLockNote == false)
    }

    /// Criterion 4: a custom repeat reads as the engine's plain-language summary, a preset and
    /// Never likewise. The wording itself is pinned in the engine's `RepeatSummaryTests`.
    @Test func aCustomRepeatShowsItsPlainLanguageSummary() async throws {
        let model = try await launchedModel()
        let custom = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 19, 9),
                              repeatRule: try RepeatRule(rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=5"), strength: .gentle)
        model.add(custom)
        model.add(bins)

        let details = try #require(ReminderDetails(engine: model.engine, id: custom.id))

        #expect(details.repeats == "Every 2 weeks on Monday and Wednesday at 9:00\u{202F}AM, 5 times")
        #expect(try #require(ReminderDetails(engine: model.engine, id: bins.id)).repeats == "Once, Today at 9:00\u{202F}AM")
    }

    /// Criterion 5, Confirm: Delete removes the reminder and everything pending for it, from the
    /// engine, the notification center, the alarms and the store. (Cancel never reaches the
    /// model: the dialog is a device check.)
    @Test func deleteRemovesTheReminderAndItsPendingItems() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = try await launchedModel(store: store)
        model.add(bins)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        await model.appOpened()
        await model.waitUntilApplied()
        #expect(!center.pending.isEmpty)
        #expect(!manager.scheduled.isEmpty)

        model.delete(bins.id)
        await model.waitUntilApplied()

        #expect(ReminderDetails(engine: model.engine, id: bins.id) == nil)
        #expect(center.pending.isEmpty)
        #expect(manager.scheduled.isEmpty)
        #expect(try store.load().reminders.isEmpty)
    }

    /// Criterion 7: notes and tags are in the app and nowhere in a notification or an alarm. Every
    /// field of every pending request, and everything an alarm carries, is searched for them.
    @Test(arguments: ["Green one too", "Garden"])
    func notesAndTagsAreNotInAnyNotificationOrAlarm(secret: String) async throws {
        let model = try await launchedModel()
        let garden = try #require(try model.createTag(named: "Garden"))
        var reminder = bins
        reminder.notes = "Green one too"
        reminder.tagIDs = [garden.id]
        model.add(reminder)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        await model.appOpened()
        await model.waitUntilApplied()
        #expect(!center.pending.isEmpty)
        #expect(!manager.scheduled.isEmpty)

        let notifications = center.pending.map { String(describing: [$0.content.title, $0.content.subtitle, $0.content.body] as [Any] + [$0.content.userInfo]) }
        let alarms = manager.scheduled.map { String(describing: $0.attributes) }

        #expect(!(notifications + alarms).contains { $0.localizedCaseInsensitiveContains(secret) })
        // The searches can find what is there: the title is.
        #expect(notifications.allSatisfy { $0.contains("Take the bins out") })
        #expect(alarms.allSatisfy { $0.contains("Take the bins out") })
    }

    /// The tags as VoiceOver reads them: a list in the engine's words, not commas glued on.
    @Test func theTagsReadToVoiceOverAsAList() async throws {
        let model = try await launchedModel()
        let home = try #require(try model.createTag(named: "home"))
        let weekly = try #require(try model.createTag(named: "weekly"))
        var tagged = bins
        tagged.tagIDs = [home.id, weekly.id]
        model.add(tagged)

        let details = try #require(ReminderDetails(engine: model.engine, id: bins.id))

        #expect(String(localized: try #require(details.tagsVoiceOverLabel)) == "Tags: #home and #weekly")
        model.add(meds)
        #expect(try #require(ReminderDetails(engine: model.engine, id: meds.id)).tagsVoiceOverLabel == nil)
    }

    /// A one-off paused before it was due comes back at that time: Resume has a future time to
    /// return it at, so it isn't turned down.
    @Test func resumingAOneOffPausedBeforeItWasDueReturnsItAtItsTime() async throws {
        let model = try await launchedModel()
        model.add(bins)
        model.pause(bins.id)
        try model.resume(bins.id)

        let details = try #require(ReminderDetails(engine: model.engine, id: bins.id))

        #expect(details.status == .comingUp)
        #expect(details.next == .at(day: "Today", time: "9:00\u{202F}AM"))
        #expect(details.pauseAction == .pause)
    }

    /// While a repeating reminder is nudging, Next is its following due time, not the one that is
    /// open now.
    @Test func whileNudgingNextIsTheFollowingDueTime() async throws {
        let model = try await launchedModel()
        model.add(meds)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        await model.appOpened()

        let details = try #require(ReminderDetails(engine: model.engine, id: meds.id))

        #expect(details.status == .nudging)
        #expect(details.next == .at(day: "Tomorrow", time: "8:00\u{202F}AM"))
        #expect(details.pauseAction == .pause)
    }

    /// A one-off that has closed has nothing left to pause, and its status is how it closed.
    @Test func aFinishedReminderOffersNoPauseAndSaysHowItClosed() async throws {
        let model = try await launchedModel()
        model.add(bins)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        await model.appOpened()
        // Gentle's give-up span, from the due time at 9:00, is long past by the next morning.
        clock.now = NewYork.local(2026, 10, 17, 12)
        await model.appOpened()

        let details = try #require(ReminderDetails(engine: model.engine, id: bins.id))

        #expect(details.status == .closed(.missed(reason: .giveUpLimit)))
        #expect(details.pauseAction == nil)
        #expect(details.next == .none)
        #expect(details.lastOccurrence?.state == .missed(reason: .giveUpLimit))
    }

    /// A reminder paused through its due time closes as Skipped, and with no later time the hero
    /// says how it closed only once it is no longer paused; while paused it says Paused.
    @Test func aPausedOneOffWhoseTimePassedStillSaysPaused() async throws {
        let model = try await launchedModel()
        model.add(bins)
        model.pause(bins.id)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        await model.appOpened()

        let details = try #require(ReminderDetails(engine: model.engine, id: bins.id))

        #expect(details.status == .paused)
        #expect(details.lastOccurrence?.state == .skipped(reason: .paused))
    }

    /// Edit's Save after Resume was turned down for want of a time: a new time resumes the
    /// reminder at once.
    @Test func anEditThatChoseANewTimeResumesTheReminder() async throws {
        let model = try await launchedModel()
        model.add(bins)
        model.pause(bins.id)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        await model.appOpened()
        let before = try #require(model.engine.reminders.first)
        var edited = before
        edited.dueTime = NewYork.local(2026, 10, 16, 12)
        try model.edit(edited)

        #expect(model.resumeAfterEdit(of: before) == .resumed)

        let details = try #require(ReminderDetails(engine: model.engine, id: bins.id))
        #expect(details.status == .comingUp)
        #expect(details.next == .at(day: "Today", time: "12:00\u{202F}PM"))
    }

    /// A Save that left the time alone, a new title say, still has no time to resume at: the
    /// screen is told, so it asks again rather than staying paused in silence.
    @Test func anEditThatLeftNoTimeStillNeedsOne() async throws {
        let model = try await launchedModel()
        model.add(bins)
        model.pause(bins.id)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        await model.appOpened()
        let before = try #require(model.engine.reminders.first)
        var renamed = before
        renamed.title = "Bins"
        try model.edit(renamed)

        #expect(model.resumeAfterEdit(of: before) == .needsNewDueTime)

        #expect(try #require(ReminderDetails(engine: model.engine, id: bins.id)).status == .paused)
    }

    /// Cancel left the reminder as it was, so there is nothing to resume or to say.
    @Test func aCancelledEditChangesNothing() async throws {
        let model = try await launchedModel()
        model.add(bins)
        model.pause(bins.id)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        await model.appOpened()
        let before = try #require(model.engine.reminders.first)

        #expect(model.resumeAfterEdit(of: before) == .unchanged)

        #expect(try #require(ReminderDetails(engine: model.engine, id: bins.id)).status == .paused)
    }
}
