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

        form.chooseCustom()

        #expect(form.repeatPreset == nil)
        #expect(form.customRepeat == model.engine.customRepeat(from: .everyTwoWeeks, startingAt: Self.monday))
        #expect(form.repeatRule?.rrule == "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO")
    }

    /// Device check, ticket 27: looking at the Custom page changed the Repeat page and the form to
    /// Custom, though the rule hadn't changed, even on a locked reminder. Leaving it with the
    /// choices as they were seeded puts the draft back as it was.
    @Test func leavingTheCustomPageUnchangedLeavesTheRepeatAsItWas() async throws {
        let model = try await launchedModel()
        let daily = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 9), repeatRule: .everyDay, strength: .gentle)
        model.add(daily)
        let form = try editForm(of: daily.id, on: model)

        form.chooseCustom()
        form.leaveCustom()

        #expect(form.repeatPreset == .everyDay)
        #expect(form.repeatRule == .everyDay)
        #expect(form.customRepeat == nil)
        #expect(!form.hasChanges)
    }

    /// A new reminder that was Never is still Never: the page's starting choices aren't a choice.
    @Test func leavingTheCustomPageUnchangedKeepsNever() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)

        form.chooseCustom()
        form.leaveCustom()

        #expect(form.repeatPreset == .never)
        #expect(form.repeatRule == nil)
    }

    /// A choice made on the page is kept when the person leaves it: that is a change.
    @Test func leavingTheCustomPageAfterAChoiceKeepsTheCustomRepeat() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = Self.monday
        form.repeatPreset = .everyDay
        form.chooseCustom()
        form.customRepeat?.interval = 3

        form.leaveCustom()

        #expect(form.repeatPreset == nil)
        #expect(form.repeatRule?.rrule == "FREQ=DAILY;INTERVAL=3")
    }

    /// A reminder with a custom repeat already, reopened, keeps it: nothing was seeded to undo.
    @Test func leavingTheCustomPageOnAnExistingCustomRepeatKeepsIt() async throws {
        let model = try await launchedModel()
        let custom = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 16, 9),
                              repeatRule: try #require(RepeatRule(frequency: .daily, interval: 3)), strength: .gentle)
        model.add(custom)
        let form = try editForm(of: custom.id, on: model)

        form.chooseCustom()
        form.leaveCustom()

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
        form.chooseCustom()

        form.customRepeat?.toggle(.wednesday)
        #expect(form.upcomingDueTimes == [Self.monday, NewYork.local(2026, 10, 21), NewYork.local(2026, 11, 2)])

        form.customRepeat?.ending = .afterCount
        form.customRepeat?.count = 2
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
        form.chooseCustom()
        form.customRepeat?.monthlyDay = .lastWeekdayOfMonth
        #expect(form.repeatRule?.rrule == "FREQ=MONTHLY;BYDAY=-1WE")

        form.dueTime = NewYork.local(2026, 11, 18)

        #expect(form.repeatRule?.rrule == "FREQ=MONTHLY;BYMONTHDAY=18")
    }

    @Test func aCustomRepeatThatEndsBeforeItStartsCantBeSaved() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Water the plants"
        form.dueTime = Self.monday
        form.chooseCustom()
        form.customRepeat?.ending = .onDate
        form.customRepeat?.endDate = NewYork.local(2026, 10, 18)

        #expect(form.repeatBlock == .endsBeforeStart)
        #expect(form.saveBlock == .endsBeforeStart)
        #expect(form.save(to: model) == false)

        form.customRepeat?.endDate = Self.monday
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

        form.customRepeat?.count = 5
        #expect(form.repeatBlock == .noTimesLeft)
        #expect(form.saveBlock == .noTimesLeft)

        form.customRepeat?.count = 30
        #expect(form.saveBlock == nil)
        form.title = "Water the ferns"
        #expect(form.save(to: model))
    }

    @Test func aSavedCustomRepeatReopensWithItsChoicesAndAPresetReplacesIt() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Pay the cleaner"
        form.dueTime = NewYork.local(2026, 10, 28)
        form.chooseCustom()
        form.customRepeat?.frequency = .monthly
        form.customRepeat?.monthlyDay = .lastWeekdayOfMonth
        form.customRepeat?.ending = .afterCount
        form.customRepeat?.count = 5
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
        again.customRepeat?.toggle(.friday)
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
        form.chooseCustom()

        switch control {
        case "daily every 3":
            form.customRepeat?.frequency = .daily
            form.customRepeat?.interval = 3
        case "monthly last Wednesday":
            form.customRepeat?.frequency = .monthly
            form.customRepeat?.monthlyDay = .lastWeekdayOfMonth
        case "monthly fourth Wednesday":
            form.customRepeat?.frequency = .monthly
            form.customRepeat?.monthlyDay = .weekdayOfMonth
        case "monthly last day":
            form.customRepeat?.frequency = .monthly
            form.customRepeat?.monthlyDay = .lastDay
        case "yearly every 2":
            form.customRepeat?.frequency = .yearly
            form.customRepeat?.interval = 2
        default:
            form.customRepeat?.ending = .onDate
            form.customRepeat?.endDate = NewYork.local(2026, 12, 1, 0)
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
        form.chooseCustom()

        form.dueTime = NewYork.local(2026, 10, 20)

        #expect(form.upcomingDueTimes == [NewYork.local(2026, 10, 20), NewYork.local(2026, 10, 26), NewYork.local(2026, 11, 2)])
    }

    /// The clock is at 15 October 2026.
    @Test(arguments: [(NewYork.local(2026, 12, 31), false), (NewYork.local(2027, 1, 1), true)])
    func aNextTimeShowsItsYearOnlyWhenItIsntThisYear(dueTime: Date, showsYear: Bool) async throws {
        let model = try await launchedModel()

        #expect(newForm(on: model).showsYear(of: dueTime) == showsYear)
    }
}
