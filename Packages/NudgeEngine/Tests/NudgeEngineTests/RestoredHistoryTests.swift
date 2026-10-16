import Foundation
import Testing
@testable import NudgeEngine

/// The store saves what the clock can't work out (`engine.histories`) and hands it to a new engine
/// at launch (`update(histories:)`). A relaunched engine then reads every occurrence back as the
/// old one did.
struct RestoredHistoryTests {
    let clock = FakeClock(now: .distantPast)
    let scheduler = FakeScheduler()
    /// Every day at 9:00 from Thursday 15 October 2026.
    let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15), repeatRule: .everyDay, strength: .firm)

    func engine(for reminder: Reminder) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: [reminder])
        return engine
    }

    /// The launch order ticket 21 follows: tags, then histories, then reminders, which plans once.
    func relaunched(from old: Engine) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(tags: old.tags)
        engine.update(histories: old.histories)
        engine.update(reminders: old.reminders)
        return engine
    }

    @Test func aDoneOccurrenceStaysDoneAfterARelaunch() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var old = engine(for: pills)
        old.markDone(pills.id)

        let engine = relaunched(from: old)

        #expect(engine.latestOccurrence(for: pills.id)?.state == .done)
        #expect(engine.openOccurrence(for: pills.id) == nil)
    }

    /// Paused at 9:40 on the 15th, relaunched on the 16th: still paused, both due times Skipped,
    /// and nothing planned.
    @Test func aPauseSurvivesARelaunch() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var old = engine(for: pills)
        old.pause(pills.id)

        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        let engine = relaunched(from: old)

        #expect(engine.isPaused(pills.id))
        let states = [15, 16].map { engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, $0))?.state }
        #expect(states == [.skipped(reason: .paused), .skipped(reason: .paused)])
        #expect(try #require(scheduler.lastPlan).items.isEmpty)
    }

    /// Resumed on the 16th at 8:00, relaunched at 9:30: the pause ended, so the 16th nudges.
    @Test func aResumedPauseStaysEndedAfterARelaunch() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var old = engine(for: pills)
        old.pause(pills.id)
        clock.now = NewYork.local(2026, 10, 16, 8)
        try old.resume(pills.id)

        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        let engine = relaunched(from: old)

        #expect(!engine.isPaused(pills.id))
        #expect(engine.occurrence(of: pills.id, dueAt: NewYork.local(2026, 10, 15))?.state == .skipped(reason: .paused))
        #expect(engine.openOccurrence(for: pills.id)?.dueTime == NewYork.local(2026, 10, 16))
    }

    /// Renamed at 9:40 while nudging, relaunched at 9:41: the nudges at 9:00 and 9:30 went out with
    /// the old title, and the later ones carry the new one.
    @Test func passedNudgesKeepTheirTitleAfterARelaunch() throws {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var old = engine(for: pills)
        var renamed = pills
        renamed.title = "Take the blue pills"
        try old.edit(renamed)

        clock.now = NewYork.local(2026, 10, 15, 9, 41)
        _ = relaunched(from: old)

        let today = try #require(scheduler.lastPlan).items.filter { $0.fireTime < NewYork.local(2026, 10, 16) }
        #expect(today.prefix(2).map(\.title) == ["Take the pills", "Take the pills"])
        #expect(today.dropFirst(2).allSatisfy { $0.title == "Take the blue pills" })
    }

    /// Every day at 9:00 from the 14th, Done at 9:05 on the 15th, then moved to 18:00. Yesterday's
    /// 18:00 never happened, before the relaunch or after it.
    @Test func aDueTimeAnEditMeansNeverHappenedStaysGoneAfterARelaunch() throws {
        let since14th = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 14), repeatRule: .everyDay, strength: .firm)
        clock.now = NewYork.local(2026, 10, 15, 9, 5)
        var old = engine(for: since14th)
        old.markDone(since14th.id)
        var moved = since14th
        moved.dueTime = NewYork.local(2026, 10, 14, 18)
        try old.edit(moved)

        clock.now = NewYork.local(2026, 10, 15, 9, 10)
        let engine = relaunched(from: old)

        #expect(engine.occurrence(of: since14th.id, dueAt: NewYork.local(2026, 10, 14, 18)) == nil)
        #expect(engine.latestOccurrence(for: since14th.id)?.state == .done)
    }

    /// The alarm-limit reports aren't saved (ticket 15): histories handed to a running engine
    /// replace only what the store saves, so a reported nudge stays a marked notification.
    @Test func handingHistoriesToARunningEngineKeepsItsAlarmLimitReports() throws {
        let urgent = Reminder(title: "Leave for the airport", dueTime: NewYork.local(2026, 10, 15), strength: .relentless)
        clock.now = NewYork.local(2026, 10, 15, 8)
        var engine = engine(for: urgent)
        let nudgeFour = try #require(scheduler.lastPlan?.items.first { $0.nudgeNumber == 4 })
        engine.markAlarmLimitReached(urgent.id, firingAt: nudgeFour.fireTime)

        engine.update(histories: engine.histories)
        engine.update(reminders: [urgent])

        let item = try #require(scheduler.lastPlan?.items.first { $0.nudgeNumber == 4 })
        #expect(item.isPastAlarmLimit)
    }

    @Test func handingOverHistoriesAppliesNoPlan() {
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        var engine = engine(for: pills)
        let plansBefore = scheduler.appliedPlans.count

        engine.update(histories: [pills.id: ReminderHistory(pauseSpans: [PauseSpan(start: clock.now)])])

        #expect(scheduler.appliedPlans.count == plansBefore)
    }
}
