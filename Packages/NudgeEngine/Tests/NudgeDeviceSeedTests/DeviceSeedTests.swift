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

    /// #497: a check that turned Quiet Now on by hand leaves nothing behind, with any set loaded or none.
    @Test(arguments: ["sample", "none"])
    func cleanTurnsQuietNowOff(loaded: String) {
        if loaded != "none" { _ = run(loaded) }
        target.isQuietNowOn = true

        _ = run("clean")

        #expect(!target.isQuietNowOn)
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

    /// Nothing on screen shows seconds, so a due time with some rings off the minute it shows. Down,
    /// not up, as the screen reads it. The creation date isn't a time anything fires at.
    @Test(arguments: [
        (dueIn: 180.0, due: 60_180.0),
        (dueIn: -600.0, due: 59_400.0),
    ])
    func aDueTimeRoundsDownToTheWholeMinute(dueIn: TimeInterval, due: TimeInterval) {
        let now = Date(timeIntervalSinceReferenceDate: 60_037.5)
        let seed = SeedReminder(id: SeedReminder.fixedID(99), title: "Whole minute", dueIn: dueIn, createdAgo: 30)

        let reminder = seed.reminder(tagIDs: [], now: now)

        #expect(reminder.dueTime == Date(timeIntervalSinceReferenceDate: due))
        #expect(reminder.createdAt == Date(timeIntervalSinceReferenceDate: 60_007.5))
    }

    /// Disconnect's check (ticket 197) needs reminders received from the stand-in's connection.
    @Test func aSeedReminderKeepsTheOriginItIsGiven() {
        let origin = ReminderOrigin.received(connectionID: SeedSet.standInConnectionID, sendersReminderID: UUID(), revision: 1, state: .waiting)
        let seed = SeedReminder(id: SeedReminder.fixedID(98), title: "From Riley", dueIn: 60, origin: origin)

        #expect(seed.reminder(tagIDs: [], now: .now).origin == origin)
        #expect(SeedReminder(id: SeedReminder.fixedID(97), title: "Mine", dueIn: 60).reminder(tagIDs: [], now: .now).origin == .mine)
    }

    /// Use for All Reminders' check (#458) needs a reminder on a tone.
    @Test func aSeedReminderKeepsTheAlarmSoundItIsGiven() {
        let seed = SeedReminder(id: SeedReminder.fixedID(96), title: "On a tone", dueIn: 60, alarmSound: .chime)

        #expect(seed.reminder(tagIDs: [], now: .now).alarmSound == .chime)
        #expect(SeedReminder(id: SeedReminder.fixedID(95), title: "Mine", dueIn: 60).reminder(tagIDs: [], now: .now).alarmSound == .default)
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

    /// The stand-in sharing's Riley Park can send reminders on the phone check (ticket 198). Their
    /// copies have IDs of their own, so removal finds them by the stand-in's connection instead, and
    /// leaves what came through any other.
    @Test func removalDeletesWhatTheStandInsPersonSent() {
        let fromStandIn = Reminder(title: "Bring the umbrella", dueTime: target.now, strength: .gentle,
                                   origin: .received(connectionID: SeedSet.standInConnectionID, sendersReminderID: UUID(), revision: 0, state: .accepted))
        let fromSomeoneElse = Reminder(title: "Feed the cat", dueTime: target.now, strength: .gentle,
                                       origin: .received(connectionID: UUID(), sendersReminderID: UUID(), revision: 0, state: .accepted))
        target.add(fromStandIn)
        target.add(fromSomeoneElse)

        #expect(run(DeviceSeed.cleanCommand) == .cleaned)

        #expect(target.reminders.map(\.title) == ["Feed the cat"])
    }

    /// Keep as My Own Reminders makes a stand-in send the person's own, with no connection to find
    /// it by (#199's phone check left one behind), so removal finds it by the notes the stand-in
    /// writes, and leaves the person's own.
    @Test func removalDeletesWhatTheStandInsPersonSentAfterItWasKept() {
        let kept = Reminder(title: "Bring the umbrella", notes: SeedSet.standInSentNotes, dueTime: target.now, strength: .gentle)
        let mine = target.addPersonsOwn(title: "Mine")
        target.add(kept)

        #expect(run(DeviceSeed.cleanCommand) == .cleaned)

        #expect(target.reminders.map(\.id) == [mine.id])
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

    // MARK: Quiet hours before the load (#369)

    /// The span reads as quiet hours that were on then and turned off at the load, so the set's
    /// past nudges count as held. It is in place before the first reminder, so that reminder's
    /// plan reads it.
    @Test func aSetCanMakeASpanBeforeTheLoadReadAsQuietHours() throws {
        let sets: [SeedSet] = [.quiet]
        _ = DeviceSeed.run(command: "quiet", sets: sets, on: target, record: store)

        let span = try #require(target.quietSpans.first)
        #expect(target.quietSpans.count == 1)
        #expect(span.from == target.now - 3 * 3600)
        #expect(span.to == target.now - 2 * 3600)
        #expect(span.replacedAt == target.now)
        #expect(target.quietSpansWhenFirstAdded == 1)
    }

    @Test func loadingAgainReplacesTheSpanAndRemovalTakesItAway() {
        let sets: [SeedSet] = [.quiet]
        _ = DeviceSeed.run(command: "quiet", sets: sets, on: target, record: store)
        target.now += 600
        target.addQuietSpan(from: target.now - 7200, to: target.now - 3600, replacedAt: target.now - 60)
        _ = DeviceSeed.run(command: "quiet", sets: sets, on: target, record: store)
        #expect(target.quietSpans.map(\.replacedAt) == [target.now - 60, target.now])

        _ = DeviceSeed.run(command: "clean", sets: sets, on: target, record: store)

        // Only the seed's own span goes; the person's stays.
        #expect(target.quietSpans.map(\.replacedAt) == [target.now - 60])
    }

    /// So a launch that stops partway still leaves a span `clean` can find.
    @Test func theRecordListsTheSpanBeforeItIsAdded() {
        target.record = { self.store.record }
        _ = DeviceSeed.run(command: "quiet", sets: [.quiet], on: target, record: store)

        #expect(target.recordWhenSpanAdded?.sets["quiet"]?.quietSpanAddedAt == target.now)
    }

    @Test func aSetWithoutASpanAddsNone() {
        _ = run("sample")
        _ = run("clean")

        #expect(target.quietSpans.isEmpty)
    }

    // MARK: Shipped sets

    @Test func everyShippedSetIsNamedOnceAndHasUniqueReminderIDs() {
        let names = SeedSet.all.map(\.name)
        #expect(Set(names).count == names.count)
        #expect(!names.contains("clean"))
        let ids = SeedSet.all.flatMap { $0.reminders.map(\.id) }
        #expect(Set(ids).count == ids.count)
    }

    /// The sets whose reminders ring on purpose, by the developer's go of 2026-11-22 (#379): the
    /// device checks of what quiet hours do to real alarms. Each cancels its alarms in `clean`.
    static let setsThatRing: Set<String> = ["urgency-cards", "quiet-hours-window", "quiet-hours-ringing", "quiet-hours-edit", "quiet-hours-quiet-now"]

    @Test func noShippedReminderCanScheduleAnAlarmExceptInTheNamedSets() {
        // Relentless always breaks through Focus, and an alarm outlives an uninstall, so a set
        // schedules none, and `clean` removes it, unless it is named in `setsThatRing`:
        // `urgency-cards` (#442: Urgent on Relentless is a card to look at) and the quiet hours
        // alarm sets (#379).
        let sets = SeedSet.all.filter { !Self.setsThatRing.contains($0.name) }
        let reminders = sets.flatMap(\.reminders).map { $0.reminder(tagIDs: [], now: target.now) }
        #expect(reminders.allSatisfy { !$0.breakThroughFocus && $0.strength != .relentless })
    }

    @Test func everyNamedRingingSetIsShipped() {
        #expect(Self.setsThatRing.isSubset(of: Set(SeedSet.all.map(\.name))))
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

// MARK: A quiet window timed from the load, and a reminder that rings (#379)

@MainActor
struct SeedQuietWindowTests {
    let target = FakeTarget()
    let store = MemoryRecordStore()

    static let window = SeedSet(
        name: "window",
        quietWindow: SeedQuietWindow(startIn: 3 * 60, length: 6 * 60),
        reminders: [
            SeedReminder(id: SeedReminder.fixedID(105), title: "Rings", dueIn: -120, strength: .firm, pace: .consistent(wait: 120), breakThroughFocus: true),
        ]
    )

    @Test func aSeedReminderKeepsItsPaceAndBreakThroughFocus() {
        let rings = Self.window.reminders[0].reminder(tagIDs: [], now: target.now)

        #expect(rings.breakThroughFocus)
        #expect(rings.pace == .consistent(wait: 120))
        let plain = SeedReminder(id: SeedReminder.fixedID(106), title: "Quiet", dueIn: 60).reminder(tagIDs: [], now: target.now)
        #expect(!plain.breakThroughFocus)
        #expect(plain.pace == .escalating)
    }

    @Test func theWindowStartsAndEndsOnWholeMinutesCountedFromTheLoad() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let load = target.now + 41  // 00:00:41 after a whole minute

        let times = Self.window.quietWindow!.times(from: load, calendar: calendar)

        let minuteOfDay = calendar.component(.hour, from: target.now) * 60 + calendar.component(.minute, from: target.now)
        #expect(times.start == TimeOfDay(wrappingMinutes: minuteOfDay + 3))
        #expect(times.end == TimeOfDay(wrappingMinutes: minuteOfDay + 9))
    }

    @Test func aWindowThatCrossesMidnightWrapsOntoTheClock() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let lateEvening = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 23, minute: 58, second: 20)))

        let times = SeedQuietWindow(startIn: 0, length: 5 * 60).times(from: lateEvening, calendar: calendar)

        #expect(times.start == (try TimeOfDay(hour: 23, minute: 58)))
        #expect(times.end == (try TimeOfDay(hour: 0, minute: 3)))
    }

    @Test func loadingWritesTheWindowAsTheQuietHoursSchedule() {
        _ = DeviceSeed.run(command: "window", sets: [Self.window], on: target, record: store)

        let times = Self.window.quietWindow!.times(from: target.now, calendar: .autoupdatingCurrent)
        func hhmm(_ time: TimeOfDay) -> String { String(format: "%02d:%02d", time.hour, time.minute) }
        #expect(target.setting(.quietHours) == "\(hhmm(times.start))-\(hhmm(times.end)) SU,MO,TU,WE,TH,FR,SA on")
    }

    /// The window and the reminders count from one read of the clock, whatever it reads next.
    @Test func theWindowAndTheDueTimesCountFromTheSameInstant() {
        let moving = MovingClockTarget()

        _ = DeviceSeed.run(command: "window", sets: [Self.window], on: moving, record: store)

        #expect(moving.nowReads == 1)
    }

    @Test func cleanPutsTheEarlierSchedulesBack() {
        target.setSetting(.quietHours, to: "22:00-07:00 SU on")

        _ = DeviceSeed.run(command: "window", sets: [Self.window], on: target, record: store)
        _ = DeviceSeed.run(command: "clean", sets: [Self.window], on: target, record: store)

        #expect(target.setting(.quietHours) == "22:00-07:00 SU on")
        #expect(target.reminders.isEmpty)
    }
}
