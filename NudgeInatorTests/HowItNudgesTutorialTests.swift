import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The How It Nudges sheet (#470), against the approved tutorial sheets mockup,
/// `docs/mockups/2026-11-20-tutorial-sheets/`: the welcome's points, then a page per strength drawn
/// at the Default Pace with Break Through Focus on. A class so `deinit` removes the defaults each
/// test wrote, even when it fails.
@MainActor
final class HowItNudgesTutorialTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let suiteName = "HowItNudgesTutorialTests.\(UUID().uuidString)"

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    func engine() -> Engine {
        Engine(clock: clock, scheduler: FakeScheduler(), permissions: PermissionStates(alarms: .allowed))
    }

    @Test func theFourPagesShowInOrder() {
        let pages = HowItNudgesTutorialPage.pages(pace: .escalating, engine: engine())
        #expect(pages.map { String(localized: $0.heading) } == ["What to Expect", "Gentle", "Firm", "Relentless"])
        #expect(String(localized: HowItNudgesTutorialPage.title) == "How It Nudges")
    }

    /// The mockup's first page: a nudge until Done, then the welcome's four points as rows, with
    /// #459's line under the alarms point alone.
    @Test func whatToExpectListsTheWelcomesPoints() {
        let page = HowItNudgesTutorialPage.whatToExpect
        #expect(page.art.map(\.described) == ["bell Nudge", "→", "checkmark.circle.fill Done"])
        guard case .points(let lead, let points, let footnote) = page.content else {
            Issue.record("What to Expect isn't a page of points")
            return
        }
        #expect(lead == nil)
        #expect(footnote == nil)
        #expect(points.map { [$0.symbol, String(localized: $0.title), String(localized: $0.text), $0.note.map { String(localized: $0) } ?? ""] } == [
            ["bell", "Nudges until you're done", "Reminders keep coming back until you tap Done: at a steady pace, or more often and more insistently.", ""],
            ["alarm", "Urgent nudges ring as alarms", "When it really matters, your iPhone rings and vibrates like an alarm, even on silent and in a Focus. Stopping the alarm only quiets it: the next nudge still comes, and only Done ends the reminder.",
             "Choose the sound alarms ring with in Settings, under Default Alarm Sound, and for each reminder, under Sound on its form."],
            ["moon.fill", "You choose what breaks through", "Each Gentle or Firm reminder has a Break Through Focus switch. Turn it off and a Focus can hold its nudges, and nothing rings. Relentless always breaks through.", ""],
            ["lock", "Stays on your iPhone", "Your own reminders stay on this iPhone. Reminders you send or receive via an approved share, go through your iCloud. There's no account and no server of ours involved.", ""],
        ])
    }

    /// Each strength page as the mockups draw it: a pill of the strength's bars
    /// (`2026-11-20-how-it-nudges-strength-pills`), its line, the pace it's drawn
    /// at, and its schedule. The give-up spans are worked out in `HowItNudgesSummaryTests` and the
    /// engine's `HowItNudgesTests`: at Consistent · 10 min each strength sends 20 nudges, one wait
    /// apart, 19 × 600 + 600 = 12,000 s, and Relentless folds into one Urgent row.
    @Test func eachStrengthPageShowsItsScheduleAtTheDefaultPace() throws {
        let escalating = try strengthPages(HowItNudgesTutorialPage.pages(pace: .escalating, engine: engine()))
        #expect(escalating.map(\.art) == [["bars Gentle"], ["bars Firm"], ["bars Relentless"]])
        #expect(escalating.map(\.lead) == ["Never rings as an alarm.", "Rings as an alarm from nudge 4.", "Every nudge rings as an alarm."])
        #expect(escalating.map(\.note) == Array(repeating: "At your Default Pace, Escalating, with Break Through Focus on.", count: 3))
        #expect(escalating.map(\.schedule.givesUpAfter) == [29044, 8250, 3090])
        #expect(escalating.last?.schedule.rows.count == 4)

        let consistent = try strengthPages(HowItNudgesTutorialPage.pages(pace: .consistent(wait: 10 * 60), engine: engine()))
        #expect(consistent.map(\.note) == Array(repeating: "At your Default Pace, Consistent · 10 min, with Break Through Focus on.", count: 3))
        #expect(consistent.map(\.schedule.givesUpAfter) == [12_000, 12_000, 12_000])
        #expect(consistent.last?.schedule.rows == [
            HowItNudges.Row(nudges: 1...20, startsAfter: 0, wait: 600, urgency: .urgent, delivery: .alarm),
        ])
    }

    /// The sheet's pages are built from the model's Default Pace as it opens, so a change shows the
    /// next time it's opened.
    @Test func aChangedDefaultPaceChangesTheNextOpening() throws {
        let model = try model()
        #expect(try strengthPages(HowItNudgesTutorialPage.pages(model: model)).map(\.note).first == "At your Default Pace, Consistent · 10 min, with Break Through Focus on.")

        model.defaultPace = DefaultPace(choice: .escalating, consistentWait: 30 * 60)
        let escalating = try strengthPages(HowItNudgesTutorialPage.pages(model: model))
        #expect(escalating.map(\.note).first == "At your Default Pace, Escalating, with Break Through Focus on.")
        #expect(escalating.map(\.schedule.givesUpAfter) == [29044, 8250, 3090])

        model.defaultPace = DefaultPace(choice: .consistent, consistentWait: 30 * 60)
        #expect(try strengthPages(HowItNudgesTutorialPage.pages(model: model)).map(\.note).first == "At your Default Pace, Consistent · 30 min, with Break Through Focus on.")
    }

    /// The shared paging over four pages: the dots count four, and the fourth is the last.
    @Test func nextAndBackMoveOverTheFourPages() {
        var paging = TutorialPaging(pages: HowItNudgesTutorialPage.pages(pace: .escalating, engine: engine()))
        #expect(paging.page == .whatToExpect)
        #expect(!paging.canGoBack)
        #expect(String(localized: paging.position) == "Page 1 of 4")

        paging.goForward()
        paging.goForward()
        paging.goForward()
        #expect(String(localized: paging.heading) == "Relentless")
        #expect(paging.isLastPage)
        #expect(String(localized: paging.position) == "Page 4 of 4")
        paging.goForward()
        #expect(paging.pageIndex == 3)

        paging.goBack()
        #expect(String(localized: paging.heading) == "Firm")
        #expect(!paging.isLastPage)
        paging.pageIndex = 9
        #expect(paging.pageIndex == 2)
        paging.pageIndex = 0
        paging.goBack()
        #expect(paging.page == .whatToExpect)
    }

    /// A model over this test's defaults, not yet launched, as `DefaultPaceTests` makes one.
    func model() throws -> AppModel {
        let store = try ReminderStore(location: .inMemory)
        return AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: FakeNotificationCenter(), clock: clock),
            alarms: AlarmAdapter(manager: FakeAlarmManager(), clock: clock),
            settingsRecords: .temporary(defaultPace: DefaultPaceRecord(defaults: try #require(UserDefaults(suiteName: suiteName)))),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
    }

    /// The three strength pages after What to Expect, as the tests read them.
    func strengthPages(_ pages: [HowItNudgesTutorialPage]) throws -> [(art: [String], lead: String, note: String, schedule: HowItNudges)] {
        try #require(pages.count == 4)
        return try pages.dropFirst().map { page in
            guard case .schedule(let lead, let note, let schedule) = page.content else {
                throw StrengthPageError.notASchedule
            }
            return (page.art.map(\.described), String(localized: lead), String(localized: note), schedule)
        }
    }

    enum StrengthPageError: Error {
        case notASchedule
    }
}

extension TutorialPaging {
    /// The page on screen's heading.
    fileprivate var heading: LocalizedStringResource { page.heading }
}
