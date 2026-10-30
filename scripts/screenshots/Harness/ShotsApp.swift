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
        /// Everything allowed but badges: turned off in iOS Settings, or never asked for, as on an
        /// install upgraded from 1.1.0 (#86).
        case badgesOff, badgesNotSet
        /// Everything allowed, plus a Custom reminder that starts nudging a minute or two after
        /// launch, so its Custom page can be open as it locks (ticket 16). `SHOT_DARK` shows it dark.
        case customLocking
        /// Everything allowed, and no reminder at all: the Reminders tab's first empty state.
        case noReminders
    }

    @State private var model: AppModel

    init() {
        let name = ProcessInfo.processInfo.environment["SHOT_SCENARIO"] ?? Scenario.app.rawValue
        guard let scenario = Scenario(rawValue: name) else { fatalError("Unknown SHOT_SCENARIO \(name)") }
        self.scenario = scenario
        _model = State(initialValue: ShotsSeed.makeModel(scenario: scenario))
    }

    private let scenario: Scenario

    var body: some Scene {
        WindowGroup {
            if let count = ProcessInfo.processInfo.environment["SHOT_BADGE_COUNT"].flatMap(Int.init) {
                BadgeBarShot(chosen: count)
                    .environment(model)
            } else {
                RootView()
                    .environment(model)
                    .preferredColorScheme(ProcessInfo.processInfo.environment["SHOT_DARK"] == "1" ? .dark : nil)
                    .task { await ShotsSeed.launch(model, scenario: scenario) }
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
                        MyDayFilterButton(chosen: chosen, showsBadge: !dynamicTypeSize.isAccessibilitySize, open: {}, clear: {})
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
            center.settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: .enabled, badgeSetting: .enabled)
            manager.authorizationState = .denied
        case .timeSensitiveOff:
            center.settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: .disabled, badgeSetting: .enabled)
        case .badgesOff:
            center.settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: .enabled, badgeSetting: .disabled)
        case .badgesNotSet:
            center.settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: .enabled, badgeSetting: .notSupported)
        case .app, .customLocking, .noReminders:
            center.settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: .enabled, badgeSetting: .enabled)
        }
        let store = try! ReminderStore(location: .inMemory)
        if scenario != .noReminders { try! store.save(storedBeforeLaunch()) }
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

    static func launch(_ model: AppModel, scenario: ShotsApp.Scenario) async {
        await model.launch()
        if !isSeeded, scenario != .noReminders {
            isSeeded = true
            seedMockupData(into: model)
            if scenario == .customLocking { seedCustomLocking(into: model) }
        }
        await model.appOpened()
    }

    /// The mockup's reminders (its `seed()`) and their paces (the rest Escalating), with the
    /// mockup's 8:20 AM as now. Times are now plus or minus the mockup's gaps, so the screens show
    /// the same states whenever this runs.
    static func seedMockupData(into model: AppModel) {
        var tags: [String: Tag.ID] = [:]
        for name in ["home", "health", "work", "money", "morning", "appointments", "travel"] {
            // #health came from the store, with the physio exercises.
            tags[name] = model.engine.tags.first { $0.name == name }?.id ?? (try! model.createTag(named: name)!.id)
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

        // 12:00 PM four days ago, given up a day later.
        let carService = Reminder(title: "Book the car service", notes: "The garage closes at 5.", dueTime: at(220, days: -4), strength: .gentle)

        // Each is added at the mockup's creation date (its `createdAt`), so the Reminders tab lists
        // them in its order, and before anything happens to it. The clock only moves forward.
        func add(_ reminder: Reminder, daysAgo: Double, _ hour: Double, _ minute: Double) {
            clock.frozenNow = on(daysAgo: daysAgo, hour, minute)
            model.add(reminder)
        }
        add(rent, daysAgo: 273, 18, 44)
        add(bins, daysAgo: 269, 19, 5)
        add(standUp, daysAgo: 269, 19, 12)
        add(status, daysAgo: 268, 9, 0)
        add(dog, daysAgo: 240, 7, 45)
        add(meds, daysAgo: 213, 8, 12)
        add(plants, daysAgo: 184, 10, 2)
        add(grandma, daysAgo: 114, 16, 30)
        add(passport, daysAgo: 39, 9, 15)
        add(stretch, daysAgo: 28, 12, 30)
        clock.frozenNow = at(81, days: -18)
        model.markDone(passport.id)
        add(dentist, daysAgo: 14, 11, 20)
        add(carService, daysAgo: 13, 13, 0)
        clock.frozenNow = at(-28, days: -7)
        model.markDone(bins.id)
        clock.frozenNow = at(-60, days: -1)
        model.markDone(meds.id)
        model.markDone(dog.id)
        clock.frozenNow = at(-15, days: -1)
        model.pause(grandma.id)
        add(alex, daysAgo: 1, 21, 40)
        clock.frozenNow = at(-76)
        model.markDone(meds.id)
        clock.frozenNow = at(-62)
        model.markDone(dog.id)
        clock.frozenNow = nil
    }

    /// Now, to the minute, read once: the mockup's 8:20 AM.
    private static let seedNow = Calendar.current.dateInterval(of: .minute, for: .now)!.start

    /// `minutes` and `days` from the mockup's 8:20 AM. Days are calendar days, so a daylight
    /// saving change between then and now keeps the time of day.
    private static func at(_ minutes: Double, days: Double = 0) -> Date {
        Calendar.current.date(byAdding: .day, value: Int(days), to: seedNow)!.addingTimeInterval(minutes * 60)
    }

    /// The time of day `hour`:`minute` on the day `daysAgo` before the mockup's.
    private static func on(daysAgo: Double, _ hour: Double, _ minute: Double) -> Date {
        at(hour * 60 + minute - 500, days: -daysAgo)
    }

    /// The mockup's physio exercises, with #health: every day at 7:00 PM up to two days ago, the
    /// day before's Done at 7:12, the last one Skipped by a pause that ended after it. Only the
    /// store can hold a pause that ended with nothing left to resume at, so the seed saves it
    /// there before launch.
    private static func storedBeforeLaunch() -> StoredData {
        let health = Tag(name: "health")
        let lastDay = Calendar.current.dateComponents([.year, .month, .day], from: on(daysAgo: 2, 19, 0))
        let physio = Reminder(
            title: "Physio exercises",
            notes: "Shoulder routine, 3 sets.",
            tagIDs: [health.id],
            dueTime: on(daysAgo: 16, 19, 0),
            repeatRule: RepeatRule(frequency: .daily, end: .untilDate(year: lastDay.year!, month: lastDay.month!, day: lastDay.day!))!,
            strength: .firm,
            pace: .consistent(wait: 15 * 60),
            createdAt: on(daysAgo: 17, 17, 20)
        )
        let history = ReminderHistory(
            closedOccurrences: [on(daysAgo: 3, 19, 0): Closing(state: .done, closedAt: on(daysAgo: 3, 19, 12), nudgesSent: 1)],
            pauseSpans: [PauseSpan(start: on(daysAgo: 2, 18, 0), end: on(daysAgo: 1, 9, 0))]
        )
        return StoredData(reminders: [physio], tags: [health], histories: [physio.id: history])
    }

    /// Weekly on today and tomorrow, at the first whole minute at least 90 seconds away: time for
    /// the walk to open its Custom page before it falls due.
    static func seedCustomLocking(into model: AppModel) {
        let calendar = Calendar.current
        let dueTime = calendar.dateInterval(of: .minute, for: .now.addingTimeInterval(90))!.end
        let today = calendar.component(.weekday, from: dueTime)
        let weekdays = [today, today % 7 + 1].map { RepeatRule.WeekdayNumber(RepeatRule.Weekday(rawValue: $0)!) }
        let rule = RepeatRule(frequency: .weekly, weekdays: Set(weekdays))!
        model.add(Reminder(title: "Plan the week", dueTime: dueTime, repeatRule: rule, strength: .gentle, breakThroughFocus: false))
    }
}
