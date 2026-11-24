import Foundation
import Testing
@testable import NudgeEngine

/// The Tags tab lists every tag with how many reminders have it, how many are due today and how
/// many are nudging. A reminder with several tags counts under each.
struct TagSummaryTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 20))
    let scheduler = FakeScheduler()

    /// 6:00 on Friday 16 October. Rent has #money and #home and is nudging; the bins are due
    /// tonight; the passport is due tomorrow; last night's 23:00 call is still nudging though it
    /// isn't due today, as the Now tab shows it. #travel has no reminders.
    @Test func countsAReminderUnderEachOfItsTags() {
        let home = Tag(name: "home"), money = Tag(name: "money"), travel = Tag(name: "travel")
        let rent = Reminder(title: "Pay rent", tagIDs: [money.id, home.id], dueTime: NewYork.local(2026, 10, 16, 5, 45), strength: .relentless)
        let bins = Reminder(title: "Take the bins out", tagIDs: [home.id], dueTime: NewYork.local(2026, 10, 16, 20), strength: .firm)
        let passport = Reminder(title: "Renew passport", tagIDs: [money.id], dueTime: NewYork.local(2026, 10, 17, 9), strength: .firm)
        let call = Reminder(title: "Call the landlord", tagIDs: [home.id], dueTime: NewYork.local(2026, 10, 15, 23), strength: .gentle)
        let walk = Reminder(title: "Walk the dog", dueTime: NewYork.local(2026, 10, 16, 7), strength: .gentle)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(tags: [travel, money, home])
        engine.update(reminders: [rent, bins, passport, call, walk])
        clock.now = NewYork.local(2026, 10, 16, 6)

        #expect(engine.tagSummaries() == [
            TagSummary(tag: home, reminderCount: 3, dueTodayCount: 2, nudgingCount: 2),
            TagSummary(tag: money, reminderCount: 2, dueTodayCount: 1, nudgingCount: 1),
            TagSummary(tag: travel, reminderCount: 0, dueTodayCount: 0, nudgingCount: 0),
        ])
    }

    /// A tag's details page reads one tag with the numbers its row on the list shows.
    @Test func readsOneTagWithTheCountsItsRowShows() {
        let home = Tag(name: "home"), money = Tag(name: "money"), travel = Tag(name: "travel")
        let rent = Reminder(title: "Pay rent", tagIDs: [money.id, home.id], dueTime: NewYork.local(2026, 10, 16, 5, 45), strength: .relentless)
        let bins = Reminder(title: "Take the bins out", tagIDs: [home.id], dueTime: NewYork.local(2026, 10, 16, 20), strength: .firm)
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(tags: [travel, money, home])
        engine.update(reminders: [rent, bins])
        clock.now = NewYork.local(2026, 10, 16, 6)

        #expect(engine.tagSummary(for: home.id) == TagSummary(tag: home, reminderCount: 2, dueTodayCount: 2, nudgingCount: 1))
        #expect(engine.tagSummary(for: travel.id) == TagSummary(tag: travel, reminderCount: 0, dueTodayCount: 0, nudgingCount: 0))
        for row in engine.tagSummaries() {
            #expect(engine.tagSummary(for: row.tag.id) == row)
        }
    }

    /// A tag deleted while its page is open has no summary: the page shows Tag Deleted.
    @Test func hasNoSummaryForATagTheEngineDoesNotHold() {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(tags: [Tag(name: "home")])

        #expect(engine.tagSummary(for: Tag(name: "gone").id) == nil)
    }
}
