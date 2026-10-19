import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// A Done chosen before the first unlock after a restart (ticket 32), through the app model over
/// the real adapters on the fakes. The store opener fails while the store is shut, as data
/// protection keeps it then, and succeeds once it opens. A class so `deinit` removes this test's
/// queue folder and defaults, even when it fails.
@MainActor
final class DoneBeforeFirstUnlockTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let center = FakeNotificationCenter()
    let manager = FakeAlarmManager()
    let folder = FileManager.default.temporaryDirectory.appending(path: "DoneBeforeFirstUnlockTests-\(UUID().uuidString)")
    let suiteName = "DoneBeforeFirstUnlockTests.\(UUID().uuidString)"
    let store: ReminderStore
    /// Data protection keeps the store shut until the first unlock.
    var storeIsShut = false
    /// Thursday 15 October 2026 at 9:00, once. Relentless sends nudges 1–3 at 9:00, 9:10 and 9:15
    /// as Time Sensitive notifications, then rings nudges 4–20 as alarms from 9:17:30.
    let call = Reminder(title: "Call the bank", notes: "Ask about the fee", dueTime: NewYork.local(2026, 10, 15, 9), strength: .relentless)

    struct StoreIsShut: Error {}

    var queue: DoneQueue { DoneQueue(folder: folder) }

    init() throws {
        store = try ReminderStore(location: .inMemory)
    }

    deinit {
        try? FileManager.default.removeItem(at: folder)
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    /// A model before launch, as the app delegate builds it, over new adapters on the shared fakes.
    func model() throws -> (model: AppModel, notifications: NotificationAdapter) {
        let notifications = NotificationAdapter(center: center, clock: clock)
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let model = AppModel(
            clock: clock,
            openStore: { [unowned self] in
                if storeIsShut { throw StoreIsShut() }
                return store
            },
            notifications: notifications,
            alarms: AlarmAdapter(manager: manager, clock: clock),
            onboardingRecord: OnboardingRecord(defaults: defaults),
            doneQueue: queue,
            timeZone: NewYork.timeZone
        )
        return (model, notifications)
    }

    /// The reminders saved and their nudges pending, then a restart at 9:12 that shuts the store,
    /// and the model a Done action launches. The first model is returned too, to keep it alive.
    func restartedBeforeTheFirstUnlock(with reminders: [Reminder]) async throws -> (model: AppModel, notifications: NotificationAdapter, first: AppModel) {
        let first = try model().model
        await first.launch()
        for reminder in reminders {
            first.add(reminder)
        }
        await first.waitUntilApplied()
        storeIsShut = true
        clock.now = NewYork.local(2026, 10, 15, 9, 12)
        let (model, notifications) = try model()
        return (model, notifications, first)
    }

    /// What the notification center's delegate hands the adapter when the person chooses Done on
    /// the call's 9:10 nudge.
    func chooseDone(on notifications: NotificationAdapter) async {
        await notifications.handleResponse(
            actionIdentifier: NotificationAdapter.doneActionIdentifier,
            nudge: DeliveredNudge(reminderID: call.id, dueTime: call.dueTime, fireTime: NewYork.local(2026, 10, 15, 9, 10))
        )
    }

    @Test func aDoneWhileTheStoreIsShutIsQueuedWithItsOccurrenceAndWhenItWasChosen() async throws {
        let (model, notifications, first) = try await restartedBeforeTheFirstUnlock(with: [call])

        await chooseDone(on: notifications)

        #expect(try queue.dones() == [QueuedDone(reminderID: call.id, dueTime: call.dueTime, doneAt: NewYork.local(2026, 10, 15, 9, 12))])
        withExtendedLifetime((model, first)) {}
    }

    /// The model has no reminders to plan from, so the adapters find the occurrence's nudges by
    /// their identifiers. The other reminder's stay.
    @Test func aDoneWhileTheStoreIsShutStopsItsOccurrencesNudges() async throws {
        let plants = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 10), strength: .relentless)
        let (model, notifications, first) = try await restartedBeforeTheFirstUnlock(with: [call, plants])

        await chooseDone(on: notifications)
        await model.waitUntilApplied()

        #expect(!center.pending.isEmpty)
        #expect(center.pending.allSatisfy { NotificationAdapter.deliveredNudge(in: $0.content.userInfo)?.reminderID == plants.id })
        #expect(manager.scheduled.count == 17)
        #expect(manager.cancelledIDs.count == 17)
        withExtendedLifetime(first) {}
    }

    /// The call's title, its note, and its tag's name.
    @Test(arguments: ["Call the bank", "Ask about the fee", "errands"])
    func theQueueHoldsNoTitleNoteOrTag(personal: String) async throws {
        let first = try model().model
        await first.launch()
        let tag = try #require(try first.createTag(named: "errands"))
        var call = call
        call.tagIDs = [tag.id]
        let (model, notifications, _) = try await restartedBeforeTheFirstUnlock(with: [call])

        await chooseDone(on: notifications)

        let text = try String(contentsOf: queue.file, encoding: .utf8)
        #expect(text.contains(call.id.uuidString))
        #expect(!text.localizedStandardContains(personal))
        #expect(!text.contains(tag.id.uuidString))
        withExtendedLifetime((model, first)) {}
    }

    enum Opening: CaseIterable {
        case protectedDataBecameAvailable
        case appOpened
    }

    /// Once the store opens, the Done closes the occurrence at the time it was chosen, it is saved,
    /// and the file goes.
    @Test(arguments: Opening.allCases)
    func theQueuedDoneIsMergedOnceTheStoreOpensAndTheFileIsDeleted(opening: Opening) async throws {
        let (model, notifications, first) = try await restartedBeforeTheFirstUnlock(with: [call])
        await chooseDone(on: notifications)

        storeIsShut = false
        clock.now = NewYork.local(2026, 10, 15, 9, 20)
        switch opening {
        case .protectedDataBecameAvailable: await model.protectedDataBecameAvailable()
        case .appOpened: await model.appOpened()
        }
        await model.waitUntilApplied()

        #expect(model.engine.latestOccurrence(for: call.id)?.state == .done)
        #expect(try store.load().histories[call.id]?.closedOccurrences[call.dueTime]?.closedAt == NewYork.local(2026, 10, 15, 9, 12))
        #expect(!FileManager.default.fileExists(atPath: queue.file.path()))
        #expect(center.pending.isEmpty)
        #expect(manager.scheduled.isEmpty)
        withExtendedLifetime(first) {}
    }

    /// Each Done chosen before the unlock is merged: the call's, on its 9:10 nudge, and the
    /// plants', on their first at 9:05.
    @Test func severalQueuedDonesAreAllMerged() async throws {
        let plants = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 9, 5), strength: .relentless)
        let (model, notifications, first) = try await restartedBeforeTheFirstUnlock(with: [call, plants])
        await chooseDone(on: notifications)
        await notifications.handleResponse(
            actionIdentifier: NotificationAdapter.doneActionIdentifier,
            nudge: DeliveredNudge(reminderID: plants.id, dueTime: plants.dueTime, fireTime: plants.dueTime)
        )

        storeIsShut = false
        await model.protectedDataBecameAvailable()

        #expect(model.engine.latestOccurrence(for: call.id)?.state == .done)
        #expect(model.engine.latestOccurrence(for: plants.id)?.state == .done)
        #expect(!FileManager.default.fileExists(atPath: queue.file.path()))
        withExtendedLifetime(first) {}
    }

    /// A queue that won't decode never will, so it is deleted and the launch goes on. Its Done is
    /// lost, and the occurrence keeps nudging.
    @Test func aQueueThatWontDecodeIsDeletedAndTheLaunchGoesOn() async throws {
        try queue.makeFolder()
        try Data("not a list of Dones".utf8).write(to: queue.file)
        let model = try model().model

        await model.launch()

        guard case .ready = model.launchState else {
            Issue.record("Launched as \(model.launchState)")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: queue.file.path()))
    }

    /// The app was killed before the store opened, so the next launch finds the queue. A Done for
    /// yesterday's occurrence, now that today's has fallen due, is dropped without error.
    @Test func aQueuedDoneForAnOccurrenceNoLongerTheLatestIsDropped() async throws {
        let pills = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15, 9), repeatRule: .everyDay, strength: .relentless)
        let first = try model().model
        await first.launch()
        first.add(pills)
        await first.waitUntilApplied()
        try queue.add(QueuedDone(reminderID: pills.id, dueTime: pills.dueTime, doneAt: NewYork.local(2026, 10, 15, 9, 12)))

        clock.now = NewYork.local(2026, 10, 16, 9, 5)
        let model = try model().model
        await model.launch()

        #expect(model.engine.occurrence(of: pills.id, dueAt: pills.dueTime)?.state == .missed(reason: .giveUpLimit))
        #expect(model.engine.openOccurrence(for: pills.id)?.dueTime == NewYork.local(2026, 10, 16, 9))
        #expect(model.saveError == nil)
        #expect(!FileManager.default.fileExists(atPath: queue.file.path()))
        withExtendedLifetime(first) {}
    }

    /// A Done that can't be written is lost, as before ticket 32, so its nudges are left to come:
    /// what is pending still matches the store, and the person can choose Done again.
    @Test func aDoneThatCantBeQueuedLeavesTheNudgesPending() async throws {
        let (model, notifications, first) = try await restartedBeforeTheFirstUnlock(with: [call])
        let pending = Set(center.pending.map(\.identifier))
        let alarms = Set(manager.scheduled.map(\.id))
        // A file where the folder should be, so the queue can't be written.
        try FileManager.default.removeItem(at: folder)
        try Data().write(to: folder)

        await chooseDone(on: notifications)
        await model.waitUntilApplied()

        #expect(Set(center.pending.map(\.identifier)) == pending)
        #expect(Set(manager.scheduled.map(\.id)) == alarms)
        withExtendedLifetime(first) {}
    }

    /// The queue's folder is made while the store is open, so a Done before the first unlock has
    /// only the file to write: Apple's docs don't say a folder can be made then.
    @Test func theQueuesFolderIsMadeOnceTheStoreOpens() async throws {
        let model = try model().model

        await model.launch()

        #expect(FileManager.default.fileExists(atPath: folder.path()))
    }

    /// `UserDefaults` is shut before the first unlock too, so a model a Done launched then read
    /// onboarding as not finished. Once the store opens it reads the record again, and onboarding
    /// doesn't come back.
    @Test func onboardingReadBeforeTheFirstUnlockIsReadAgainOnceTheStoreOpens() async throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removeObject(forKey: "onboardingFinished")
        storeIsShut = true
        let model = try model().model
        await model.launch()
        #expect(model.onboarding == .welcome)

        OnboardingRecord(defaults: defaults).isFinished = true
        storeIsShut = false
        await model.protectedDataBecameAvailable()

        #expect(model.onboarding == nil)
    }
}
