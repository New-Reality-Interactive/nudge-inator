import AlarmKit
import Foundation
import NudgeEngine
import SwiftData
import Testing
import UserNotifications
@testable import NudgeInator

/// The composition root through its one seam: the app model, built from a fake clock, a store and
/// the real adapters over the fake notification center and alarm manager. Tests assert on the
/// model's engine read-outs, on what the fakes hold, and on what the store loads.
@MainActor
struct AppModelTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let center = FakeNotificationCenter()
    let manager = FakeAlarmManager()
    /// Thursday 15 October 2026 at 9:00, once. Relentless sends nudges 1–3 at 9:00, 9:10 and 9:15
    /// as Time Sensitive notifications, then rings nudges 4–20 as alarms from 9:17:30.
    let call = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 9), strength: .relentless)

    /// A model before launch, as the app delegate builds it, over new adapters on the shared fakes.
    func model(store: ReminderStore) -> (model: AppModel, notifications: NotificationAdapter) {
        model(openingStoreWith: { store })
    }

    func model(openingStoreWith openStore: @escaping () throws -> ReminderStore) -> (model: AppModel, notifications: NotificationAdapter) {
        let notifications = NotificationAdapter(center: center, clock: clock)
        let model = AppModel(
            clock: clock,
            openStore: openStore,
            notifications: notifications,
            alarms: AlarmAdapter(manager: manager, clock: clock),
            timeZone: NewYork.timeZone
        )
        return (model, notifications)
    }

    func launchedModel(store: ReminderStore) async -> AppModel {
        let model = model(store: store).model
        await model.launch()
        return model
    }

    /// What the notification center's delegate hands the adapter when the person chooses Done.
    func chooseDone(on notifications: NotificationAdapter, nudgeFiredAt fireTime: Date) async {
        await notifications.handleResponse(
            actionIdentifier: NotificationAdapter.doneActionIdentifier,
            nudge: DeliveredNudge(reminderID: call.id, fireTime: fireTime)
        )
    }

    @Test func aRelentlessReminderReachesBothAdaptersAndDoneClearsThemAndIsSaved() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)

        model.add(call)
        await model.waitUntilApplied()
        #expect(center.pending.count == 3)
        #expect(manager.scheduled.count == 17)

        clock.now = NewYork.local(2026, 10, 15, 9, 12)
        await model.appOpened()
        await model.waitUntilApplied()
        #expect(model.engine.openOccurrence(for: call.id)?.state == .nudging(nudgeNumber: 2))
        #expect(center.pending.count == 1)

        model.markDone(call.id)
        await model.waitUntilApplied()
        #expect(center.pending.isEmpty)
        #expect(manager.scheduled.isEmpty)
        let saved = try store.load()
        #expect(saved.reminders == [call])
        #expect(saved.histories[call.id]?.closedOccurrences[call.dueTime]?.state == .done)
    }

    /// A relaunch keeps the system's pending requests and alarms, so the new model's adapters sit
    /// over the same fakes, and its store opens the same file.
    @Test func aRelaunchedModelHasTheSameOccurrencesAndPlan() async throws {
        let storeFile = TemporaryStoreFile()
        let water = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 9, 5), strength: .firm)
        let model = await launchedModel(store: try ReminderStore(location: .file(storeFile.url)))
        model.add(call)
        model.add(water)
        clock.now = NewYork.local(2026, 10, 15, 9, 12)
        await model.appOpened()
        model.markDone(water.id)
        await model.waitUntilApplied()
        let pending = Set(center.pending.map(\.identifier))
        let alarms = Set(manager.scheduled.map(\.id))
        let added = center.added.count
        let scheduled = manager.scheduleCalls.count

        let relaunched = await launchedModel(store: try ReminderStore(location: .file(storeFile.url)))
        await relaunched.waitUntilApplied()

        #expect(relaunched.engine.reminders == [call, water])
        #expect(relaunched.engine.openOccurrence(for: call.id)?.state == .nudging(nudgeNumber: 2))
        #expect(relaunched.engine.latestOccurrence(for: water.id)?.state == .done)
        #expect(Set(center.pending.map(\.identifier)) == pending)
        #expect(Set(manager.scheduled.map(\.id)) == alarms)
        #expect(center.added.count == added)
        #expect(manager.scheduleCalls.count == scheduled)
    }

    /// Yields until `condition` holds, for events that reach the model through an adapter's own
    /// task, then waits for the plans they cause.
    func waitUntil(_ model: AppModel, _ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            await Task.yield()
        }
        await model.waitUntilApplied()
    }

    @Test func alarmsDeniedInSettingsReplanTheUrgentNudgesAsTimeSensitiveNotifications() async throws {
        manager.authorizationState = .authorized
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        model.add(call)
        await model.waitUntilApplied()

        manager.changeAuthorization(to: .denied)
        await waitUntil(model) { manager.scheduled.isEmpty }

        #expect(manager.scheduled.isEmpty)
        #expect(center.pending.count == 20)
        #expect(center.pending.allSatisfy { $0.content.interruptionLevel == .timeSensitive })
    }

    /// App opened reads the permissions while an authorization change reads them too. The reads
    /// overlap, and here the later one finishes first: the change must still win. Alarms allowed
    /// again is the case nothing else corrects: with them denied, the adapter's refusal would
    /// start another read.
    @Test func permissionReadsTakeEffectInTheOrderTheyStarted() async throws {
        manager.authorizationState = .denied
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        model.add(call)
        await model.waitUntilApplied()
        center.holdsSettingsReads = true

        let opened = Task { await model.appOpened() }
        await yield(until: center.heldSettingsReadCount == 1)
        manager.changeAuthorization(to: .authorized)
        await yield(until: false)
        repeat {
            center.releaseLatestSettingsRead()
            await yield(until: false)
        } while center.heldSettingsReadCount > 0
        await opened.value
        await model.waitUntilApplied()

        #expect(model.engine.reach.urgent == .alarm)
        #expect(manager.scheduled.count == 17)
    }

    /// Lets the model's and adapters' tasks run, up to 200 turns or until `condition` holds.
    func yield(until condition: @autoclosure () -> Bool) async {
        for _ in 0..<200 where !condition() {
            await Task.yield()
        }
    }

    /// Settings' status rows (ticket 30) need not determined, which `reach` doesn't say, and the
    /// banners (ticket 31) must follow a change without a relaunch.
    @Test func thePermissionStatesFollowWhatTheAdaptersRead() async throws {
        center.settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: .disabled)
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        #expect(model.permissions == PermissionStates(notifications: .allowed, alarms: .notDetermined, timeSensitive: .off))

        manager.changeAuthorization(to: .denied)
        await waitUntil(model) { model.permissions.alarms == .denied }

        #expect(model.permissions == PermissionStates(notifications: .allowed, alarms: .denied, timeSensitive: .off))
    }

    /// The app hears notifications were turned off only when the center turns a request down.
    @Test func notificationsTurnedOffAreReadAgainWhenTheCenterRefusesARequest() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        center.settings = NotificationSettingsSnapshot(authorizationStatus: .denied, timeSensitiveSetting: .disabled)
        center.addError = UNError(.notificationsNotAllowed)

        model.add(call)
        await waitUntil(model) { model.engine.reach.normal == nil }

        #expect(model.engine.reach == Reach(normal: nil, high: nil, urgent: .alarm))
    }

    @Test func doneFromANotificationClosesTheOccurrenceClearsBothAdaptersAndIsSaved() async throws {
        let store = try ReminderStore(location: .inMemory)
        let (model, notifications) = model(store: store)
        await model.launch()
        model.add(call)
        clock.now = NewYork.local(2026, 10, 15, 9, 12)
        await model.appOpened()

        await chooseDone(on: notifications, nudgeFiredAt: NewYork.local(2026, 10, 15, 9, 10))
        await model.waitUntilApplied()

        #expect(model.engine.latestOccurrence(for: call.id)?.state == .done)
        #expect(center.pending.isEmpty)
        #expect(manager.scheduled.isEmpty)
        #expect(try store.load().histories[call.id]?.closedOccurrences[call.dueTime]?.state == .done)
    }

    /// A store the model can't read is left as it is, and so is everything pending: an empty plan
    /// would cancel the nudges, and a save would replace the file with nothing.
    @Test func aStoreThatCantBeReadChangesNothingPendingOrSaved() async throws {
        let storeFile = TemporaryStoreFile()
        let first = await launchedModel(store: try ReminderStore(location: .file(storeFile.url)))
        first.add(call)
        await first.waitUntilApplied()
        let pending = Set(center.pending.map(\.identifier))
        let alarms = Set(manager.scheduled.map(\.id))
        try damageStrength(inStoreAt: storeFile.url)

        let model = await launchedModel(store: try ReminderStore(location: .file(storeFile.url)))
        clock.now = NewYork.local(2026, 10, 15, 9, 12)
        await model.appOpened()
        model.add(Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 10), strength: .firm))
        await model.waitUntilApplied()

        guard case .storeUnreadable = model.launchState else {
            Issue.record("Launched as \(model.launchState)")
            return
        }
        #expect(Set(center.pending.map(\.identifier)) == pending)
        #expect(Set(manager.scheduled.map(\.id)) == alarms)
        #expect(throws: StoreError.unreadable(field: .strength, value: "very")) {
            try ReminderStore(location: .file(storeFile.url)).load()
        }
    }

    @Test func deleteCancelsEverythingPendingAndForgetsTheReminder() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)
        model.add(call)
        clock.now = NewYork.local(2026, 10, 15, 9, 12)
        model.markDone(call.id)

        model.delete(call.id)
        await model.waitUntilApplied()

        #expect(model.engine.reminders.isEmpty)
        #expect(center.pending.isEmpty)
        #expect(manager.scheduled.isEmpty)
        #expect(try store.load() == StoredData(reminders: [], tags: [], histories: [:]))
    }

    @Test func pauseAndResumeAreSavedAndReachBothAdapters() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)
        model.add(call)

        model.pause(call.id)
        await model.waitUntilApplied()
        #expect(center.pending.isEmpty)
        #expect(manager.scheduled.isEmpty)
        #expect(try store.load().histories[call.id]?.pauseSpans == [PauseSpan(start: clock.now)])

        clock.now = NewYork.local(2026, 10, 15, 8, 30)
        try model.resume(call.id)
        await model.waitUntilApplied()
        #expect(center.pending.count == 3)
        #expect(manager.scheduled.count == 17)
        #expect(try store.load().histories[call.id]?.pauseSpans.last?.end == clock.now)
    }

    @Test func aTitleEditIsSavedAndReachesBothAdapters() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)
        model.add(call)
        var edited = call
        edited.title = "Call the bank about the card"

        try model.edit(edited)
        await model.waitUntilApplied()

        #expect(try store.load().reminders == [edited])
        #expect(center.pending.allSatisfy { $0.content.title == edited.title })
        #expect(manager.scheduled.map { String(localized: $0.attributes.presentation.alert.title) }
            == Array(repeating: edited.title, count: 17))
    }

    /// The lock while nudging (ADR 0002).
    @Test func anEditOfALockedFieldIsThrownAndNotSaved() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)
        model.add(call)
        clock.now = NewYork.local(2026, 10, 15, 9, 12)
        var edited = call
        edited.strength = .gentle

        #expect(throws: EditError.locked([.strength])) { try model.edit(edited) }
        #expect(try store.load().reminders == [call])
    }

    @Test func tagsAreSavedAsTheyAreCreatedRenamedAndDeleted() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)

        let home = try #require(try model.createTag(named: "home"))
        var tagged = call
        tagged.tagIDs = [home.id]
        model.add(tagged)
        #expect(try store.load().tags == [home])

        try model.renameTag(home.id, to: "house")
        #expect(try store.load().tags.map(\.name) == ["house"])

        model.deleteTag(home.id)
        let saved = try store.load()
        #expect(saved.tags.isEmpty)
        #expect(saved.reminders.map(\.tagIDs) == [[]])
    }

    @Test func aTagNameTheEngineTurnsDownIsThrownAndNotSaved() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)
        try model.createTag(named: "home")

        #expect(throws: TagNameError.self) { try model.createTag(named: "Home") }
        #expect(try store.load().tags.map(\.name) == ["home"])
    }

    /// A Never reminder whose due time has passed has nothing to resume at (ticket 11).
    @Test func aResumeTheEngineTurnsDownIsThrownAndChangesNothing() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)
        model.add(call)
        model.pause(call.id)
        clock.now = NewYork.local(2026, 10, 16)

        #expect(throws: ResumeError.needsNewDueTime) { try model.resume(call.id) }
        #expect(model.engine.isPaused(call.id))
    }

    /// With room for 2 alarms, nudges 6–20 come back as Time Sensitive notifications marked past
    /// the alarm limit (ticket 15), beside nudges 1–3.
    @Test func nudgesPastTheSystemsAlarmLimitComeAsNotificationsInstead() async throws {
        manager.alarmLimit = 2
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))

        model.add(call)
        await model.waitUntilApplied()

        #expect(manager.scheduled.count == 2)
        #expect(center.pending.count == 18)
    }

    /// The plan has already reached the adapters, so the event stands; the screens can say the
    /// save failed.
    @Test func aSaveTheStoreTurnsDownIsReported() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)
        model.add(call)
        #expect(model.saveError == nil)

        model.add(call)

        #expect(model.saveError as? StoreError == .duplicateID(call.id))
        #expect(try store.load().reminders == [call])
    }

    struct StoreWontOpen: Error {}

    @Test func aStoreThatWontOpenLeavesTheAdaptersAlone() async throws {
        let model = model(openingStoreWith: { throw StoreWontOpen() }).model
        await model.launch()
        await model.appOpened()
        model.add(call)
        await model.waitUntilApplied()

        guard case .storeUnreadable(let error) = model.launchState else {
            Issue.record("Launched as \(model.launchState)")
            return
        }
        #expect(error is StoreWontOpen)
        #expect(center.added.isEmpty)
        #expect(manager.scheduleCalls.isEmpty)
    }

    /// Before the first unlock after a restart, data protection keeps the file shut, and a Done
    /// action can launch the app then. App opened comes once the phone is unlocked, so it tries
    /// again.
    @Test func appOpenedTriesAStoreThatCouldntBeOpenedAgain() async throws {
        let store = try ReminderStore(location: .inMemory)
        try store.save(StoredData(reminders: [call], tags: [], histories: [:]))
        var attempts = 0
        let model = model(openingStoreWith: {
            attempts += 1
            if attempts == 1 { throw StoreWontOpen() }
            return store
        }).model
        await model.launch()

        await model.appOpened()
        await model.waitUntilApplied()

        guard case .ready = model.launchState else {
            Issue.record("Launched as \(model.launchState)")
            return
        }
        #expect(model.engine.reminders == [call])
        #expect(center.pending.count == 3)
        #expect(manager.scheduled.count == 17)
    }

    /// Writes a strength the store can't map back, as a bad schema change might.
    func damageStrength(inStoreAt url: URL) throws {
        let container = try ModelContainer(
            for: ReminderRecord.self, ClosedOccurrenceRecord.self, PauseSpanRecord.self, ReplacedTitleRecord.self, TagRecord.self,
            configurations: ReminderStore.configuration(for: .file(url))
        )
        for record in try container.mainContext.fetch(FetchDescriptor<ReminderRecord>()) {
            record.strength = "very"
        }
        try container.mainContext.save()
    }

    /// Four Gentle reminders with Break through Focus off plan 80 notifications, and the system
    /// keeps 64 pending. By 10:00 each has sent nudges 1 (9:00) and 2 (10:00), so App opened
    /// swaps those 8 for the next 8.
    @Test func appOpenedRefillsTheNotificationsTheSystemKeepsPending() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        for title in ["Water the plants", "Stretch", "Read", "Tidy the desk"] {
            model.add(Reminder(title: title, dueTime: NewYork.local(2026, 10, 15, 9), strength: .gentle, breakThroughFocus: false))
        }
        await model.waitUntilApplied()
        let before = Set(center.pending.map(\.identifier))
        #expect(before.count == 64)

        clock.now = NewYork.local(2026, 10, 15, 10)
        await model.appOpened()
        await model.waitUntilApplied()

        let after = Set(center.pending.map(\.identifier))
        #expect(after.count == 64)
        #expect(after.subtracting(before).count == 8)
    }

    /// When the app is the test host, its own model would plan from the real store, and on every
    /// foreground hand the real adapters a plan that cancels the device checks' alarms.
    @Test func theAppDoesntBuildItsModelWhenItHostsTests() {
        #expect(AppDelegate.isHostingTests)
    }

    /// Apple: the response handler returning tells the system "you are done processing the
    /// user's response", and the Done action launches the app in the background, so it can be
    /// suspended straight after. The Done must be saved and applied by then.
    @Test func aDoneFromANotificationIsSavedAndAppliedBeforeTheResponseHandlerReturns() async throws {
        let store = try ReminderStore(location: .inMemory)
        let first = await launchedModel(store: store)
        first.add(call)
        await first.waitUntilApplied()
        clock.now = NewYork.local(2026, 10, 15, 9, 12)
        let (model, notifications) = model(store: store)

        await chooseDone(on: notifications, nudgeFiredAt: NewYork.local(2026, 10, 15, 9, 10))

        #expect(try store.load().histories[call.id]?.closedOccurrences[call.dueTime]?.state == .done)
        #expect(center.pending.isEmpty)
        #expect(manager.scheduled.isEmpty)
        withExtendedLifetime(model) {}
    }

    /// Ticket 20's Open intent calls `showReminder`; Done on the details screen is then the same
    /// `markDone` as everywhere else in the app.
    @Test func openShowsTheRemindersDetailsWhereDoneClosesItsOccurrence() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)
        model.add(call)
        clock.now = NewYork.local(2026, 10, 15, 9, 20)
        await model.appOpened()

        model.showReminder(call.id)
        #expect(model.route == .reminderDetails(call.id))

        model.markDone(call.id)
        await model.waitUntilApplied()
        #expect(model.engine.latestOccurrence(for: call.id)?.state == .done)
        #expect(center.pending.isEmpty)
        #expect(manager.scheduled.isEmpty)
        #expect(try store.load().histories[call.id]?.closedOccurrences[call.dueTime]?.state == .done)
    }

    /// An alarm left from a reminder since deleted, for example.
    @Test func openForAReminderTheAppDoesntHoldShowsNow() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))

        model.showReminder(call.id)

        #expect(model.route == .now)
    }

    /// The tab shell takes the route once it has followed it, so the same Open isn't followed again.
    @Test func takingTheRouteHandsItOverOnce() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        model.add(call)
        model.showReminder(call.id)

        #expect(model.takeRoute() == .reminderDetails(call.id))
        #expect(model.route == nil)
        #expect(model.takeRoute() == nil)
    }

    /// What the tabs show for each launch state (ticket 22): nothing that claims "All clear"
    /// before the store is read, and a message when it can't be.
    @Test func theScreensFollowTheLaunchState() async throws {
        let launching = model(store: try ReminderStore(location: .inMemory)).model
        #expect(ScreenState(model: launching) == .loading)

        await launching.launch()
        #expect(ScreenState(model: launching) == .ready)

        let unreadable = model(openingStoreWith: { throw StoreWontOpen() }).model
        await unreadable.launch()
        #expect(ScreenState(model: unreadable) == .storeUnreadable)
    }

    /// The app hosting tests, and previews, have no model: the tabs still draw.
    @Test func withoutAModelTheScreensAreReady() {
        #expect(ScreenState(model: nil) == .ready)
    }

    /// The app delegate starts launch and the scene's first `.active` sends App opened, in either
    /// order: App opened waits for the one launch.
    @Test func appOpenedBeforeLaunchLaunchesFirstAndPlans() async throws {
        let storeFile = TemporaryStoreFile()
        try ReminderStore(location: .file(storeFile.url)).save(StoredData(reminders: [call], tags: [], histories: [:]))
        let model = model(store: try ReminderStore(location: .file(storeFile.url))).model

        await model.appOpened()
        #expect(model.engine.reminders == [call])
        await model.launch()
        await model.waitUntilApplied()

        #expect(center.pending.count == 3)
        #expect(manager.scheduled.count == 17)
        #expect(manager.scheduleCalls.count == 17)
    }

    /// The Done action launches the app in the background, and its response can arrive while the
    /// model is still reading the store.
    @Test func aDoneThatArrivesBeforeLaunchFinishesClosesTheSavedOccurrence() async throws {
        let store = try ReminderStore(location: .inMemory)
        try store.save(StoredData(reminders: [call], tags: [], histories: [:]))
        clock.now = NewYork.local(2026, 10, 15, 9, 12)
        let (model, notifications) = model(store: store)

        await chooseDone(on: notifications, nudgeFiredAt: NewYork.local(2026, 10, 15, 9, 10))
        await model.launch()
        await model.waitUntilApplied()

        #expect(model.engine.latestOccurrence(for: call.id)?.state == .done)
        #expect(center.pending.isEmpty)
        #expect(manager.scheduled.isEmpty)
        #expect(try store.load().histories[call.id]?.closedOccurrences[call.dueTime]?.state == .done)
    }
}
