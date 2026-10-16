import Foundation
import Testing
@testable import NudgeEngine

/// The Now tab's three sections: what is nudging, Coming Up (the next 7 days) and the Last 24 Hours
/// (occurrences that closed, newest first).
struct NowQueriesTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 16, 6))
    let scheduler = FakeScheduler()

    func engine(holding reminders: [Reminder]) -> Engine {
        var engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return engine
    }

    /// Oldest due time first, as the mockup's `openOccs`. Done and not yet due are left out.
    @Test func nudgingListsOpenOccurrencesOldestFirst() {
        let bins = Reminder(title: "Take the bins out", dueTime: NewYork.local(2026, 10, 16, 7, 30), strength: .firm)
        let alex = Reminder(title: "Reply to Alex", dueTime: NewYork.local(2026, 10, 16, 8, 10), strength: .relentless)
        let meds = Reminder(title: "Morning meds", dueTime: NewYork.local(2026, 10, 16, 6, 30), strength: .gentle)
        let rent = Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 10, 16, 9), strength: .relentless)
        var engine = engine(holding: [alex, rent, meds, bins])
        clock.now = NewYork.local(2026, 10, 16, 7, 4)
        engine.markDone(meds.id)
        clock.now = NewYork.local(2026, 10, 16, 8, 22)
        engine.update(reminders: engine.reminders)

        let nudging = engine.nudgingOccurrences()

        #expect(nudging == [
            ReminderOccurrence(reminderID: bins.id, occurrence: Occurrence(dueTime: NewYork.local(2026, 10, 16, 7, 30), state: .nudging(nudgeNumber: 3))),
            ReminderOccurrence(reminderID: alex.id, occurrence: Occurrence(dueTime: NewYork.local(2026, 10, 16, 8, 10), state: .nudging(nudgeNumber: 2))),
        ])
    }

    /// Friday 16 October at 9:00. Coming Up runs to the same time next Friday: 9:00 on day 7 is in,
    /// 9:01 on day 7 and anything on day 8 are out. Each reminder shows only its next due time.
    @Test func comingUpIncludesDaySevenAndExcludesDayEight() {
        clock.now = NewYork.local(2026, 10, 16, 9)
        let meds = Reminder(title: "Morning meds", dueTime: NewYork.local(2026, 10, 1, 8), repeatRule: .everyDay, strength: .gentle)
        let daySeven = Reminder(title: "Day seven", dueTime: NewYork.local(2026, 10, 23, 9), strength: .firm)
        let justPast = Reminder(title: "Just past", dueTime: NewYork.local(2026, 10, 23, 9, 1), strength: .firm)
        let dayEight = Reminder(title: "Day eight", dueTime: NewYork.local(2026, 10, 24, 8), strength: .firm)
        let engine = engine(holding: [daySeven, dayEight, justPast, meds])

        let comingUp = engine.comingUp()

        #expect(comingUp == [
            ComingUpItem(reminderID: meds.id, dueTime: NewYork.local(2026, 10, 17, 8)),
            ComingUpItem(reminderID: daySeven.id, dueTime: NewYork.local(2026, 10, 23, 9)),
        ])
    }

    /// From Friday 30 October at 9:00, New York falls back on Sunday, so 9:00 next Friday is 169
    /// hours away. Seven local days still reach it; 7 × 24 hours would stop at 8:00.
    @Test func comingUpCountsLocalDaysAcrossAFallBack() {
        clock.now = NewYork.local(2026, 10, 30, 9)
        let daySeven = Reminder(title: "Day seven", dueTime: NewYork.local(2026, 11, 6, 9), strength: .firm)
        let engine = engine(holding: [daySeven])

        #expect(engine.comingUp() == [ComingUpItem(reminderID: daySeven.id, dueTime: NewYork.local(2026, 11, 6, 9))])
    }

    /// Two due at the same time go by title, as on My Day, whatever their IDs.
    @Test func comingUpBreaksTiesByTitle() throws {
        clock.now = NewYork.local(2026, 10, 16, 9)
        let dueTime = NewYork.local(2026, 10, 17, 8)
        let water = Reminder(id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")), title: "Water the plants", dueTime: dueTime, strength: .gentle)
        let feed = Reminder(id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002")), title: "Feed the cat", dueTime: dueTime, strength: .gentle)
        let engine = engine(holding: [water, feed])

        #expect(engine.comingUp().map(\.reminderID) == [feed.id, water.id])
    }

    /// A paused reminder has nothing coming up until Resume: its due times are Skipped.
    @Test func comingUpLeavesOutPausedReminders() {
        clock.now = NewYork.local(2026, 10, 16, 9)
        let grandma = Reminder(title: "Call Grandma", dueTime: NewYork.local(2026, 10, 1, 17), repeatRule: .everyDay, strength: .gentle)
        var engine = engine(holding: [grandma])

        engine.pause(grandma.id)

        #expect(engine.comingUp().isEmpty)
    }

    /// 13:00 on Friday. Relentless gives up 51 min 30 s after its due time. Meds were Done at 7:04,
    /// the stand-up gave up at 10:21:30, and Thursday's call gave up at exactly 13:00, 24 hours
    /// ago, so it's in. Thursday's earlier call gave up at 12:51:30, so it's out. Alex is still
    /// nudging. Newest first, by when each closed. Gentle's second nudge would have come at 7:30,
    /// so meds were Done after one; each give-up came after all 20.
    @Test func lastTwentyFourHoursListsWhatClosedInThePast24HoursNewestFirst() {
        let meds = Reminder(title: "Morning meds", dueTime: NewYork.local(2026, 10, 16, 6, 30), strength: .gentle)
        let standUp = Reminder(title: "Team stand-up", dueTime: NewYork.local(2026, 10, 16, 9, 30), strength: .relentless)
        let edgeCall = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 12, 8) + 30, strength: .relentless)
        let earlierCall = Reminder(title: "Call the vet", dueTime: NewYork.local(2026, 10, 15, 12), strength: .relentless)
        let alex = Reminder(title: "Reply to Alex", dueTime: NewYork.local(2026, 10, 16, 12, 30), strength: .firm)
        clock.now = NewYork.local(2026, 10, 15, 11)
        var engine = engine(holding: [alex, earlierCall, edgeCall, standUp, meds])
        clock.now = NewYork.local(2026, 10, 16, 7, 4)
        engine.markDone(meds.id)
        clock.now = NewYork.local(2026, 10, 16, 13)
        engine.update(reminders: engine.reminders)

        let closed = engine.closedInLast24Hours()

        #expect(closed == [
            ClosedOccurrence(
                reminderID: standUp.id,
                occurrence: Occurrence(dueTime: NewYork.local(2026, 10, 16, 9, 30), state: .missed(reason: .giveUpLimit)),
                closedAt: NewYork.local(2026, 10, 16, 10, 21) + 30,
                nudgesSent: 20
            ),
            ClosedOccurrence(
                reminderID: meds.id,
                occurrence: Occurrence(dueTime: NewYork.local(2026, 10, 16, 6, 30), state: .done),
                closedAt: NewYork.local(2026, 10, 16, 7, 4),
                nudgesSent: 1
            ),
            ClosedOccurrence(
                reminderID: edgeCall.id,
                occurrence: Occurrence(dueTime: NewYork.local(2026, 10, 15, 12, 8) + 30, state: .missed(reason: .giveUpLimit)),
                closedAt: NewYork.local(2026, 10, 15, 13),
                nudgesSent: 20
            ),
        ])
    }

    /// With the give-up limit widened, each 9:00 occurrence nudges until the next takes it over.
    /// Thursday's closed at 9:00 on Friday, so it's in; Wednesday's closed at 9:00 on Thursday, 28
    /// hours ago, so it's out. Friday's is still nudging. Firm nudged at +0, +30, +45 and +52.5 min,
    /// then every 5 minutes up to +1,437.5 min, the last before the take-over: 4 + 277 = 281.
    @Test func aTakenOverOccurrenceClosedWhenTheNextFellDue() {
        let widened = GiveUpLimit(nudgeCount: 10_000, span: 72 * 60 * 60)
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 14), repeatRule: .everyDay, strength: .firm)
        var engine = Engine(clock: clock, scheduler: scheduler, giveUpLimit: widened, timeZone: NewYork.timeZone)
        clock.now = NewYork.local(2026, 10, 16, 13)
        engine.update(reminders: [pills])

        #expect(engine.closedInLast24Hours() == [
            ClosedOccurrence(
                reminderID: pills.id,
                occurrence: Occurrence(dueTime: NewYork.local(2026, 10, 15), state: .missed(reason: .nextTookOver)),
                closedAt: NewYork.local(2026, 10, 16),
                nudgesSent: 281
            ),
        ])
    }

    /// The stretch break was nudging when paused at 10:10, so it closed then. Grandma was paused at
    /// 16:00 on Thursday, before her 17:00 call, which closed as it fell due, as the mockup's
    /// Skipped `o13` does, with no nudge sent. The stretch break's second nudge would have come at
    /// 10:30. Wednesday's call gave up at 1:04 on Thursday, before the window.
    @Test func aSkippedOccurrenceClosedAtThePauseOrAtItsDueTimeIfThatCameWhilePaused() {
        let stretch = Reminder(title: "Stretch break", dueTime: NewYork.local(2026, 10, 16, 10), strength: .firm)
        let grandma = Reminder(title: "Call Grandma", dueTime: NewYork.local(2026, 10, 1, 17), repeatRule: .everyDay, strength: .gentle)
        clock.now = NewYork.local(2026, 10, 15, 16)
        var engine = engine(holding: [stretch, grandma])
        engine.pause(grandma.id)
        clock.now = NewYork.local(2026, 10, 16, 10, 10)
        engine.pause(stretch.id)
        clock.now = NewYork.local(2026, 10, 16, 13)
        engine.update(reminders: engine.reminders)

        #expect(engine.closedInLast24Hours() == [
            ClosedOccurrence(
                reminderID: stretch.id,
                occurrence: Occurrence(dueTime: NewYork.local(2026, 10, 16, 10), state: .skipped(reason: .paused)),
                closedAt: NewYork.local(2026, 10, 16, 10, 10),
                nudgesSent: 1
            ),
            ClosedOccurrence(
                reminderID: grandma.id,
                occurrence: Occurrence(dueTime: NewYork.local(2026, 10, 15, 17), state: .skipped(reason: .paused)),
                closedAt: NewYork.local(2026, 10, 15, 17),
                nudgesSent: 0
            ),
        ])
    }

    /// Every day at 9:00, Done at 9:05, then moved to 18:00 at 9:30. The Edit applies from the next
    /// occurrence (ADR 0002), so this morning's Done stays in the last 24 hours, and no 18:00
    /// occurrence before the Edit is made up: yesterday's would have given up at 20:17:30.
    @Test func anEditThatMovesTheDueTimeKeepsWhatClosedAndMakesNothingUp() throws {
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 1), repeatRule: .everyDay, strength: .firm)
        var engine = engine(holding: [pills])
        clock.now = NewYork.local(2026, 10, 16, 9, 5)
        engine.markDone(pills.id)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        var evening = pills
        evening.dueTime = NewYork.local(2026, 10, 1, 18)
        try engine.edit(evening)
        clock.now = NewYork.local(2026, 10, 16, 13)

        #expect(engine.closedInLast24Hours() == [
            ClosedOccurrence(
                reminderID: pills.id,
                occurrence: Occurrence(dueTime: NewYork.local(2026, 10, 16), state: .done),
                closedAt: NewYork.local(2026, 10, 16, 9, 5),
                nudgesSent: 1
            ),
        ])
        #expect(engine.latestOccurrence(for: pills.id) == Occurrence(dueTime: NewYork.local(2026, 10, 16), state: .done))
    }

    /// Every day at 9:00, Relentless: yesterday's gave up at 9:51:30. Made Firm at 9:30 today, the
    /// clock alone would have yesterday's giving up at 11:17:30, so the Edit fixes it as it was.
    @Test func anEditThatChangesTheStrengthKeepsEarlierCloseTimes() throws {
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 1), repeatRule: .everyDay, strength: .relentless)
        var engine = engine(holding: [pills])
        clock.now = NewYork.local(2026, 10, 16, 9, 5)
        engine.markDone(pills.id)
        clock.now = NewYork.local(2026, 10, 16, 9, 30)
        var firmer = pills
        firmer.strength = .firm
        try engine.edit(firmer)
        clock.now = NewYork.local(2026, 10, 16, 9, 40)

        #expect(engine.closedInLast24Hours().map(\.closedAt) == [NewYork.local(2026, 10, 16, 9, 5), NewYork.local(2026, 10, 15, 9, 51) + 30])
    }

    /// The stand-up gave up at 10:21:30. Edited to Gentle at 11:00, the clock alone would now have
    /// it nudging until the evening, so the Edit fixes it as Missed, and it keeps its close time.
    @Test func anOccurrenceFixedByAnEditKeepsWhenItClosed() throws {
        let standUp = Reminder(title: "Team stand-up", dueTime: NewYork.local(2026, 10, 16, 9, 30), strength: .relentless)
        var engine = engine(holding: [standUp])
        clock.now = NewYork.local(2026, 10, 16, 11)
        var gentler = standUp
        gentler.strength = .gentle
        try engine.edit(gentler)
        clock.now = NewYork.local(2026, 10, 16, 13)

        #expect(engine.closedInLast24Hours().map(\.closedAt) == [NewYork.local(2026, 10, 16, 10, 21) + 30])
    }
}
