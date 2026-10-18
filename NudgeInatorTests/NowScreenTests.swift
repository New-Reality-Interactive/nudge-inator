import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The Now tab through `NowScreen`, what it draws, read from the real app model (in-memory store,
/// real adapters over the fakes). Tests assert on the sections' items and their text, and on the
/// fakes after Done. Layout, the wide card, swipe actions, VoiceOver and Dynamic Type are
/// screenshot and device checks.
@MainActor
struct NowScreenTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 16, 7))
    let center = FakeNotificationCenter()
    let manager = FakeAlarmManager()

    /// Every day at 8:00 since 1 October, Gentle. Yesterday's gave up at 16:04:04, after 20
    /// nudges; today's is nudging from 8:00.
    let meds = Reminder(title: "Morning meds", dueTime: NewYork.local(2026, 10, 1, 8), repeatRule: .everyDay, strength: .gentle)
    /// Today at 9:00, once, Firm.
    let bins = Reminder(title: "Take the bins out", dueTime: NewYork.local(2026, 10, 16, 9), strength: .firm)
    /// Tuesday 20 October at 9:00, once, Relentless.
    let rent = Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 10, 20, 9), strength: .relentless)
    /// Today at 7:00, once, Gentle: Done at 7:30, after its first nudge.
    let walk = Reminder(title: "Walk the dog", dueTime: NewYork.local(2026, 10, 16, 7), strength: .gentle)

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

    /// The text as it shows, without its Markdown.
    func plain(_ resource: LocalizedStringResource) -> String {
        String(AttributedString(localized: resource).characters)
    }

    /// The fixture at 9:40 on Friday 16 October, with the walk Done at 7:30.
    func modelAtNineForty() async throws -> AppModel {
        let model = try await launchedModel()
        for reminder in [rent, walk, bins, meds] { model.add(reminder) }
        clock.now = NewYork.local(2026, 10, 16, 7, 30)
        model.markDone(walk.id)
        clock.now = NewYork.local(2026, 10, 16, 9, 40)
        await model.appOpened()
        await model.waitUntilApplied()
        return model
    }

    /// The mockup's `viewNow`: nudging oldest due first, Coming Up soonest first, and the Last 24
    /// Hours newest close first.
    @Test func theThreeSectionsListTheirItemsInTheMockupsOrder() async throws {
        let model = try await modelAtNineForty()

        let screen = NowScreen(engine: model.engine)

        #expect(screen.nudging.map(\.title) == ["Morning meds", "Take the bins out"])
        #expect(screen.comingUp.map(\.title) == ["Morning meds", "Pay rent"])
        #expect(screen.comingUp.map(\.dueTime) == [NewYork.local(2026, 10, 17, 8), NewYork.local(2026, 10, 20, 9)])
        #expect(screen.lastDay.map(\.title) == ["Walk the dog", "Morning meds"])
    }

    /// Done on the bins' card, as its button and swipe action send it. At 9:40 the bins have sent
    /// nudges 1 and 2, with nudge 3 (Time Sensitive) and 4–20 (alarms) pending. The meds' pending
    /// notifications and the rent's alarms on Tuesday stay.
    @Test func doneOnACardClosesItsOccurrenceAndCancelsOnlyItsPendingNudges() async throws {
        let model = try await modelAtNineForty()
        let card = try #require(NowScreen(engine: model.engine).nudging.first { $0.title == "Take the bins out" })
        #expect(center.pending.contains { $0.identifier.contains(bins.id.uuidString) })
        #expect(manager.scheduled.contains { $0.fireDate.map { $0 < NewYork.local(2026, 10, 17) } ?? false })

        model.markDone(card.id)
        await model.waitUntilApplied()

        let screen = NowScreen(engine: model.engine)
        #expect(model.engine.closedOccurrence(of: bins.id, dueAt: bins.dueTime)?.occurrence.state == .done)
        #expect(screen.nudging.map(\.title) == ["Morning meds"])
        let closed = try #require(screen.lastDay.first)
        #expect(closed.title == "Take the bins out")
        #expect(String(localized: closed.detail) == "Done after 2 nudges")
        #expect(!center.pending.contains { $0.identifier.contains(bins.id.uuidString) })
        #expect(center.pending.contains { $0.identifier.contains(meds.id.uuidString) })
        #expect(manager.scheduled.count == 17)
        #expect(manager.scheduled.allSatisfy { $0.fireDate.map { $0 >= rent.dueTime } ?? false })
    }

    /// The mockup's `closedLabel` and `closedWhy`, with the take-over distinct from the give-up
    /// limit. With the shipped limit a daily repeat gives up long before the next falls due, so no
    /// fixture can reach a take-over through the model; the row's text is checked for each state.
    @Test(arguments: [
        (OccurrenceState.done, 1, "Done after 1 nudge", "Done"),
        (.done, 3, "Done after 3 nudges", "Done"),
        (.missed(reason: .giveUpLimit), 20, "Missed: gave up after the limit", "Missed"),
        (.missed(reason: .nextTookOver), 12, "Missed: the next one took over", "Missed"),
        (.skipped(reason: .paused), 2, "Skipped: the reminder was paused", "Skipped"),
    ])
    func aClosedRowSaysHowItClosed(state: OccurrenceState, nudgesSent: Int, detail: String, status: String) {
        #expect(String(localized: ClosedRow.detail(closingAs: state, nudgesSent: nudgesSent)) == detail)
        #expect(String(localized: ClosedRow.status(closingAs: state)) == status)
    }

    /// The time columns, the card's tag line and its times, in the engine's time zone (New York),
    /// as the repeat summary writes them. The simulator is en_US.
    @Test func theCardsAndRowsReadTheirTimesAsTheEngineWritesThem() async throws {
        let model = try await modelAtNineForty()
        let home = try #require(try model.createTag(named: "home"))
        var tagged = bins
        tagged.tagIDs = [home.id]
        try model.edit(tagged)

        let screen = NowScreen(engine: model.engine)

        let meds = try #require(screen.nudging.first)
        let bins = try #require(screen.nudging.last)
        #expect(String(localized: meds.detail) == "Due 8:00\u{202F}AM")
        #expect(String(localized: bins.detail) == "#home · due 9:00\u{202F}AM")
        #expect(bins.nextNudgeTime == "9:45\u{202F}AM")
        #expect(bins.missedAtTime == "11:17\u{202F}AM")
        let comingUp = try #require(screen.comingUp.first)
        #expect([comingUp.day, comingUp.time, comingUp.schedule] == ["Tomorrow", "8:00\u{202F}AM", "Every day at 8:00\u{202F}AM"])
        let closed = try #require(screen.lastDay.first)
        #expect([closed.day, closed.time] == ["Today", "7:30\u{202F}AM"])
    }

    /// Nothing nudging, nothing in the next 7 days and nothing closed: every section is empty, the
    /// subhead says so and the badge is hidden.
    @Test func withNothingNudgingEverySectionIsEmpty() async throws {
        let model = try await launchedModel()
        model.add(Reminder(title: "Renew the passport", dueTime: NewYork.local(2026, 10, 30, 9), strength: .gentle))

        let screen = NowScreen(engine: model.engine)

        #expect(screen.nudging.isEmpty && screen.comingUp.isEmpty && screen.lastDay.isEmpty)
        #expect(screen.badgeCount == 0)
        #expect(plain(screen.subhead(on: clock.now)) == "Fri, Oct 16 · Nothing is nudging you")
    }

    /// The mockup's subhead counts the nudging reminders, as the tab's badge does.
    @Test func theSubheadAndTheBadgeCountWhatIsNudging() async throws {
        let model = try await modelAtNineForty()
        let two = NowScreen(engine: model.engine)
        model.pause(bins.id)
        let one = NowScreen(engine: model.engine)

        #expect(two.badgeCount == 2)
        #expect(plain(two.subhead(on: clock.now)) == "Fri, Oct 16 · 2 reminders nudging you")
        #expect(one.badgeCount == 1)
        #expect(plain(one.subhead(on: clock.now)) == "Fri, Oct 16 · 1 reminder nudging you")
    }

    /// The mockup's `viaLabel`: how the next nudge arrives, and why when it's weaker than its
    /// urgency. Time Sensitive and ordinary notifications both read "Notification".
    @Test(arguments: [
        (NudgeDelivery.alarm, "Alarm"),
        (.notification(fallback: nil), "Notification"),
        (.notification(fallback: .alarmsOff), "Notification: alarms are off"),
        (.notification(fallback: .alarmsAndTimeSensitiveOff), "Notification: alarms and Time Sensitive are off"),
        (.notification(fallback: .timeSensitiveOff), "Notification: Time Sensitive is off"),
        (.notification(fallback: .breakThroughFocusOff), "Notification: Break through Focus is off"),
        (.notification(fallback: .pastAlarmLimit), "Notification: too many alarms scheduled"),
        (.cannotArrive, "Notifications off"),
    ])
    func theViaLabelSaysHowTheNextNudgeArrives(delivery: NudgeDelivery, text: String) {
        #expect(String(localized: NudgeCard.via(delivery)) == text)
    }

    /// Yesterday's meds gave up at 16:04:04; the bins, paused at 9:40, closed as Skipped then.
    @Test func missedAndSkippedOccurrencesAppearUnderTheLast24HoursWithTheirReasons() async throws {
        let model = try await modelAtNineForty()
        model.pause(bins.id)

        let rows = NowScreen(engine: model.engine).lastDay.map { "\($0.title): \(String(localized: $0.detail))" }

        #expect(rows == [
            "Take the bins out: Skipped: the reminder was paused",
            "Walk the dog: Done after 1 nudge",
            "Morning meds: Missed: gave up after the limit",
        ])
    }
}
