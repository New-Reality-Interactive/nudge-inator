import NudgeEngine
import SwiftUI

/// Stands in for `NudgeInatorApp` in the screenshots harness (`scripts/screenshots.sh`): the real
/// shell and model over the test fakes and an in-memory store, seeded with the mockup's reminders.
/// `SHOT_SCENARIO` picks the permissions. Not shipped, so it force unwraps what can't fail here.
@main
struct ShotsApp: App {
    /// What the permissions are, and whether onboarding has been finished.
    enum Scenario: String {
        /// Everything allowed.
        case app
        /// First launch, nothing asked yet.
        case onboarding
        case notificationsOff, alarmsOff, timeSensitiveOff
    }

    @State private var model: AppModel

    init() {
        let name = ProcessInfo.processInfo.environment["SHOT_SCENARIO"] ?? Scenario.app.rawValue
        guard let scenario = Scenario(rawValue: name) else { fatalError("Unknown SHOT_SCENARIO \(name)") }
        _model = State(initialValue: ShotsSeed.makeModel(scenario: scenario))
    }

    var body: some Scene {
        WindowGroup {
            if let count = ProcessInfo.processInfo.environment["SHOT_BADGE_COUNT"].flatMap(Int.init) {
                BadgeBarShot(chosen: count)
                    .environment(model)
            } else {
                RootView()
                    .environment(model)
                    .task { await ShotsSeed.launch(model) }
            }
        }
    }
}

/// My Day's bar with the Filter button at a count the seed can't reach (12, 999), since choosing
/// that many tags takes as many taps. `SHOT_BADGE_COUNT` picks it. The bar is the real one: the
/// Filter button and New Reminder, with My Day's title.
struct BadgeBarShot: View {
    let chosen: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
                .navigationTitle("My Day")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        MyDayFilterButton(chosen: chosen, showsBadge: !dynamicTypeSize.isAccessibilitySize) {}
                    }
                    ToolbarItem(placement: .primaryAction) { NewReminderButton() }
                }
        }
    }
}

/// The real clock, except while seeding, when the seed sets the time of each Done and Pause.
final class ShotsClock: EngineClock {
    var frozenNow: Date?
    var now: Date { frozenNow ?? .now }
}

@MainActor
enum ShotsSeed {
    static let clock = ShotsClock()
    /// The root view's `task` can run again; the data goes in once.
    private static var isSeeded = false

