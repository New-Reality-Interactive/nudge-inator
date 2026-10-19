import Foundation
import NudgeEngine
import Observation
import Synchronization
import Testing
@testable import NudgeInator

/// The New and Edit Reminder form through its draft, `ReminderForm`, saving through the real app
/// model (in-memory store, real adapters over the fakes). Tests assert on what the form says
/// blocks a save and on the engine's read-outs after it. Layout, VoiceOver, Dynamic Type and the
/// keyboard are screenshot and device checks.
@MainActor
struct ReminderFormTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let center = FakeNotificationCenter()
    let manager = FakeAlarmManager()

    func launchedModel() async throws -> AppModel {
        let store = try ReminderStore(location: .inMemory)
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

    func newForm(on model: AppModel) -> ReminderForm {
        ReminderForm(engine: { model.engine }, now: { [clock] in clock.now })
    }

    func editForm(of reminderID: Reminder.ID, on model: AppModel) throws -> ReminderForm {
        let form = ReminderForm(engine: { model.engine }, editing: reminderID, now: { [clock] in clock.now })
        return try #require(form)
    }

    /// Due at 7:30 and Firm, so at 8:00 it is Nudging.
    let bins = Reminder(title: "Take the bins out", dueTime: NewYork.local(2026, 10, 15, 7, 30), strength: .firm)

    /// The form's How It Nudges and the line under the strength (ticket 31) follow the draft's
    /// strength and switch, from the engine. Firm waits 30 min, then 15 and 7.5, then its 5 min
    /// floor; Gentle waits an hour, easing to 20 min.
    @Test(arguments: [
        (Strength.firm, true, StrengthBlurb(firstWait: 30 * 60, floor: 5 * 60, firstAlarm: 4)),
        (.firm, false, StrengthBlurb(firstWait: 30 * 60, floor: 5 * 60, firstAlarm: nil)),
        (.gentle, true, StrengthBlurb(firstWait: 60 * 60, floor: 20 * 60, firstAlarm: nil)),
        (.relentless, true, StrengthBlurb(firstWait: 10 * 60, floor: 2 * 60, firstAlarm: 4)),
    ])
    func theStrengthsLineAndHowItNudgesFollowTheDraft(strength: Strength, breakThroughFocus: Bool, blurb: StrengthBlurb) async throws {
        manager.authorizationState = .authorized
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.strength = strength
        form.breakThroughFocus = breakThroughFocus

        #expect(form.strengthBlurb == blurb)
        #expect(form.howItNudges.nudgeCount == 20)
        #expect(form.howItNudges.rows.contains { $0.delivery == .alarm } == (blurb.firstAlarm != nil))
    }

    @Test(arguments: ["", "   ", "\n"])
    func aReminderWithNoTitleCantBeSaved(title: String) async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = title

        #expect(form.saveBlock == .noTitle)
        #expect(form.save(to: model) == false)
        #expect(model.engine.reminders.isEmpty)
    }

    @Test func aNewReminderWithTagsRelentlessAndBreakThroughFocusIsSavedAndComingUp() async throws {
        let model = try await launchedModel()
        let home = try #require(try model.createTag(named: "home"))
        let money = try #require(try model.createTag(named: "money"))
        let form = newForm(on: model)
        form.title = "Pay the rent"
        form.notes = "Online, before noon"
        form.tagIDs = [home.id, money.id]
        form.dueTime = NewYork.local(2026, 10, 16, 9)
        form.strength = .relentless
        form.breakThroughFocus = true

        #expect(form.save(to: model))

        let saved = try #require(model.engine.reminders.only)
        #expect(saved.title == "Pay the rent")
        #expect(saved.notes == "Online, before noon")
        #expect(saved.tagIDs == [home.id, money.id])
        #expect(saved.dueTime == NewYork.local(2026, 10, 16, 9))
        #expect(saved.repeatRule == nil)
        #expect(saved.strength == .relentless)
        #expect(saved.breakThroughFocus)
        #expect(model.engine.comingUp().map(\.reminderID) == [saved.id])
    }

    @Test(arguments: ["Home", "#home", " HOME "])
    func typingAnExistingTagsNameAttachesThatTag(typed: String) async throws {
        let model = try await launchedModel()
        let home = try #require(try model.createTag(named: "home"))
        let form = newForm(on: model)
        form.title = "Water the plants"

        form.addTag(named: typed)

        #expect(form.tagIDs == [home.id])
        #expect(form.save(to: model))
        #expect(model.engine.tags == [home])
        #expect(model.engine.reminders.only?.tagIDs == [home.id])
    }

    @Test func aNewTagIsCreatedWhenTheReminderIsSavedWithIt() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Buy stamps"

        form.addTag(named: "errands")
        form.addTag(named: "Errands")

        #expect(form.tags.map(\.name) == ["errands"])
        #expect(form.tagIDs.count == 1)
        #expect(model.engine.tags.isEmpty)
        #expect(form.save(to: model))
        let errands = try #require(model.engine.tags.only)
        #expect(errands.name == "errands")
        #expect(model.engine.reminders.only?.tagIDs == [errands.id])
    }

    @Test func aNewTagThatIsNoLongerChosenIsNotCreated() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Buy stamps"
        form.addTag(named: "errands")
        let errands = try #require(form.tags.only)

        form.toggleTag(errands.id)

        #expect(form.tagIDs.isEmpty)
        #expect(form.save(to: model))
        #expect(model.engine.tags.isEmpty)
        #expect(model.engine.reminders.only?.tagIDs == [])
    }

    @Test func editingANudgingReminderLocksItsScheduleButSavesTitleNotesAndTags() async throws {
        let model = try await launchedModel()
        model.add(bins)
        let form = try editForm(of: bins.id, on: model)

        #expect(form.lockedFields == [.dueTime, .repeatRule, .strength, .breakThroughFocus])
        form.title = "Take both bins out"
        form.notes = "Recycling too"
        form.addTag(named: "home")

        #expect(form.save(to: model))
        let saved = try #require(model.engine.reminders.only)
        #expect(saved.id == bins.id)
        #expect(saved.title == "Take both bins out")
        #expect(saved.notes == "Recycling too")
        #expect(saved.tagIDs == model.engine.tags.map(\.id))
        #expect(saved.dueTime == bins.dueTime)
        #expect(saved.strength == .firm)
        #expect(model.engine.openOccurrence(for: bins.id) != nil)
    }

    enum NotNudging: CaseIterable {
        case paused, finished, notYetDue
    }

    @Test(arguments: NotNudging.allCases)
    func editingAReminderThatIsntNudgingLocksNothing(_ state: NotNudging) async throws {
        let model = try await launchedModel()
        switch state {
        case .paused:
            model.add(bins)
            model.pause(bins.id)
        case .finished:
            model.add(bins)
            model.markDone(bins.id)
        case .notYetDue:
            model.add(Reminder(id: bins.id, title: bins.title, dueTime: NewYork.local(2026, 10, 15, 9), strength: .firm))
        }
        let form = try editForm(of: bins.id, on: model)

        #expect(form.lockedFields.isEmpty)
        form.strength = .relentless
        #expect(form.save(to: model))
        #expect(model.engine.reminders.only?.strength == .relentless)
    }

    /// Device check, ticket 27: a form open on a reminder that falls due kept showing its fields
    /// editable, because nothing told its views to read the lock again as the clock passed the
    /// due time. Checking the clock does: what a view read from `lockedFields` is invalidated.
    @Test func checkingTheClockMakesViewsReadTheLockAgain() async throws {
        let model = try await launchedModel()
        let later = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 9), strength: .firm)
        model.add(later)
        let form = try editForm(of: later.id, on: model)
        let viewsMustReadAgain = Mutex(false)
        withObservationTracking {
            _ = form.lockedFields
        } onChange: {
            viewsMustReadAgain.withLock { $0 = true }
        }

        clock.now = NewYork.local(2026, 10, 15, 9)
        form.checkLock()

        #expect(viewsMustReadAgain.withLock { $0 })
        #expect(form.lockedFields == Set(LockedField.allCases))
    }

    /// Device check, ticket 27 (the user's ruling): when the lock arrives while the form is open,
    /// the locked fields go back to their saved values at once, so the screen shows only what a
    /// Save can keep, and the first Save works. A title being typed is kept: it isn't locked.
    @Test func aLockArrivingRestoresTheLockedFieldsToTheirSavedValues() async throws {
        let model = try await launchedModel()
        let saved = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 9), repeatRule: .everyDay, strength: .firm)
        model.add(saved)
        let form = try editForm(of: saved.id, on: model)
        form.title = "Call the bank about the card"
        form.strength = .relentless
        form.breakThroughFocus = false
        form.dueTime = NewYork.local(2026, 10, 15, 11)
        form.customChoices.interval = 3

        clock.now = NewYork.local(2026, 10, 15, 9, 5)
        form.checkLock()

        #expect(form.strength == .firm)
        #expect(form.breakThroughFocus)
        #expect(form.dueTime == saved.dueTime)
        #expect(form.repeatPreset == .everyDay)
        #expect(form.repeatRule == .everyDay)
        #expect(form.title == "Call the bank about the card")
        // Nothing is left for the lock to turn down, so the first Save works.
        #expect(form.save(to: model))
        #expect(model.engine.reminders.only?.title == "Call the bank about the card")
        #expect(model.engine.reminders.only?.strength == .firm)
    }

    /// A custom repeat the reminder had when the form opened is what comes back, not a default.
    @Test func aLockArrivingRestoresASavedCustomRepeat() async throws {
        let model = try await launchedModel()
        let everyThreeDays = try #require(RepeatRule(frequency: .daily, interval: 3))
        let saved = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 9), repeatRule: everyThreeDays, strength: .gentle)
        model.add(saved)
        let form = try editForm(of: saved.id, on: model)
        form.customChoices.interval = 5

        clock.now = NewYork.local(2026, 10, 15, 9, 5)
        form.checkLock()

        #expect(form.repeatRule == everyThreeDays)
        #expect(form.customChoices.interval == 3)
    }

    /// Nothing is locked yet, so checking the clock leaves the person's changes alone.
    @Test func checkingTheClockBeforeTheLockLeavesChangesAlone() async throws {
        let model = try await launchedModel()
        let saved = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 9), strength: .firm)
        model.add(saved)
        let form = try editForm(of: saved.id, on: model)
        form.strength = .relentless

        form.checkLock()

        #expect(form.strength == .relentless)
    }

    @Test func aSaveAfterTheReminderStartedNudgingIsTurnedDownAndTheFormLocks() async throws {
        let model = try await launchedModel()
        let later = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 9), strength: .firm)
        model.add(later)
        let form = try editForm(of: later.id, on: model)
        #expect(form.lockedFields.isEmpty)

        clock.now = NewYork.local(2026, 10, 15, 9, 5)
        form.strength = .relentless

        #expect(form.save(to: model) == false)
        #expect(form.lockedFields == Set(LockedField.allCases))
        #expect(form.strength == .firm)
        #expect(model.engine.reminders == [later])

        // The locked fields are back as saved, so the title can still be saved.
        form.title = "Call the bank about the card"
        #expect(form.save(to: model))
        #expect(model.engine.reminders.only?.title == "Call the bank about the card")
    }

    @Test(arguments: [
        (RepeatPreset.never, nil),
        (.everyDay, RepeatRule.everyDay),
        (.everyWeekday, .everyWeekday),
        (.everyWeek, .everyWeek),
        (.everyTwoWeeks, .everyTwoWeeks),
        (.everyMonth, .everyMonth),
        (.everyYear, .everyYear),
    ] as [(RepeatPreset, RepeatRule?)])
    func eachRepeatPresetSavesTheEnginesRule(preset: RepeatPreset, rule: RepeatRule?) async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Stretch"
        form.dueTime = NewYork.local(2026, 10, 15, 9)

        form.repeatPreset = preset

        #expect(form.repeatPreset == preset)
        #expect(form.save(to: model))
        #expect(model.engine.reminders.only?.repeatRule == rule)
    }

    @Test func aCustomRuleReadsAsCustomWithItsSummaryUntilAPresetReplacesIt() async throws {
        let model = try await launchedModel()
        let everyThreeDays = try #require(RepeatRule(frequency: .daily, interval: 3))
        let water = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 9), repeatRule: everyThreeDays, strength: .gentle)
        model.add(water)
        let form = try editForm(of: water.id, on: model)

        #expect(form.repeatPreset == nil)
        // The engine's own summary: its wording is pinned in RepeatSummaryTests, in a fixed locale.
        #expect(form.repeatSummary == model.engine.repeatSummary(of: water))

        form.repeatPreset = .everyDay
        var daily = water
        daily.repeatRule = .everyDay
        #expect(form.repeatSummary == model.engine.repeatSummary(of: daily))
        #expect(form.repeatSummary != model.engine.repeatSummary(of: water))
        #expect(form.save(to: model))
        #expect(model.engine.reminders.only?.repeatRule == .everyDay)
    }

    @Test func aNewOneOffAtATimeThatHasPassedCantBeSaved() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Feed the cat"
        form.dueTime = NewYork.local(2026, 10, 15, 7)

        #expect(form.saveBlock == .pastTime)
        #expect(form.save(to: model) == false)
        #expect(model.engine.reminders.isEmpty)
    }

    /// Ticket 13: a repeat whose start has passed would open an occurrence at once and nudge.
    @Test func aRepeatCantStartAtATimeThatHasPassedUnlessItKeepsItsSavedStart() async throws {
        let model = try await launchedModel()
        let new = newForm(on: model)
        new.title = "Stretch"
        new.repeatPreset = .everyDay
        new.dueTime = NewYork.local(2026, 10, 15, 7)
        #expect(new.saveBlock == .pastTime)

        let stretch = Reminder(title: "Stretch", dueTime: NewYork.local(2026, 10, 1, 9), repeatRule: .everyWeek, strength: .gentle)
        model.add(stretch)
        let edit = try editForm(of: stretch.id, on: model)
        edit.title = "Stretch for ten minutes"
        #expect(edit.saveBlock == nil)
        edit.dueTime = NewYork.local(2026, 10, 15, 7, 30)
        #expect(edit.saveBlock == .pastTime)
    }

    @Test func aOneOffThatKeepsItsPassedTimeCanBeRenamedButNotMovedToAnotherPassedTime() async throws {
        let model = try await launchedModel()
        model.add(bins)
        model.markDone(bins.id)
        let form = try editForm(of: bins.id, on: model)

        form.title = "Took the bins out"
        #expect(form.saveBlock == nil)

        form.dueTime = NewYork.local(2026, 10, 15, 7, 45)
        #expect(form.saveBlock == .pastTime)

        // The picker shows minutes, so the same minute is the same start.
        form.dueTime = NewYork.local(2026, 10, 15, 7, 30, 40)
        #expect(form.saveBlock == nil)
    }

    @Test(arguments: [
        (NewYork.local(2026, 10, 15, 8), NewYork.local(2026, 10, 15, 9)),
        (NewYork.local(2026, 10, 15, 8, 20), NewYork.local(2026, 10, 15, 9)),
        (NewYork.local(2026, 10, 15, 23, 59, 30), NewYork.local(2026, 10, 16, 0)),
    ])
    func aNewReminderStartsAtTheNextWholeHourFirmWithBreakThroughFocusOn(now: Date, start: Date) async throws {
        let model = try await launchedModel()
        clock.now = now
        let form = newForm(on: model)

        #expect(form.dueTime == start)
        #expect(form.repeatPreset == .never)
        #expect(form.strength == .firm)
        #expect(form.breakThroughFocus)
        #expect(form.lockedFields.isEmpty)
    }

    @Test func aFormHasChangesOnlyWhileItDiffersFromWhatItOpenedWith() async throws {
        let model = try await launchedModel()
        model.add(bins)
        let new = newForm(on: model)
        let edit = try editForm(of: bins.id, on: model)
        #expect(!new.hasChanges)
        #expect(!edit.hasChanges)

        new.title = "Feed the cat"
        edit.notes = "Recycling too"
        #expect(new.hasChanges)
        #expect(edit.hasChanges)

        edit.notes = ""
        #expect(!edit.hasChanges)
        edit.addTag(named: "home")
        #expect(edit.hasChanges)
    }

    @Test func theTitleAndNotesAreSavedWithoutSpaceAroundThem() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "  Feed the cat \n"
        form.notes = "\nHalf a pouch  "

        #expect(form.save(to: model))
        #expect(model.engine.reminders.only?.title == "Feed the cat")
        #expect(model.engine.reminders.only?.notes == "Half a pouch")
    }

    @Test func theTagsRowListsTheChosenTagsAsHashNamesInTheOrderChosen() async throws {
        let model = try await launchedModel()
        let home = try #require(try model.createTag(named: "home"))
        let form = newForm(on: model)
        #expect(form.chosenTagsText == nil)

        form.addTag(named: "errands")
        form.toggleTag(home.id)

        #expect(form.chosenTagsText == "#errands #home")
    }

    @Test func aSaveTurnedDownByTheLockCreatesNoTag() async throws {
        let model = try await launchedModel()
        let later = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 9), strength: .firm)
        model.add(later)
        let form = try editForm(of: later.id, on: model)
        form.addTag(named: "money")
        form.strength = .relentless
        clock.now = NewYork.local(2026, 10, 15, 9, 5)

        #expect(form.save(to: model) == false)
        #expect(model.engine.tags.isEmpty)
    }

    @Test func theLockLiftsWhenTheReminderIsMarkedDoneWhileTheFormIsOpen() async throws {
        let model = try await launchedModel()
        model.add(bins)
        let form = try editForm(of: bins.id, on: model)
        #expect(!form.lockedFields.isEmpty)

        model.markDone(bins.id)

        #expect(form.lockedFields.isEmpty)
    }

    @Test func aTitleWithLineBreaksIsSavedOnOneLine() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Buy\nmilk\r\nand eggs"

        #expect(form.save(to: model))
        #expect(model.engine.reminders.only?.title == "Buy milk and eggs")
    }

    @Test func savingTwiceAddsTheReminderOnce() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Feed the cat"

        #expect(form.save(to: model))
        #expect(form.save(to: model) == false)
        #expect(model.engine.reminders.count == 1)
    }

    /// Monday 19 October 2026 at 9:00, after the clock's 15 October.
    static let monday = NewYork.local(2026, 10, 19)

    @Test func choosingCustomAfterAPresetStartsFromThatPreset() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = Self.monday
        form.repeatPreset = .everyTwoWeeks

        form.customRepeat = form.customChoices

        #expect(form.repeatPreset == nil)
        #expect(form.customRepeat == model.engine.customRepeat(from: .everyTwoWeeks, startingAt: Self.monday))
        #expect(form.repeatRule?.rrule == "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO")
    }

    /// Device check, ticket 27: looking at the Custom page changed the Repeat page and the form to
    /// Custom, though the rule hadn't changed, even on a locked reminder. The page shows its
    /// starting choices without storing them, so looking changes nothing.
    @Test func lookingAtTheCustomPageChangesNothing() async throws {
        let model = try await launchedModel()
        let daily = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 9), repeatRule: .everyDay, strength: .gentle)
        model.add(daily)
        let form = try editForm(of: daily.id, on: model)

        let shown = form.customChoices

        #expect(shown == model.engine.customRepeat(from: .everyDay, startingAt: daily.dueTime))
        #expect(form.customRepeat == nil)
        #expect(form.repeatPreset == .everyDay)
        #expect(form.repeatRule == .everyDay)
        #expect(!form.hasChanges)
    }

    /// A new reminder that was Never is still Never: the page's starting choices aren't a choice.
    /// Its header and Next Times describe the choices it shows, not the one-off it still is.
    @Test func lookingAtTheCustomPageKeepsNeverAndDescribesTheChoicesShown() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = Self.monday

        // Never starts the page from a weekly repeat on the start's weekday (the mockup's `customFrom`).
        #expect(form.customPageSummary == "Every Monday at 9:00\u{202F}AM")
        #expect(form.customPageUpcomingDueTimes == [Self.monday, NewYork.local(2026, 10, 26), NewYork.local(2026, 11, 2)])
        #expect(form.repeatPreset == .never)
        #expect(form.repeatRule == nil)
        #expect(form.customRepeat == nil)
    }

    /// The first choice made on the page stores the choices: that is a change, and the repeat is
    /// then Custom.
    @Test func aChoiceOnTheCustomPageMakesTheRepeatCustom() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = Self.monday
        form.repeatPreset = .everyDay

        form.customChoices.interval = 3

        #expect(form.repeatPreset == nil)
        #expect(form.repeatRule?.rrule == "FREQ=DAILY;INTERVAL=3")
        #expect(form.customChoices.interval == 3)
    }

    /// Storing the choices a preset starts the page from, as the first control tap does, must not
    /// change when the reminder falls due. The rule may be written differently (a weekly rule
    /// names its weekday), but the times are the same. Never is left out: it starts a weekly page.
    @Test(arguments: RepeatPreset.allCases.filter { $0 != .never })
    func storingAPresetsStartingChoicesKeepsItsDueTimes(preset: RepeatPreset) async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = Self.monday
        form.repeatPreset = preset
        let before = form.upcomingDueTimes

        form.customChoices = form.customChoices

        #expect(form.upcomingDueTimes == before)
    }

    /// Accepted (ticket 25): Every Month from the 31st uses the last day of a short month, but the
    /// Custom page's "On the 31st" skips it, and says so in its footer. A control tap stores that.
    @Test func storingEveryMonthsChoicesFromThe31stSkipsTheShortMonths() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = NewYork.local(2026, 10, 31)
        form.repeatPreset = .everyMonth
        #expect(form.upcomingDueTimes.prefix(2).last == NewYork.local(2026, 11, 30))

        form.customChoices = form.customChoices

        #expect(form.upcomingDueTimes.prefix(2).last == NewYork.local(2026, 12, 31))
    }

    /// A reminder with a custom repeat already shows it, and nothing is seeded over it.
    @Test func theCustomPageShowsAnExistingCustomRepeat() async throws {
        let model = try await launchedModel()
        let custom = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 16, 9),
                              repeatRule: try #require(RepeatRule(frequency: .daily, interval: 3)), strength: .gentle)
        model.add(custom)
        let form = try editForm(of: custom.id, on: model)

        #expect(form.customChoices.interval == 3)
        #expect(form.repeatPreset == nil)
        #expect(form.repeatRule == custom.repeatRule)
    }

    /// Every 2 weeks from Monday 19 October skips the week of the 26th.
    @Test func theCustomPagesChoicesUpdateTheSummaryAndTheNextTimes() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Water the plants"
        form.dueTime = Self.monday
        form.repeatPreset = .everyTwoWeeks

        form.customChoices.toggle(.wednesday)
        #expect(form.upcomingDueTimes == [Self.monday, NewYork.local(2026, 10, 21), NewYork.local(2026, 11, 2)])

        form.customChoices.ending = .afterCount
        form.customChoices.count = 2
        #expect(form.upcomingDueTimes == [Self.monday, NewYork.local(2026, 10, 21)])
        let expected = Reminder(title: "Water the plants", dueTime: Self.monday,
                                repeatRule: try RepeatRule(rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=2"), strength: .firm)
        #expect(form.repeatSummary == model.engine.repeatSummary(of: expected))
        #expect(form.upcomingDueTimes == model.engine.upcomingDueTimes(of: expected, count: 3))
    }

    /// Wednesday 28 October is October's last Wednesday; 18 November isn't November's.
    @Test func aMonthlyChoiceANewStartDoesntOfferFallsBackToItsDayOfTheMonth() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = NewYork.local(2026, 10, 28)
        form.repeatPreset = .everyMonth
        form.customChoices.monthlyDay = .lastWeekdayOfMonth
        #expect(form.repeatRule?.rrule == "FREQ=MONTHLY;BYDAY=-1WE")

        form.dueTime = NewYork.local(2026, 11, 18)

        #expect(form.repeatRule?.rrule == "FREQ=MONTHLY;BYMONTHDAY=18")
    }

    @Test func aCustomRepeatThatEndsBeforeItStartsCantBeSaved() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Water the plants"
        form.dueTime = Self.monday
        form.customChoices.ending = .onDate
        form.customChoices.endDate = NewYork.local(2026, 10, 18)

        #expect(form.repeatBlock == .endsBeforeStart)
        #expect(form.saveBlock == .endsBeforeStart)
        #expect(form.save(to: model) == false)

        form.customChoices.endDate = Self.monday
        #expect(form.saveBlock == nil)
        #expect(form.save(to: model))
    }

    /// Daily from 1 October, three times, so it ended on the 3rd. Kept as it was, it can still be
    /// renamed, as a kept start can (decision 4, ticket 25).
    @Test func aChangedCustomRepeatWithNoTimesLeftCantBeSaved() async throws {
        let model = try await launchedModel()
        let ended = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 1, 9),
                             repeatRule: try RepeatRule(rrule: "FREQ=DAILY;COUNT=3"), strength: .gentle)
        model.add(ended)
        let form = try editForm(of: ended.id, on: model)
        #expect(form.upcomingDueTimes.isEmpty)
        #expect(form.saveBlock == nil)

        form.customChoices.count = 5
        #expect(form.repeatBlock == .noTimesLeft)
        #expect(form.saveBlock == .noTimesLeft)

        form.customChoices.count = 30
        #expect(form.saveBlock == nil)
        form.title = "Water the ferns"
        #expect(form.save(to: model))
    }

    @Test func aSavedCustomRepeatReopensWithItsChoicesAndAPresetReplacesIt() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Pay the cleaner"
        form.dueTime = NewYork.local(2026, 10, 28)
        form.customChoices.frequency = .monthly
        form.customChoices.monthlyDay = .lastWeekdayOfMonth
        form.customChoices.ending = .afterCount
        form.customChoices.count = 5
        #expect(form.save(to: model))
        let saved = try #require(model.engine.reminders.only)
        #expect(saved.repeatRule?.rrule == "FREQ=MONTHLY;BYDAY=-1WE;COUNT=5")

        let edit = try editForm(of: saved.id, on: model)
        #expect(edit.repeatPreset == nil)
        #expect(edit.customRepeat?.frequency == .monthly)
        #expect(edit.customRepeat?.monthlyDay == .lastWeekdayOfMonth)
        #expect(edit.customRepeat?.ending == .afterCount)
        #expect(edit.customRepeat?.count == 5)
        #expect(edit.hasChanges == false)

        edit.repeatPreset = .everyWeek
        #expect(edit.customRepeat == nil)
        #expect(edit.save(to: model))
        #expect(model.engine.reminders.only?.repeatRule == .everyWeek)
    }

    /// Decision 5, ticket 25: the page shows what it can of a rule it has no controls for, and
    /// the rule stays as saved until a choice or the start changes.
    @Test func aRuleThePageCantShowIsKeptUntilAChoiceChanges() async throws {
        let model = try await launchedModel()
        let summer = Reminder(title: "Water the lawn", dueTime: Self.monday,
                              repeatRule: try RepeatRule(rrule: "FREQ=WEEKLY;BYDAY=MO;BYMONTH=6,7;COUNT=50"), strength: .gentle)
        model.add(summer)
        let form = try editForm(of: summer.id, on: model)
        #expect(form.repeatRule == summer.repeatRule)
        #expect(form.hasChanges == false)

        form.title = "Water the grass"
        #expect(form.save(to: model))
        #expect(model.engine.reminders.only?.repeatRule == summer.repeatRule)

        let again = try editForm(of: summer.id, on: model)
        again.customChoices.toggle(.friday)
        #expect(again.repeatRule?.rrule == "FREQ=WEEKLY;BYDAY=MO,FR;COUNT=30")
    }

    /// Each Custom page control, set through the form from Every Week on Wednesday 28 October.
    @Test(arguments: [
        ("daily every 3", "FREQ=DAILY;INTERVAL=3"),
        ("monthly last Wednesday", "FREQ=MONTHLY;BYDAY=-1WE"),
        ("monthly fourth Wednesday", "FREQ=MONTHLY;BYDAY=4WE"),
        ("monthly last day", "FREQ=MONTHLY;BYMONTHDAY=-1"),
        ("yearly every 2", "FREQ=YEARLY;INTERVAL=2;BYMONTH=10;BYMONTHDAY=28"),
        ("until 1 December", "FREQ=WEEKLY;BYDAY=WE;UNTIL=20261201"),
    ])
    func eachCustomPageControlBuildsItsRule(control: String, rrule: String) async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = NewYork.local(2026, 10, 28)
        form.repeatPreset = .everyWeek

        switch control {
        case "daily every 3":
            form.customChoices.frequency = .daily
            form.customChoices.interval = 3
        case "monthly last Wednesday":
            form.customChoices.frequency = .monthly
            form.customChoices.monthlyDay = .lastWeekdayOfMonth
        case "monthly fourth Wednesday":
            form.customChoices.frequency = .monthly
            form.customChoices.monthlyDay = .weekdayOfMonth
        case "monthly last day":
            form.customChoices.frequency = .monthly
            form.customChoices.monthlyDay = .lastDay
        case "yearly every 2":
            form.customChoices.frequency = .yearly
            form.customChoices.interval = 2
        default:
            form.customChoices.ending = .onDate
            form.customChoices.endDate = NewYork.local(2026, 12, 1, 0)
        }

        #expect(form.repeatRule?.rrule == rrule)
        #expect(form.repeatSummary == model.engine.repeatSummary(of: Reminder(
            title: "", dueTime: form.dueTime, repeatRule: try RepeatRule(rrule: rrule), strength: .firm)))
    }

    /// RFC 5545 counts the first due time, so moving the start to a day that isn't chosen adds
    /// that one day (ticket 09's decision), as Next Times shows.
    @Test func aWeeklyStartOnADayThatIsntChosenStillFallsDue() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = Self.monday
        form.repeatPreset = .everyWeek
        form.customRepeat = form.customChoices

        form.dueTime = NewYork.local(2026, 10, 20)

        #expect(form.upcomingDueTimes == [NewYork.local(2026, 10, 20), NewYork.local(2026, 10, 26), NewYork.local(2026, 11, 2)])
    }

    /// The clock is at 15 October 2026.
    @Test(arguments: [(NewYork.local(2026, 12, 31), false), (NewYork.local(2027, 1, 1), true)])
    func aNextTimeShowsItsYearOnlyWhenItIsntThisYear(dueTime: Date, showsYear: Bool) async throws {
        let model = try await launchedModel()

        #expect(newForm(on: model).showsYear(of: dueTime) == showsYear)
    }

    @Test func aFormOpenedFromATagStartsWithItChosenAndNoChanges() async throws {
        let model = try await launchedModel()
        let home = try #require(try model.createTag(named: "home"))
        let now = clock.now
        let form = ReminderForm(engine: { model.engine }, now: { now }, tagIDs: [home.id])
        let hasChanges = form.hasChanges
        form.title = "Water the plants"

        #expect(form.tagIDs == [home.id])
        #expect(!hasChanges)
        #expect(form.save(to: model))
        #expect(model.engine.reminders.first?.tagIDs == [home.id])
    }
}
