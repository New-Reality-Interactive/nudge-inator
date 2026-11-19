import Foundation
import Testing
import NudgeEngine
import SwiftData
@testable import NudgeInator

/// 1.3.0 opens 1.2.0's store (schema version 1) under schema version 2, which adds the creation
/// date. Each test writes a file with version 1's schema, then opens it as a relaunch would.
@MainActor
struct StoreMigrationTests {
    let storeFile = TemporaryStoreFile()
    var fileURL: URL { storeFile.url }

    let home = Tag(name: "home")
    let health = Tag(name: "health")
    let pills = Reminder(
        title: "Take the pills",
        notes: "With food",
        tagIDs: [UUID(), UUID()],
        dueTime: NewYork.local(2026, 10, 15, 9),
        repeatRule: .everyDay,
        strength: .firm,
        pace: .consistent(wait: 300),
        breakThroughFocus: false
    )
    let bins = Reminder(title: "Put the bins out", dueTime: NewYork.local(2026, 10, 16, 19), strength: .relentless)
    let rent = Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 11, 1, 9), strength: .gentle)
    let migrationInstant = NewYork.local(2026, 10, 30, 12)

    /// What 1.2.0 saved for `pills`: one closed occurrence, two pauses (one open), a replaced title.
    var pillsHistory: ReminderHistory {
        ReminderHistory(
            closedOccurrences: [
                NewYork.local(2026, 10, 15, 9): Closing(state: .done, closedAt: NewYork.local(2026, 10, 15, 9, 5), nudgesSent: 1),
                NewYork.local(2026, 10, 16, 9): Closing(state: .missed(reason: .giveUpLimit), closedAt: NewYork.local(2026, 10, 16, 11), nudgesSent: 20),
            ],
            editAppliesAfter: NewYork.local(2026, 10, 16, 9),
            pauseSpans: [
                PauseSpan(start: NewYork.local(2026, 10, 17, 8), end: NewYork.local(2026, 10, 18, 8)),
                PauseSpan(start: NewYork.local(2026, 10, 19, 8)),
            ],
            replacedTitles: [Replaced(value: "Take the blue pills", replacedAt: NewYork.local(2026, 10, 14, 7))]
        )
    }

    func openAfterUpdate() throws -> ReminderStore {
        try ReminderStore(location: .file(fileURL), now: migrationInstant)
    }

    @Test func aVersion1StoreOpensWithEveryReminderHistoryAndTagKept() throws {
        try Version1Store.write(to: fileURL, reminders: [pills, bins, rent], tags: [home, health], histories: [pills.id: pillsHistory])

        let loaded = try openAfterUpdate().load()

        func stamped(_ reminder: Reminder) -> Reminder {
            var reminder = reminder
            reminder.createdAt = migrationInstant
            return reminder
        }
        #expect(loaded == StoredData(
            reminders: [pills, bins, rent].map(stamped),
            tags: [home, health],
            histories: [pills.id: pillsHistory]
        ))
    }

    /// Every closing state 1.2.0 saved (Done, both Missed reasons, Skipped, and the Nudging state
    /// the type allows, with its number), every repeat shape (none; a preset that moves to a
    /// month's last day; a custom rule that skips; a custom rule with an interval and weekdays; an
    /// UNTIL at a day; an UNTIL at an instant with a fraction of a second; a COUNT), both paces, a
    /// closed and an open pause, and a closing fixed by an Edit (`editAppliesAfter`).
    @Test func aVersion1StoreWithEveryClosingStateAndRepeatShapeOpensWithAllOfThemKept() throws {
        let instant = NewYork.local(2026, 10, 15, 9)
        let untilInstant = NewYork.local(2026, 12, 31, 23, 59).addingTimeInterval(59.5)
        let monthly = Reminder(title: "Pay the card", dueTime: instant, repeatRule: .everyMonth, strength: .firm)
        let skipping = Reminder(
            title: "Month-end report",
            dueTime: NewYork.local(2026, 10, 31, 9),
            repeatRule: RepeatRule(frequency: .monthly, missingDay: .skip),
            strength: .relentless,
            pace: .escalating
        )
        let ending = Reminder(
            title: "Water the plants",
            dueTime: instant,
            repeatRule: RepeatRule(frequency: .daily, end: .untilTime(untilInstant)),
            strength: .gentle,
            pace: .consistent(wait: 900),
            breakThroughFocus: false
        )
        let alternating = Reminder(
            title: "Bin day",
            dueTime: instant,
            repeatRule: RepeatRule(frequency: .weekly, interval: 2, weekdays: [RepeatRule.WeekdayNumber(.monday), RepeatRule.WeekdayNumber(.thursday)]),
            strength: .gentle
        )
        let untilDay = Reminder(
            title: "Physio exercises",
            dueTime: instant,
            repeatRule: RepeatRule(frequency: .daily, end: .untilDate(year: 2026, month: 12, day: 31)),
            strength: .firm
        )
        let counted = Reminder(title: "Course lessons", dueTime: instant, repeatRule: RepeatRule(frequency: .weekly, end: .count(6)), strength: .firm)
        let never = Reminder(title: "Renew the passport", dueTime: NewYork.local(2027, 1, 5, 9), strength: .gentle)
        func closing(_ state: OccurrenceState, closedAtHour hour: Int) -> Closing {
            Closing(state: state, closedAt: NewYork.local(2026, 10, 15, hour, 30), nudgesSent: hour)
        }
        let history = ReminderHistory(
            closedOccurrences: [
                NewYork.local(2026, 10, 10, 9): closing(.done, closedAtHour: 9),
                NewYork.local(2026, 10, 11, 9): closing(.missed(reason: .giveUpLimit), closedAtHour: 10),
                NewYork.local(2026, 10, 12, 9): closing(.missed(reason: .nextTookOver), closedAtHour: 11),
                NewYork.local(2026, 10, 13, 9): closing(.skipped(reason: .paused), closedAtHour: 12),
                NewYork.local(2026, 10, 14, 9): closing(.nudging(nudgeNumber: 4), closedAtHour: 13),
            ],
            editAppliesAfter: NewYork.local(2026, 10, 14, 9),
            pauseSpans: [PauseSpan(start: NewYork.local(2026, 10, 12, 8), end: NewYork.local(2026, 10, 13, 8))],
            replacedTitles: [Replaced(value: "Pay card", replacedAt: NewYork.local(2026, 10, 9, 7))]
        )
        let reminders = [monthly, skipping, ending, alternating, untilDay, counted, never]
        // Paused and not resumed, the open span the history above doesn't hold.
        let stillPaused = ReminderHistory(pauseSpans: [PauseSpan(start: NewYork.local(2026, 10, 14, 8))])
        let histories = [monthly.id: history, ending.id: history, alternating.id: stillPaused]
        try Version1Store.write(to: fileURL, reminders: reminders, tags: [home], histories: histories)

        let loaded = try openAfterUpdate().load()

        var stamped = reminders
        for index in stamped.indices { stamped[index].createdAt = migrationInstant }
        #expect(loaded == StoredData(reminders: stamped, tags: [home], histories: histories))
        #expect(loaded.reminders.map(\.repeatRule) == reminders.map(\.repeatRule))
    }

    @Test func everyMigratedReminderGetsTheMigrationInstantAndKeepsItsPosition() throws {
        try Version1Store.write(to: fileURL, reminders: [rent, pills, bins], tags: [], histories: [:])

        let loaded = try openAfterUpdate().load()

        #expect(loaded.reminders.map(\.id) == [rent.id, pills.id, bins.id])
        #expect(loaded.reminders.map(\.createdAt) == Array(repeating: migrationInstant, count: 3))
    }

    /// Every 1.2.0 reminder ties on the migration instant, so the Reminders tab reads them in
    /// `position` order under Oldest First and exactly reversed under Newest First (spec #104,
    /// Decision 54).
    @Test func migratedRemindersListInPositionOrderOldestFirstAndReversedNewestFirst() throws {
        try Version1Store.write(to: fileURL, reminders: [rent, pills, bins], tags: [], histories: [:])
        var engine = Engine(clock: FakeClock(now: NewYork.local(2026, 10, 30, 13)), scheduler: FakeScheduler(), timeZone: NewYork.timeZone)
        engine.update(reminders: try openAfterUpdate().load().reminders)

        func titles(_ order: RemindersSort.Order) -> [String] {
            engine.remindersList(sortedBy: RemindersSort(field: .created, order: order)).items.map(\.reminder.title)
        }

        #expect(titles(.ascending) == [rent.title, pills.title, bins.title])
        #expect(titles(.descending) == [bins.title, pills.title, rent.title])
    }

    @Test func theMigrationInstantIsSavedOnceAndALaterLaunchLeavesItAlone() throws {
        try Version1Store.write(to: fileURL, reminders: [pills, bins], tags: [], histories: [:])
        _ = try openAfterUpdate().load()

        let later = try ReminderStore(location: .file(fileURL), now: migrationInstant.addingTimeInterval(86_400)).load()

        #expect(later.reminders.map(\.createdAt) == [migrationInstant, migrationInstant])
    }

    @Test func aReminderMadeAfterTheUpdateSortsAfterTheMigratedOnes() throws {
        try Version1Store.write(to: fileURL, reminders: [pills, bins], tags: [], histories: [:])
        let store = try openAfterUpdate()
        var data = try store.load()
        var added = rent
        added.createdAt = migrationInstant.addingTimeInterval(60)
        data.reminders.append(added)

        try store.save(data)

        let loaded = try ReminderStore(location: .file(fileURL), now: migrationInstant.addingTimeInterval(86_400)).load()
        #expect(loaded.reminders.map(\.id) == [pills.id, bins.id, rent.id])
        #expect(loaded.reminders.map(\.createdAt) == [migrationInstant, migrationInstant, added.createdAt])
    }

    @Test func anEmptyVersion1StoreOpensEmpty() throws {
        try Version1Store.write(to: fileURL, reminders: [], tags: [], histories: [:])

        #expect(try openAfterUpdate().load() == StoredData(reminders: [], tags: [], histories: [:]))
    }
}