    static func makeModel(scenario: ShotsApp.Scenario) -> AppModel {
        let center = FakeNotificationCenter()
        let manager = FakeAlarmManager()
        let defaults = UserDefaults(suiteName: "shots")!
        defaults.removePersistentDomain(forName: "shots")
        let onboarding = OnboardingRecord(defaults: defaults)
        onboarding.isFinished = scenario != .onboarding
        switch scenario {
        case .onboarding:
            manager.authorizationState = .notDetermined
        case .notificationsOff:
            center.settings = NotificationSettingsSnapshot(authorizationStatus: .denied, timeSensitiveSetting: .disabled)
        case .alarmsOff:
            center.settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: .enabled)
            manager.authorizationState = .denied
        case .timeSensitiveOff:
            center.settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: .disabled)
        case .app:
            center.settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: .enabled)
        }
        let store = try! ReminderStore(location: .inMemory)
        let model = AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: center, clock: clock),
            alarms: AlarmAdapter(manager: manager, clock: clock),
            onboardingRecord: onboarding,
            defaultPaceRecord: DefaultPaceRecord(defaults: defaults),
            doneQueue: .temporary
        )
        return model
    }

    static func launch(_ model: AppModel) async {
        await model.launch()
        if !isSeeded {
            isSeeded = true
            seedMockupData(into: model)
        }
        await model.appOpened()
    }

    /// The mockup's reminders (its `seed()`) and their paces (the rest Escalating), with the
    /// mockup's 8:20 AM as now. Times are now plus or minus the mockup's gaps, so the screens show
    /// the same states whenever this runs.
    static func seedMockupData(into model: AppModel) {
        let now = Calendar.current.dateInterval(of: .minute, for: .now)!.start
        func at(_ minutes: Double, days: Double = 0) -> Date {
            now.addingTimeInterval(minutes * 60 + days * 86_400)
        }
        var tags: [String: Tag.ID] = [:]
        for name in ["home", "health", "work", "money", "morning", "appointments", "travel"] {
            tags[name] = try! model.createTag(named: name)!.id
        }
        func tagged(_ names: String...) -> [Tag.ID] { names.map { tags[$0]! } }
        let everyThreeDays = RepeatRule(frequency: .daily, interval: 3)!

        // 7:30 AM every week, every 30 min, so on nudge 2 since 8:00 and High at 8:30; last week's
        // was Done at 7:52.
        let bins = Reminder(title: "Take the bins out", tagIDs: tagged("home"), dueTime: at(-50, days: -7), repeatRule: .everyWeek, strength: .firm, pace: .consistent(wait: 30 * 60))
        // 8:10 AM today, nudging.
        let alex = Reminder(title: "Reply to Alex about the lease", notes: "They need an answer before 10.", tagIDs: tagged("money", "home"), dueTime: at(-10), strength: .relentless)
        // 6:30 AM every day, every 15 min, Done at 7:04.
        let meds = Reminder(title: "Morning meds", notes: "Blue pill + vitamin D", tagIDs: tagged("health", "morning"), dueTime: at(-110, days: -1), repeatRule: .everyDay, strength: .gentle, pace: .consistent(wait: 15 * 60))
        // 10:00 AM every day; yesterday's gave up.
        let stretch = Reminder(title: "Stretch break", tagIDs: tagged("health", "work"), dueTime: at(100, days: -1), repeatRule: .everyDay, strength: .firm)
        // 6:00 PM every 3 days, Break Through Focus off.
        let plants = Reminder(title: "Water the plants", tagIDs: tagged("home"), dueTime: at(580), repeatRule: everyThreeDays, strength: .gentle, breakThroughFocus: false)
        // 9:00 AM on the 1st of each month, in 3 days.
        let rent = Reminder(title: "Pay rent", notes: "Transfer to the landlord's account.", tagIDs: tagged("money", "home"), dueTime: at(40, days: 3), repeatRule: .everyMonth, strength: .relentless)
        // 1:15 PM in 4 days, every 10 min.
        let dentist = Reminder(title: "Dentist appointment", notes: "Bring the insurance card.", tagIDs: tagged("health", "appointments"), dueTime: at(295, days: 4), strength: .firm, pace: .consistent(wait: 10 * 60))
        // 18 days ago, Done after 41 minutes.
        let passport = Reminder(title: "Renew passport", tagIDs: tagged("money", "travel"), dueTime: at(40, days: -18), strength: .firm)
        // 9:30 AM every weekday, every 5 min.
        let standUp = Reminder(title: "Team stand-up", notes: "Join from the meeting link in the calendar invite.", tagIDs: tagged("work", "morning"), dueTime: at(70), repeatRule: .everyWeekday, strength: .firm, pace: .consistent(wait: 5 * 60))
        // 4:30 PM every week.
        let status = Reminder(title: "Send the weekly status update", tagIDs: tagged("work"), dueTime: at(490), repeatRule: .everyWeek, strength: .gentle)
        // 7:00 AM every day, Break Through Focus off, Done at 7:18.
        let dog = Reminder(title: "Walk the dog", tagIDs: tagged("home", "morning"), dueTime: at(-80, days: -1), repeatRule: .everyDay, strength: .gentle, breakThroughFocus: false)
        // 5:00 PM every week, paused before yesterday's.
        let grandma = Reminder(title: "Call Grandma", dueTime: at(520, days: -8), repeatRule: .everyWeek, strength: .gentle)

        clock.frozenNow = at(-200, days: -18)
        for reminder in [bins, alex, meds, stretch, plants, rent, dentist, passport, standUp, status, dog, grandma] {
            model.add(reminder)
        }
        clock.frozenNow = at(81, days: -18)
        model.markDone(passport.id)
        clock.frozenNow = at(-28, days: -7)
        model.markDone(bins.id)
        clock.frozenNow = at(-60, days: -1)
        model.markDone(meds.id)
        model.markDone(dog.id)
        clock.frozenNow = at(-15, days: -1)
        model.pause(grandma.id)
        clock.frozenNow = at(-76)
        model.markDone(meds.id)
        clock.frozenNow = at(-62)
        model.markDone(dog.id)
        clock.frozenNow = nil
    }
}
