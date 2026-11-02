import Foundation
import NudgeEngine
import Testing
@testable import NudgeDeviceSeed

@MainActor
struct DeviceSeedTests {
    let target = FakeTarget()
    let store = MemoryRecordStore()
    var sets: [SeedSet] { [.sample, .other] }

    func run(_ command: String) -> SeedOutcome {
        DeviceSeed.run(command: command, sets: sets, on: target, record: store)
    }

    // MARK: Load

    @Test func loadingASetAddsItsRemindersAndTags() {
        #expect(run("sample") == .loaded("sample"))

        #expect(target.reminders.map(\.title).sorted() == ["Buy milk", "Call home"])
        #expect(target.tags.map(\.name) == ["errands"])
        let milk = target.reminders.first { $0.title == "Buy milk" }
        #expect(milk?.tagIDs == target.tags.map(\.id))
    }

    @Test func dueTimesAndCreationDatesCountFromNow() throws {
        _ = run("sample")

        let call = try #require(target.reminders.first { $0.title == "Call home" })
        #expect(call.dueTime == target.now - 600)
        #expect(call.createdAt == target.now - 86400)
    }

    @Test func aSetsRemindersKeepTheirIDs() {
        _ = run("sample")

        #expect(Set(target.reminders.map(\.id)) == Set(SeedSet.sample.reminders.map(\.id)))
    }

    @Test func remindersHaveBreakThroughFocusOffUnlessTheSetAsksForIt() {
        _ = run("sample")

        #expect(target.reminders.allSatisfy { !$0.breakThroughFocus })
    }

    @Test func loadingTheSameSetTwiceLeavesOneCopy() {
        _ = run("sample")
        _ = run("sample")

        #expect(target.reminders.count == 2)
        #expect(target.tags.count == 1)
        #expect(Set(target.reminders.map(\.id)).count == 2)
    }

    @Test func loadingAgainBringsBackAReminderThePersonDeleted() {
        _ = run("sample")
        target.delete(SeedSet.sample.reminders[0].id)

        _ = run("sample")

        #expect(target.reminders.count == 2)
    }

    @Test func theRecordListsTheDataBeforeTheFirstReminderIsAdded() {
        target.record = { self.store.record }

        _ = run("sample")

        let recorded = target.recordWhenFirstAdded?.sets["sample"]
        #expect(Set(recorded?.reminderIDs ?? []) == Set(SeedSet.sample.reminders.map(\.id)))
        #expect(recorded?.createdTagIDs.count == 1)
    }

    @Test func anUnknownSetChangesNothing() {
        #expect(run("nope") == .unknownSet("nope"))

        #expect(target.reminders.isEmpty)
        #expect(store.record == SeedRecord())
    }

    // MARK: Tags

    @Test func aTagThePersonAlreadyHasIsUsedButNotRecorded() throws {
        _ = target.addPersonsOwn(title: "Mine", tagNamed: "errands")
        let theirTag = try #require(target.tags.first)

        _ = run("sample")

        #expect(target.tags == [theirTag])
        let milk = try #require(target.reminders.first { $0.title == "Buy milk" })
        #expect(milk.tagIDs == [theirTag.id])
        #expect(store.record.sets["sample"]?.createdTagIDs == [])
    }

    @Test func removalLeavesATagThePersonAlreadyHad() throws {
        let mine = target.addPersonsOwn(title: "Mine", tagNamed: "errands")
        let theirTag = try #require(target.tags.first)
        _ = run("sample")

        _ = run("clean")

        #expect(target.tags == [theirTag])
        #expect(target.reminders.map(\.id) == [mine.id])
        #expect(target.reminders.first?.tagIDs == [theirTag.id])
    }

    @Test func aTagAnotherLoadedSetMadeIsSharedAndGoesWithTheLastOfThem() {
        _ = run("sample")
        _ = run("other")
        #expect(target.tags.count == 1)

        _ = run("clean")

        #expect(target.tags.isEmpty)
        #expect(target.reminders.isEmpty)
    }

    // MARK: Removal

    @Test func removalDeletesTheSetsRemindersAndTags() {
        _ = run("sample")

        #expect(run("clean") == .cleaned)

        #expect(target.reminders.isEmpty)
        #expect(target.tags.isEmpty)
        #expect(store.record == SeedRecord())
    }

