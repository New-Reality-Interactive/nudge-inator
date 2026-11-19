import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// The reminders, tags and history the per-version migration suites write into an older store and
/// expect back (`Version2StoreMigrationTests`, `Version3StoreMigrationTests`). One copy, so a
/// suite's tests read the same data; each suite adds what only its version holds. They all have a
/// creation date, which 1.2.0's store (`StoreMigrationTests`, with its own fixtures) never saved.
struct StoreFixtures {
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
        breakThroughFocus: false,
        createdAt: NewYork.local(2026, 10, 1, 8)
    )
    let bins = Reminder(title: "Put the bins out", dueTime: NewYork.local(2026, 10, 16, 19), strength: .relentless, createdAt: NewYork.local(2026, 10, 2, 8))
    let rent = Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 11, 1, 9), strength: .gentle, createdAt: NewYork.local(2026, 10, 3, 8))

    /// What `pills` has behind it: a Done and a Missed closing, an edit, a closed and an open pause,
    /// and a replaced title.
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
}

/// What a per-version suite needs to open its store: the shared fixtures, its store file, and the
/// instant of the update.
@MainActor
protocol StoreFixtured {
    var fixtures: StoreFixtures { get }
    var storeFile: TemporaryStoreFile { get }
    var updateInstant: Date { get }
}

@MainActor
extension StoreFixtured {
    var fileURL: URL { storeFile.url }
    var home: Tag { fixtures.home }
    var health: Tag { fixtures.health }
    var pills: Reminder { fixtures.pills }
    var bins: Reminder { fixtures.bins }
    var rent: Reminder { fixtures.rent }
    var pillsHistory: ReminderHistory { fixtures.pillsHistory }

    /// The plan the engine makes from `reminders` on 2026-10-20, 8:00 in New York. Every notification
    /// and alarm identifier comes from it, so an update that leaves it unchanged re-plans nothing.
    func enginePlan(of reminders: [Reminder]) throws -> SchedulePlan {
        let scheduler = FakeScheduler()
        var engine = Engine(clock: FakeClock(now: NewYork.local(2026, 10, 20, 8)), scheduler: scheduler, timeZone: NewYork.timeZone)
        engine.update(reminders: reminders)
        return try #require(scheduler.lastPlan)
    }

    /// The store as the first launch after the update opens it.
    func openAfterUpdate() throws -> ReminderStore {
        try ReminderStore(location: .file(fileURL), now: updateInstant)
    }
}
