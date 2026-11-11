import Foundation
import Testing
@testable import NudgeEngine

/// What the engine reports about a received reminder for its sender: its status label now, and each
/// occurrence's for today and the 7 days before (spec #127, Status).
struct StatusReportTests {
    let clock = FakeClock(now: .distantPast)
    let scheduler = FakeScheduler()
    let connectionID = UUID()

    /// Every day at `time` from `firstDay` October 2026, received, Firm.
    func daily(
        from firstDay: Int = 15,
        at time: (hour: Int, minute: Int) = (9, 0),
        state: ReminderOrigin.ReceivedState = .accepted
    ) -> Reminder {
        Reminder(
            title: "Take the pills",
            dueTime: NewYork.local(2026, 10, firstDay, time.hour, time.minute),
            repeatRule: .everyDay,
            strength: .firm,
            origin: .received(connectionID: connectionID, sendersReminderID: UUID(), revision: 1, state: state)
        )
    }

    /// Due at 9:00 on 15 October 2026, received, never repeating.
    func oneOff(state: ReminderOrigin.ReceivedState = .accepted) -> Reminder {
        var reminder = daily(state: state)
        reminder.repeatRule = nil
        return reminder
    }

    func engine(holding reminders: Reminder...) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return engine
    }

    // MARK: Current status label

    @Test func aReceivedReminderBeforeItsFirstDueTimeIsComingUp() {
        let reminder = daily()
        let engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 15, 8)
        #expect(engine.statusReport(of: reminder.id)?.label == .comingUp)
    }

    @Test func aReceivedReminderThatHasComeDueIsNudgingUntilItIsDone() {
        let reminder = daily()
        var engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 15, 9, 30)
        #expect(engine.statusReport(of: reminder.id)?.label == .nudging)

        engine.markDone(reminder.id)
        // Done today, and the next is ahead.
        #expect(engine.statusReport(of: reminder.id)?.label == .comingUp)
    }

    @Test func anOneOffReadsDoneOnceItIsDone() {
        let reminder = oneOff()
        var engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 15, 9, 30)
        engine.markDone(reminder.id)
        #expect(engine.statusReport(of: reminder.id)?.label == .done)
    }

    @Test func anOneOffReadsMissedOnceItsGiveUpLimitHasPassed() {
        let reminder = oneOff()
        let engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 15, 11, 20)
        #expect(engine.statusReport(of: reminder.id)?.label == .missed)
    }

    @Test func aPausedReceivedReminderIsPaused() {
        let reminder = daily()
        var engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        engine.pause(reminder.id)
        #expect(engine.statusReport(of: reminder.id)?.label == .paused)
    }

    @Test func anOneOffThatFellDueWhileWaitingToBeAcceptedIsSkipped() {
        let reminder = oneOff(state: .waiting)
        let engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 15, 12)
        #expect(engine.statusReport(of: reminder.id)?.label == .skipped)
    }

    @Test func aPersonalReminderHasNoReport() {
        var reminder = daily()
        reminder.origin = .mine
        let engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 15, 9, 30)
        #expect(engine.statusReport(of: reminder.id) == nil)
    }

    @Test func aReminderTheEngineDoesNotHoldHasNoReport() {
        let engine = engine()
        #expect(engine.statusReport(of: UUID()) == nil)
    }

    // MARK: The last 7 days

    @Test func aRepeatingReminderReportsTodayAndEachOfTheSevenDaysBefore() throws {
        let reminder = daily(from: 1)
        let engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 22, 9, 30)

        let report = try #require(engine.statusReport(of: reminder.id))
        #expect(report.occurrences.map(\.day) == (15...22).map { CalendarDay(year: 2026, month: 10, day: $0) })
        #expect(report.occurrences.map(\.dueTime) == (15...22).map { NewYork.local(2026, 10, $0) })
        // Each past one gave up before the next fell due; today's is still Nudging.
        #expect(report.occurrences.map(\.label) == Array(repeating: .missed, count: 7) + [.nudging])
    }

    @Test func eachDaysOccurrenceReadsAsTheEngineReadsItForThePerson() throws {
        let reminder = daily(from: 1)
        var engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 18, 9, 30)
        engine.markDone(reminder.id)
        clock.now = NewYork.local(2026, 10, 20, 12)

        // The 13th to the 20th, the 18th Done.
        let report = try #require(engine.statusReport(of: reminder.id))
        #expect(report.occurrences.map(\.label) == [.missed, .missed, .missed, .missed, .missed, .done, .missed, .missed])
        let engineReading = report.occurrences.map { engine.occurrence(of: reminder.id, dueAt: $0.dueTime).map { ReportedStatus($0.state) } }
        #expect(report.occurrences.map(\.label) == engineReading)
    }

    @Test func aRepeatingReminderSentThreeDaysAgoReportsOnlyTheDaysItHas() throws {
        let reminder = daily(from: 20)
        let engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 22, 9, 30)

        let report = try #require(engine.statusReport(of: reminder.id))
        #expect(report.occurrences.map(\.day.day) == [20, 21, 22])
    }

    @Test func anOneOffReportsOnlyItsOwnOccurrence() throws {
        let reminder = oneOff()
        let engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 17, 12)

        let report = try #require(engine.statusReport(of: reminder.id))
        #expect(report.occurrences == [
            StatusReport.OccurrenceStatus(dueTime: NewYork.local(2026, 10, 15), day: CalendarDay(year: 2026, month: 10, day: 15), label: .missed),
        ])
    }

    @Test func anOneOffReportsNothingOnceItsDayIsMoreThanSevenDaysBack() throws {
        let reminder = oneOff()
        let engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 23, 12)

        let report = try #require(engine.statusReport(of: reminder.id))
        #expect(report.occurrences.isEmpty)
        #expect(report.label == .missed)
    }

    @Test func todaysOccurrenceDueLaterTodayIsComingUpOrPausedIfTheReminderIs() throws {
        let reminder = daily(from: 21)
        var engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 22, 8)
        #expect(try #require(engine.statusReport(of: reminder.id)).occurrences.map(\.label) == [.missed, .comingUp])

        engine.pause(reminder.id)
        #expect(try #require(engine.statusReport(of: reminder.id)).occurrences.map(\.label) == [.missed, .paused])
    }

    // MARK: Across midnight and a change of day

    @Test func theWindowMovesOnAtMidnight() throws {
        let reminder = daily(from: 1)
        let engine = engine(holding: reminder)

        clock.now = NewYork.local(2026, 10, 22, 23, 59)
        #expect(try #require(engine.statusReport(of: reminder.id)).occurrences.map(\.day.day) == Array(15...22))

        clock.now = NewYork.local(2026, 10, 23, 0, 1)
        let report = try #require(engine.statusReport(of: reminder.id))
        #expect(report.occurrences.map(\.day.day) == Array(16...23))
        #expect(report.occurrences.last?.label == .comingUp)
    }

    /// New York's clocks go back at 2:00 on 1 November 2026, so that day has 25 hours: a window made
    /// of 24-hour days would start at 1:00 on 26 October and lose its 0:30 occurrence.
    @Test func theWindowCountsCalendarDaysAcrossAChangeOfDay() throws {
        let reminder = daily(from: 1, at: (0, 30))
        let engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 11, 2, 10)

        let report = try #require(engine.statusReport(of: reminder.id))
        let days = report.occurrences.map(\.day)
        #expect(days.first == CalendarDay(year: 2026, month: 10, day: 26))
        #expect(days.last == CalendarDay(year: 2026, month: 11, day: 2))
        #expect(days.count == 8)
        #expect(report.occurrences.map(\.dueTime) == [
            NewYork.local(2026, 10, 26, 0, 30), NewYork.local(2026, 10, 27, 0, 30), NewYork.local(2026, 10, 28, 0, 30),
            NewYork.local(2026, 10, 29, 0, 30), NewYork.local(2026, 10, 30, 0, 30), NewYork.local(2026, 10, 31, 0, 30),
            NewYork.local(2026, 11, 1, 0, 30), NewYork.local(2026, 11, 2, 0, 30),
        ])
    }

    // MARK: Missed

    @Test func anOccurrenceReadsNudgingUntilTheEngineWorksOutItsCloseThenMissed() throws {
        let reminder = oneOff()
        let engine = engine(holding: reminder)

        // Firm gives up 2 h 17 min 30 s after the due time.
        clock.now = NewYork.local(2026, 10, 15, 11, 17)
        #expect(try #require(engine.statusReport(of: reminder.id)).occurrences.map(\.label) == [.nudging])

        // Asked long after, it is Missed all the same.
        clock.now = NewYork.local(2026, 10, 17, 8)
        let report = try #require(engine.statusReport(of: reminder.id))
        #expect(report.occurrences.map(\.label) == [.missed])
        #expect(report.label == .missed)
    }

    // MARK: Accepting and the sender's revision

    @Test func theDaysBeforeAcceptingARepeatingCopyReadSkipped() throws {
        let reminder = daily(from: 18, state: .waiting)
        var engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 20, 9, 30)
        engine.accept(reminder.id)
        clock.now = NewYork.local(2026, 10, 21, 12)

        let report = try #require(engine.statusReport(of: reminder.id))
        // Accepted at 9:30 on the 20th, so the 21st's is the first it nudges.
        #expect(report.occurrences.map(\.label) == [.skipped, .skipped, .skipped, .missed])
    }

    @Test func aSendersRevisionClosesTheNudgingOccurrenceAsSkipped() throws {
        let reminder = daily(from: 22)
        var engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 22, 9, 30)
        var revised = reminder
        revised.strength = .gentle
        if case let .received(connectionID, sendersReminderID, _, state) = reminder.origin {
            revised.origin = .received(connectionID: connectionID, sendersReminderID: sendersReminderID, revision: 2, state: state)
        }
        _ = engine.applySendersRevision(revised)

        let report = try #require(engine.statusReport(of: reminder.id))
        #expect(report.occurrences.map(\.label) == [.skipped])
        // Nothing more is due today, so the copy reads as it does after a pause's Skipped.
        #expect(report.label == .comingUp)
    }

    @Test func aRepeatingCopyNotYetAcceptedReadsItsDaysSoFarSkipped() throws {
        let reminder = daily(from: 20, state: .waiting)
        let engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 22, 12)

        let report = try #require(engine.statusReport(of: reminder.id))
        #expect(report.occurrences.map(\.label) == [.skipped, .skipped, .skipped])
    }

    @Test func anOneOffAcceptedLateReportsItsOccurrenceAtTheMomentOfAcceptance() throws {
        let reminder = oneOff(state: .waiting)
        var engine = engine(holding: reminder)
        clock.now = NewYork.local(2026, 10, 16, 14)
        engine.accept(reminder.id)

        let report = try #require(engine.statusReport(of: reminder.id))
        #expect(report.label == .nudging)
        #expect(report.occurrences == [
            StatusReport.OccurrenceStatus(dueTime: NewYork.local(2026, 10, 16, 14), day: CalendarDay(year: 2026, month: 10, day: 16), label: .nudging),
        ])
    }
}