    @Test func removalLeavesEverythingElseAlone() {
        let mine = target.addPersonsOwn(title: "Buy milk", tagNamed: "home")
        let myTag = target.tags.first
        _ = run("sample")

        _ = run("clean")

        #expect(target.reminders.map(\.id) == [mine.id])
        #expect(target.tags == [myTag].compactMap { $0 })
    }

    @Test func removalFindsTheSetsRemindersByIDNotByTitle() {
        let mine = target.addPersonsOwn(title: "Call home")
        _ = run("sample")

        _ = run("clean")

        #expect(target.reminders.map(\.id) == [mine.id])
    }

    @Test func removalKeepsATagAReminderOfThePersonsNowUses() throws {
        _ = run("sample")
        let seededTag = try #require(target.tags.first)
        var theirs = Reminder(title: "Mine", tagIDs: [seededTag.id], dueTime: target.now, strength: .gentle)
        theirs.createdAt = target.now
        target.add(theirs)

        _ = run("clean")

        #expect(target.tags == [seededTag])
        #expect(target.reminders.map(\.id) == [theirs.id])
    }

    @Test func removalWithNothingLoadedDoesNothing() {
        let mine = target.addPersonsOwn(title: "Mine")

        #expect(run("clean") == .cleaned)

        #expect(target.reminders.map(\.id) == [mine.id])
    }

    @Test func removalTwiceIsHarmless() {
        _ = run("sample")
        _ = run("clean")

        #expect(run("clean") == .cleaned)
        #expect(target.reminders.isEmpty)
    }

    // MARK: Settings

    @Test func aSetCanChangeSettings() {
        _ = run("sample")

        #expect(target.setting(.remindersSort) == "dueDate.descending")
        #expect(target.setting(.defaultPace) == "escalating.600")
    }

    @Test func removalPutsSettingsBack() {
        target.setSetting(.remindersSort, to: "created.descending")
        _ = run("sample")

        _ = run("clean")

        #expect(target.setting(.remindersSort) == "created.descending")
    }

    @Test func loadingAgainKeepsTheOriginalSettingToRestore() {
        target.setSetting(.remindersSort, to: "created.descending")
        _ = run("sample")
        _ = run("sample")

        _ = run("clean")

        #expect(target.setting(.remindersSort) == "created.descending")
    }

    @Test func twoSetsChangingTheSameSettingRestoreTheOriginal() {
        target.setSetting(.remindersSort, to: "created.ascending")
        _ = run("sample")
        _ = run("other")

        _ = run("clean")

        #expect(target.setting(.remindersSort) == "created.ascending")
    }

    // MARK: Shipped sets

    @Test func everyShippedSetIsNamedOnceAndHasUniqueReminderIDs() {
        let names = SeedSet.all.map(\.name)
        #expect(Set(names).count == names.count)
        #expect(!names.contains("clean"))
        let ids = SeedSet.all.flatMap { $0.reminders.map(\.id) }
        #expect(Set(ids).count == ids.count)
    }

    @Test func noShippedReminderCanScheduleAnAlarm() {
        // Relentless always breaks through Focus, and an alarm outlives an uninstall.
        let reminders = SeedSet.all.flatMap(\.reminders).map { $0.reminder(tagIDs: [], now: target.now) }
        #expect(reminders.allSatisfy { !$0.breakThroughFocus && $0.strength != .relentless })
    }

    @Test(arguments: SeedSet.all)
    func everyReminderNamesTagsItsSetDeclares(set: SeedSet) {
        #expect(Set(set.reminders.flatMap(\.tagNames)).isSubset(of: set.tags))
    }

    @Test func theSearchSetExists() {
        #expect(SeedSet.all.contains { $0.name == "search" })
    }

    @Test(arguments: SeedSet.all)
    func everyShippedSetLoadsAndRemovesCleanly(set: SeedSet) {
        let before = target.addPersonsOwn(title: "Mine")

        _ = DeviceSeed.run(command: set.name, sets: SeedSet.all, on: target, record: store)
        #expect(target.reminders.count == set.reminders.count + 1)
        _ = DeviceSeed.run(command: "clean", sets: SeedSet.all, on: target, record: store)

        #expect(target.reminders.map(\.id) == [before.id])
        #expect(target.tags.isEmpty)
    }
}
