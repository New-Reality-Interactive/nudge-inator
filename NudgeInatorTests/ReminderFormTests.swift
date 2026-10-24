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
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
        await model.launch()
        return model
    }

    /// A New form. Its Default Pace is Escalating unless a test passes another, so the strength's
    /// own waits show until a test chooses Consistent.
    func newForm(on model: AppModel, defaultPace: DefaultPace = DefaultPace(choice: .escalating, consistentWait: 10 * 60)) -> ReminderForm {
        ReminderForm(engine: { model.engine }, now: { [clock] in clock.now }, defaultPace: defaultPace)
    }

    func editForm(of reminderID: Reminder.ID, on model: AppModel) throws -> ReminderForm {
        let form = ReminderForm(engine: { model.engine }, editing: reminderID, now: { [clock] in clock.now })
        return try #require(form)
    }

    /// Due at 7:30 and Firm, so at 8:00 it is Nudging.
    let bins = Reminder(title: "Take the bins out", dueTime: NewYork.local(2026, 10, 15, 7, 30), strength: .firm)

    /// The form's How It Nudges, the line under the strength and the line under the pace (ticket
    /// 31) follow the draft's strength, pace and switch, from the engine. Firm waits 30 min, then 15
    /// and 7.5, then its 5 min floor; Gentle waits an hour, easing to 20 min. Relentless rings from
    /// nudge 1 (ticket 05).
    nonisolated static let strengthAndPaceLines: [(Strength, Pace, Bool, StrengthBlurb, PaceBlurb, Int)] = [
        (.firm, .escalating, true, StrengthBlurb(firstAlarm: 4), PaceBlurb.escalating(firstWait: 30 * 60, floor: 5 * 60), 20),
        (.firm, .escalating, false, StrengthBlurb(firstAlarm: nil), .escalating(firstWait: 30 * 60, floor: 5 * 60), 20),
        (.gentle, .escalating, true, StrengthBlurb(firstAlarm: nil), .escalating(firstWait: 60 * 60, floor: 20 * 60), 20),
        (.relentless, .escalating, true, StrengthBlurb(firstAlarm: 1), .escalating(firstWait: 10 * 60, floor: 2 * 60), 20),
        // Relentless always breaks through Focus (ticket 06).
        (.relentless, .escalating, false, StrengthBlurb(firstAlarm: 1), .escalating(firstWait: 10 * 60, floor: 2 * 60), 20),
        (.firm, .consistent(wait: 10 * 60), true, StrengthBlurb(firstAlarm: 4), .consistent(wait: 10 * 60), 20),
        // Every 12 hr, a Firm reminder nudges at the due time and 12 hr on, then gives up at 24 hr,
        // before nudge 4 could ring.
        (.firm, .consistent(wait: 12 * 60 * 60), true, StrengthBlurb(firstAlarm: nil), .consistent(wait: 12 * 60 * 60), 2),
    ]

    @Test(arguments: strengthAndPaceLines)
    func theStrengthAndPaceLinesAndHowItNudgesFollowTheDraft(strength: Strength, pace: Pace, breakThroughFocus: Bool, strengthBlurb: StrengthBlurb, paceBlurb: PaceBlurb, nudgeCount: Int) async throws {
        manager.authorizationState = .authorized
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.strength = strength
        form.breakThroughFocus = breakThroughFocus
        if case .consistent(let wait) = pace {
            form.paceChoice = .consistent
            form.consistentWait = wait
        }

        #expect(form.strengthBlurb == strengthBlurb)
        #expect(form.paceBlurb == paceBlurb)
        #expect(form.howItNudges.nudgeCount == nudgeCount)
        #expect(form.howItNudges.rows.contains { $0.delivery == .alarm } == (strengthBlurb.firstAlarm != nil))
    }

    /// Spec stories 23 and 24: a reminder saved from New keeps the pace and wait chosen, and an
    /// Edit opens with them and saves them again (ticket 04 found the draft dropped the pace).
    @Test func aConsistentPaceAndItsWaitAreSavedFromNewAndKeptByAnEdit() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Water the plants"
        form.dueTime = NewYork.local(2026, 10, 16, 9)
        form.paceChoice = .consistent
        form.consistentWait = 30 * 60

        #expect(form.save(to: model))
        let saved = try #require(model.engine.reminders.only)
        #expect(saved.pace == .consistent(wait: 30 * 60))

        let edit = try editForm(of: saved.id, on: model)
        #expect(edit.paceChoice == .consistent)
        #expect(edit.consistentWait == 30 * 60)
        edit.title = "Water the ferns"
        #expect(edit.save(to: model))
        #expect(model.engine.reminders.only?.pace == .consistent(wait: 30 * 60))
    }

    /// Spec story 25: Escalating hides the Every row but keeps its wait, so Consistent finds it
    /// again, and a reminder saved Escalating carries no wait.
    @Test func escalatingKeepsTheWaitForConsistentAndSavesWithoutIt() async throws {
        let model = try await launchedModel()
        model.add(Reminder(title: "Stretch", dueTime: NewYork.local(2026, 10, 16, 9), strength: .firm, pace: .consistent(wait: 2 * 60 * 60)))
        let edit = try editForm(of: try #require(model.engine.reminders.only).id, on: model)

        edit.paceChoice = .escalating
        #expect(edit.hasChanges)
        #expect(edit.consistentWait == 2 * 60 * 60)
        edit.paceChoice = .consistent
        #expect(!edit.hasChanges)

        edit.paceChoice = .escalating
        #expect(edit.save(to: model))
        #expect(model.engine.reminders.only?.pace == .escalating)
    }

    /// Spec story 39: a new reminder starts with the Default Pace, and saves it unless changed.
    /// Escalating keeps the default's wait ready for Consistent.
    @Test(arguments: [
        (DefaultPace(choice: .consistent, consistentWait: 60 * 60), Pace.consistent(wait: 60 * 60)),
        (DefaultPace(choice: .escalating, consistentWait: 30 * 60), Pace.escalating),
    ])
    func aNewReminderStartsWithTheDefaultPace(defaultPace: DefaultPace, saved: Pace) async throws {
        let model = try await launchedModel()
        let form = newForm(on: model, defaultPace: defaultPace)

        #expect(form.paceChoice == defaultPace.choice)
        #expect(form.consistentWait == defaultPace.consistentWait)
        #expect(!form.hasChanges)
        form.title = "Water the plants"
        #expect(form.save(to: model))
        #expect(model.engine.reminders.only?.pace == saved)
    }

    /// Spec stories 30 and 31: Relentless shows the switch on and fixed, and leaving it gives back
    /// the value the person set, editable again.
    @Test(arguments: [Strength.firm, .gentle])
    func relentlessShowsTheSwitchOnAndLeavingItGivesTheSwitchBack(leavingFor strength: Strength) async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.breaksThroughFocus = false

        form.strength = .relentless
        #expect(form.breaksThroughFocus)
        #expect(form.isBreakThroughFocusFixed)

        form.strength = strength
        #expect(!form.breaksThroughFocus)
        #expect(!form.isBreakThroughFocusFixed)
    }

    /// The stored switch keeps the person's value, so a later change to Firm finds it (ADR 0004).
    @Test func aRelentlessReminderIsSavedWithTheSwitchThePersonSet() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Call the bank"
        form.dueTime = NewYork.local(2026, 10, 16, 9)
        form.breaksThroughFocus = false
        form.strength = .relentless

        #expect(form.save(to: model))

        let saved = try #require(model.engine.reminders.only)
        #expect(saved.breakThroughFocus == false)
        #expect(saved.breaksThroughFocus)
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

        #expect(form.lockedFields == [.dueTime, .repeatRule, .strength, .pace, .breakThroughFocus])
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
        form.customPageChoices.interval = 3
        form.chooseCustomPageChoices()

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

    /// A custom repeat the reminder had when the form opened is what comes back, not a default,
    /// and the Custom page drops what was changed on it too (ticket 17).
    @Test func aLockArrivingRestoresASavedCustomRepeat() async throws {
        let model = try await launchedModel()
        let everyThreeDays = try #require(RepeatRule(frequency: .daily, interval: 3))
        let saved = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 9), repeatRule: everyThreeDays, strength: .gentle)
        model.add(saved)
        let form = try editForm(of: saved.id, on: model)
        form.customPageChoices.interval = 5
        form.chooseCustomPageChoices()
        form.customPageChoices.interval = 7

        clock.now = NewYork.local(2026, 10, 15, 9, 5)
        form.checkLock()

        #expect(form.repeatRule == everyThreeDays)
        #expect(form.customPageChoices.interval == 3)
        #expect(!form.hasChanges)
    }

    /// A saved Consistent · 30 min comes back whole: the switch to Escalating and the wait changed
    /// before it are both undone, so choosing Consistent can't show a wait that wasn't saved.
    @Test func aLockArrivingRestoresTheSavedPaceAndItsWait() async throws {
        let model = try await launchedModel()
        let saved = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 9), strength: .firm, pace: .consistent(wait: 30 * 60))
        model.add(saved)
        let form = try editForm(of: saved.id, on: model)
        form.consistentWait = 15 * 60
        form.paceChoice = .escalating

        clock.now = NewYork.local(2026, 10, 15, 9, 5)
        form.checkLock()

        #expect(form.paceChoice == .consistent)
        #expect(form.consistentWait == 30 * 60)
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

    /// A wait changed after the reminder started nudging is turned down at Save and put back, and
    /// the title then saves with the pace as it was.
    @Test func aSaveThatChangesTheWaitAfterTheReminderStartedNudgingIsTurnedDown() async throws {
        let model = try await launchedModel()
        let later = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 9), strength: .firm, pace: .consistent(wait: 30 * 60))
        model.add(later)
        let form = try editForm(of: later.id, on: model)

        clock.now = NewYork.local(2026, 10, 15, 9, 5)
        form.consistentWait = 2 * 60

        #expect(form.save(to: model) == false)
        #expect(form.paceChoice == .consistent)
        #expect(form.consistentWait == 30 * 60)
        #expect(model.engine.reminders == [later])

        form.title = "Call the bank about the card"
        #expect(form.save(to: model))
        #expect(model.engine.reminders.only?.title == "Call the bank about the card")
        #expect(model.engine.reminders.only?.pace == .consistent(wait: 30 * 60))
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

        form.customRepeat = form.customPageChoices

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

        let shown = form.customPageChoices

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

    /// Device check, ticket 17: from Never, the weekly repeat the page shows couldn't be chosen as
    /// it was. The checkmark chooses it with no control changed.
    @Test func theCheckmarkChoosesTheShownChoicesFromNever() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = Self.monday

        form.chooseCustomPageChoices()

        #expect(form.repeatPreset == nil)
        #expect(form.repeatRule?.rrule == "FREQ=WEEKLY;BYDAY=MO")
        #expect(form.repeatSummary == "Every Monday at 9:00\u{202F}AM")
    }

    /// Back drops what was changed on the page: the repeat stays as it was, and the page opens
    /// again on it.
    @Test func backDropsTheCustomPagesChanges() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = Self.monday
        form.repeatPreset = .everyDay

        form.customPageChoices.interval = 3
        form.closeCustomPage()

        #expect(form.repeatPreset == .everyDay)
        #expect(form.customPageChoices == model.engine.customRepeat(from: .everyDay, startingAt: Self.monday))
        #expect(form.customPageSummary == "Every day at 9:00\u{202F}AM")
    }

    /// The page's changes aren't in the draft before its checkmark, but they count as changes,
    /// so a swipe down on the Custom page can't drop them unasked.
    @Test func theCustomPagesChangesCountAsChangesUntilBack() async throws {
        let model = try await launchedModel()
        let daily = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 16, 9), repeatRule: .everyDay, strength: .gentle)
        model.add(daily)
        let form = try editForm(of: daily.id, on: model)

        form.customPageChoices.interval = 3
        #expect(form.hasChanges)

        // Changed back to what the repeat already is: nothing to lose.
        form.customPageChoices.interval = 1
        #expect(!form.hasChanges)

        form.customPageChoices.interval = 3
        form.closeCustomPage()
        #expect(!form.hasChanges)
    }

    /// A choice made on the page changes the page's copy, which its summary shows. Only the
    /// checkmark makes it the repeat, which is then Custom.
    @Test func aChoiceOnTheCustomPageMakesTheRepeatCustomOnlyAtTheCheckmark() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = Self.monday
        form.repeatPreset = .everyDay

        form.customPageChoices.interval = 3

        #expect(form.customPageSummary == "Every 3 days at 9:00\u{202F}AM")
        #expect(form.repeatPreset == .everyDay)

        form.chooseCustomPageChoices()

        #expect(form.repeatPreset == nil)
        #expect(form.repeatRule?.rrule == "FREQ=DAILY;INTERVAL=3")
        #expect(form.customPageChoices.interval == 3)
    }

    /// Choosing the choices a preset starts the page from, as the checkmark does, must not
    /// change when the reminder falls due. The rule may be written differently (a weekly rule
    /// names its weekday), but the times are the same. Never is left out: it starts a weekly page.
    @Test(arguments: RepeatPreset.allCases.filter { $0 != .never })
    func storingAPresetsStartingChoicesKeepsItsDueTimes(preset: RepeatPreset) async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = Self.monday
        form.repeatPreset = preset
        let before = form.upcomingDueTimes

        form.chooseCustomPageChoices()

        #expect(form.upcomingDueTimes == before)
    }

    /// Accepted (ticket 25): Every Month from the 31st uses the last day of a short month, but the
    /// Custom page's "On the 31st" skips it, and says so in its footer. The checkmark chooses that.
    @Test func storingEveryMonthsChoicesFromThe31stSkipsTheShortMonths() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = NewYork.local(2026, 10, 31)
        form.repeatPreset = .everyMonth
        #expect(form.upcomingDueTimes.prefix(2).last == NewYork.local(2026, 11, 30))

        form.chooseCustomPageChoices()

        #expect(form.upcomingDueTimes.prefix(2).last == NewYork.local(2026, 12, 31))
    }

    /// A reminder with a custom repeat already shows it, and nothing is seeded over it.
    @Test func theCustomPageShowsAnExistingCustomRepeat() async throws {
        let model = try await launchedModel()
        // Its own line: passed straight to the optional `repeatRule:`, `#require` would infer an
        // optional result and unwrap nothing.
        let rule = try #require(RepeatRule(frequency: .daily, interval: 3))
        let custom = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 16, 9),
                              repeatRule: rule, strength: .gentle)
        model.add(custom)
        let form = try editForm(of: custom.id, on: model)

        #expect(form.customPageChoices.interval == 3)
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

        form.customPageChoices.toggle(.wednesday)
        #expect(form.customPageUpcomingDueTimes == [Self.monday, NewYork.local(2026, 10, 21), NewYork.local(2026, 11, 2)])

        form.customPageChoices.ending = .afterCount
        form.customPageChoices.count = 2
        #expect(form.customPageUpcomingDueTimes == [Self.monday, NewYork.local(2026, 10, 21)])
        let expected = Reminder(title: "Water the plants", dueTime: Self.monday,
                                repeatRule: try RepeatRule(rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE;COUNT=2"), strength: .firm)
        #expect(form.customPageSummary == model.engine.repeatSummary(of: expected))
        #expect(form.customPageUpcomingDueTimes == model.engine.upcomingDueTimes(of: expected, count: 3))
    }

    /// Wednesday 28 October is October's last Wednesday; 18 November isn't November's.
    @Test func aMonthlyChoiceANewStartDoesntOfferFallsBackToItsDayOfTheMonth() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.dueTime = NewYork.local(2026, 10, 28)
        form.repeatPreset = .everyMonth
        form.customPageChoices.monthlyDay = .lastWeekdayOfMonth
        form.chooseCustomPageChoices()
        #expect(form.repeatRule?.rrule == "FREQ=MONTHLY;BYDAY=-1WE")

        form.dueTime = NewYork.local(2026, 11, 18)

        #expect(form.repeatRule?.rrule == "FREQ=MONTHLY;BYMONTHDAY=18")
    }

    @Test func aCustomRepeatThatEndsBeforeItStartsCantBeSaved() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Water the plants"
        form.dueTime = Self.monday
        form.customPageChoices.ending = .onDate
        form.customPageChoices.endDate = NewYork.local(2026, 10, 18)
        #expect(form.customPageBlock == .endsBeforeStart)
        form.chooseCustomPageChoices()

        #expect(form.repeatBlock == .endsBeforeStart)
        #expect(form.saveBlock == .endsBeforeStart)
        #expect(form.save(to: model) == false)

        form.customPageChoices.endDate = Self.monday
        #expect(form.customPageBlock == nil)
        form.chooseCustomPageChoices()
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

        #expect(form.customPageBlock == nil)

        form.customPageChoices.count = 5
        #expect(form.customPageBlock == .noTimesLeft)
        form.chooseCustomPageChoices()
        #expect(form.repeatBlock == .noTimesLeft)
        #expect(form.saveBlock == .noTimesLeft)

        form.customPageChoices.count = 30
        form.chooseCustomPageChoices()
        #expect(form.saveBlock == nil)
        form.title = "Water the ferns"
        #expect(form.save(to: model))
    }

    @Test func aSavedCustomRepeatReopensWithItsChoicesAndAPresetReplacesIt() async throws {
        let model = try await launchedModel()
        let form = newForm(on: model)
        form.title = "Pay the cleaner"
        form.dueTime = NewYork.local(2026, 10, 28)
        form.customPageChoices.frequency = .monthly
        form.customPageChoices.monthlyDay = .lastWeekdayOfMonth
        form.customPageChoices.ending = .afterCount
        form.customPageChoices.count = 5
        form.chooseCustomPageChoices()
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
        again.chooseCustomPageChoices()
        #expect(again.repeatRule == summer.repeatRule)
        again.customPageChoices.toggle(.friday)
        again.chooseCustomPageChoices()
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
            form.customPageChoices.frequency = .daily
            form.customPageChoices.interval = 3
        case "monthly last Wednesday":
            form.customPageChoices.frequency = .monthly
            form.customPageChoices.monthlyDay = .lastWeekdayOfMonth
        case "monthly fourth Wednesday":
            form.customPageChoices.frequency = .monthly
            form.customPageChoices.monthlyDay = .weekdayOfMonth
        case "monthly last day":
            form.customPageChoices.frequency = .monthly
            form.customPageChoices.monthlyDay = .lastDay
        case "yearly every 2":
            form.customPageChoices.frequency = .yearly
            form.customPageChoices.interval = 2
        default:
            form.customPageChoices.ending = .onDate
            form.customPageChoices.endDate = NewYork.local(2026, 12, 1, 0)
        }
        form.chooseCustomPageChoices()

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
        form.customRepeat = form.customPageChoices

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
        let form = ReminderForm(engine: { model.engine }, now: { now }, defaultPace: .shipped, tagIDs: [home.id])
        let hasChanges = form.hasChanges
        form.title = "Water the plants"

        #expect(form.tagIDs == [home.id])
        #expect(!hasChanges)
        #expect(form.save(to: model))
        #expect(model.engine.reminders.first?.tagIDs == [home.id])
        #expect(model.engine.reminders.first?.pace == .consistent(wait: 10 * 60))
    }
}
