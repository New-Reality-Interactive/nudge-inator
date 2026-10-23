import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Settings' How It Nudges page at the Default Pace (enhancement-pace ticket 10): its intro names
/// the pace, and each strength's section is drawn at it. A class so `deinit` removes the defaults
/// each test wrote, even when it fails.
@MainActor
final class HowItNudgesPageTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let suiteName = "HowItNudgesPageTests.\(UUID().uuidString)"

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    /// A model over this test's defaults, not yet launched, as `DefaultPaceTests` makes one.
    func model() throws -> AppModel {
        let store = try ReminderStore(location: .inMemory)
        return AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: FakeNotificationCenter(), clock: clock),
            alarms: AlarmAdapter(manager: FakeAlarmManager(), clock: clock),
            defaultPaceRecord: DefaultPaceRecord(defaults: try #require(UserDefaults(suiteName: suiteName))),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
    }

    func engine() -> Engine {
        Engine(clock: clock, scheduler: FakeScheduler(), permissions: PermissionStates(alarms: .allowed))
    }

    @Test(arguments: [
        (Pace.escalating, "Below is how each strength nudges a new reminder at your Default Pace, Escalating, with Break Through Focus on."),
        (.consistent(wait: 10 * 60), "Below is how each strength nudges a new reminder at your Default Pace, Consistent · 10 min, with Break Through Focus on."),
        (.consistent(wait: 30 * 60), "Below is how each strength nudges a new reminder at your Default Pace, Consistent · 30 min, with Break Through Focus on."),
    ])
    func theIntroNamesTheDefaultPace(pace: Pace, expected: String) {
        #expect(String(localized: HowItNudgesPageContent(pace: pace, engine: engine()).intro) == expected)
    }

    /// The give-up spans are worked out in `HowItNudgesSummaryTests` and the engine's
    /// `HowItNudgesTests`: at Consistent · 10 min each strength sends 20 nudges, one wait apart,
    /// 19 × 600 + 600 = 12,000 s, and Relentless folds into one Urgent row.
    @Test func eachStrengthIsDrawnAtTheDefaultPace() {
        let escalating = HowItNudgesPageContent(pace: .escalating, engine: engine()).sections
        #expect(escalating.map(\.strength) == [.gentle, .firm, .relentless])
        #expect(escalating.map(\.howItNudges.givesUpAfter) == [29044, 8250, 3090])
        #expect(escalating.last?.howItNudges.rows.count == 4)

        let consistent = HowItNudgesPageContent(pace: .consistent(wait: 10 * 60), engine: engine()).sections
        #expect(consistent.map(\.strength) == [.gentle, .firm, .relentless])
        #expect(consistent.map(\.howItNudges.givesUpAfter) == [12_000, 12_000, 12_000])
        #expect(consistent.last?.howItNudges.rows == [
            HowItNudges.Row(nudges: 1...20, startsAfter: 0, wait: 600, urgency: .urgent, delivery: .alarm),
        ])
    }

    /// The page reads the model's Default Pace each time it's drawn, so a change shows the next
    /// time it's opened.
    @Test func aChangedDefaultPaceChangesThePage() throws {
        let model = try model()
        #expect(HowItNudgesPageContent(model: model).pace == .consistent(wait: 10 * 60))

        model.defaultPace = DefaultPace(choice: .escalating, consistentWait: 30 * 60)
        let escalating = HowItNudgesPageContent(model: model)
        #expect(escalating.pace == .escalating)
        #expect(escalating.sections.map(\.howItNudges.givesUpAfter) == [29044, 8250, 3090])

        model.defaultPace = DefaultPace(choice: .consistent, consistentWait: 30 * 60)
        #expect(HowItNudgesPageContent(model: model).pace == .consistent(wait: 30 * 60))
    }
}
