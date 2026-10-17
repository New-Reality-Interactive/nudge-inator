import Foundation
import NudgeEngine
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
}
