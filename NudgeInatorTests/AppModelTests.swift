import AlarmKit
import Foundation
import NudgeEngine
@testable import NudgeShared
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
    /// Thursday 15 October 2026 at 8:40, once. Firm sends nudges 1–3 at 8:40, 9:10 and 9:25 as
    /// notifications, then rings nudges 4–20 as alarms from 9:32:30, so it reaches both adapters.
    let call = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 8, 40), strength: .firm)

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
            defaultPaceRecord: .temporary,
            doneQueue: .temporary,
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
            nudge: DeliveredNudge(reminderID: call.id, dueTime: call.dueTime, fireTime: fireTime)
        )
    }

    @Test func aFirmReminderReachesBothAdaptersAndDoneClearsThemAndIsSaved() async throws {
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

    /// Every Relentless nudge is Urgent, so all 20 come back as Time Sensitive notifications.
    @Test func alarmsDeniedInSettingsReplanTheUrgentNudgesAsTimeSensitiveNotifications() async throws {
        manager.authorizationState = .authorized
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        model.add(Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 10, 15, 9), strength: .relentless))
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
        manager.authorizationState = .notDetermined
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        #expect(model.permissions == PermissionStates(notifications: .allowed, alarms: .notDetermined, timeSensitive: .off))

        manager.changeAuthorization(to: .denied)
        await waitUntil(model) { model.permissions.alarms == .denied }

        #expect(model.permissions == PermissionStates(notifications: .allowed, alarms: .denied, timeSensitive: .off))
    }

    /// Ticket 30: Settings' rows, from what the fake adapters report through the model.
    @Test(arguments: [
        (UNAuthorizationStatus.authorized, AlarmManager.AuthorizationState.authorized, NotificationsStatus.on, AlarmsStatus.on, SettingsStatus.OpenSettings?.none),
        (.denied, .denied, .off, .off, .appSettings),
        (.authorized, .notDetermined, .on, .notSet, nil),
    ])
    func settingsRowsReflectWhatTheAdaptersReadThroughTheModel(
        notifications: UNAuthorizationStatus,
        alarms: AlarmManager.AuthorizationState,
        expectedNotifications: NotificationsStatus,
        expectedAlarms: AlarmsStatus,
        expectedOpenSettings: SettingsStatus.OpenSettings?
    ) async throws {
        center.settings = NotificationSettingsSnapshot(authorizationStatus: notifications, timeSensitiveSetting: .enabled)
        manager.authorizationState = alarms
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))

        let status = SettingsStatus(model.permissions)

        #expect(status.notifications == expectedNotifications)
        #expect(status.alarms == expectedAlarms)
        #expect(status.openSettings == expectedOpenSettings)
    }

    /// Ticket 30's device check: alarms turned off in Settings while the app was suspended, with no
    /// update from AlarmKit. Coming forward reads the state again and re-plans.
    @Test func alarmsTurnedOffInSettingsWithNoUpdateAreFoundWhenTheAppIsOpened() async throws {
        manager.authorizationState = .authorized
        center.settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: .enabled)
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        model.add(call)
        await model.waitUntilApplied()
        #expect(manager.scheduled.count == 17)

        manager.authorizationState = .denied
        await model.appOpened()
        await model.waitUntilApplied()

        #expect(model.permissions.alarms == .denied)
        #expect(manager.scheduled.isEmpty)
        #expect(center.pending.count == 20)
    }

    /// #89: an install upgraded from 1.1.0 answered the prompt before it asked for badges. Opening
    /// the app, at launch or coming forward, asks again, once the first ask has turned badges on.
    @Test func anUpgradedInstallAsksForBadgesWhenTheAppIsOpenedAndGetsThem() async throws {
        center.settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: .enabled, badgeSetting: .notSupported)
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))

        await model.appOpened()

        #expect(center.requestedAuthorizationOptions == [[.alert, .sound, .badge]])
        #expect(model.permissions.badges == .allowed)

        await model.appOpened()

        #expect(center.requestedAuthorizationOptions.count == 1)
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

    /// Ticket 30. A Firm reminder (3 requests, 17 alarms), a Done one with history, a tag and a
    /// test nudge: afterwards the store, the engine, the center and the alarm manager are all empty.
    @Test func deleteAllDataEmptiesTheStoreTheEngineAndBothAdapters() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)
        let water = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 9, 5), strength: .firm)
        model.add(call)
        model.add(water)
        try model.createTag(named: "home")
        clock.now = NewYork.local(2026, 10, 15, 9, 12)
        model.markDone(water.id)
        await model.sendTestNudge()
        await model.waitUntilApplied()
        #expect(center.pending.count > 1)
        #expect(manager.scheduled.isEmpty == false)

        try await model.deleteAllData()

        #expect(model.engine.reminders.isEmpty)
        #expect(model.engine.tags.isEmpty)
        #expect(model.engine.histories.isEmpty)
        #expect(center.pending.isEmpty)
        #expect(center.removedAllDeliveredCount == 1)
        #expect(manager.scheduled.isEmpty)
        #expect(try store.load() == StoredData(reminders: [], tags: [], histories: [:]))
    }

    @Test func afterDeleteAllDataTheModelTakesNewRemindersAsFromANewInstall() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)
        model.add(call)
        try await model.deleteAllData()

        model.add(call)
        await model.waitUntilApplied()

        #expect(model.engine.reminders == [call])
        #expect(try store.load().reminders == [call])
        #expect(center.pending.count == 3)
    }

    /// The store goes first, so a store that turns the delete down leaves the reminders, their
    /// nudges and the alarms exactly as they were.
    @Test func aStoreThatCannotDeleteLeavesEverythingAsItWasAndSaysSo() async throws {
        let storeFile = TemporaryStoreFile()
        let seed = try ReminderStore(location: .file(storeFile.url))
        try seed.save(StoredData(reminders: [call], tags: [], histories: [:]))
        // Read-only, as a file the system won't let the app change.
        for file in storeFile.files where FileManager.default.fileExists(atPath: file.path()) {
            try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: file.path())
        }
        let model = await launchedModel(store: try ReminderStore(location: .file(storeFile.url)))
        await model.waitUntilApplied()
        let pending = Set(center.pending.map(\.identifier))
        let alarms = Set(manager.scheduled.map(\.id))

        await #expect(throws: (any Error).self) { try await model.deleteAllData() }

        #expect(model.engine.reminders == [call])
        #expect(Set(center.pending.map(\.identifier)) == pending)
        #expect(Set(manager.scheduled.map(\.id)) == alarms)
        #expect(center.removedAllDeliveredCount == 0)
    }

    @Test func deleteAllDataBeforeTheStoreIsReadDoesNothing() async throws {
        let model = model(openingStoreWith: { throw StoreWontOpen() }).model
        await model.launch()

        try await model.deleteAllData()

        #expect(center.removedAllDeliveredCount == 0)
    }

    @Test func sendingATestNudgeSchedulesOneNotificationThatNoPlanRemoves() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))

        await model.sendTestNudge()
        model.add(call)
        await model.waitUntilApplied()

        #expect(center.pending.map(\.identifier).contains(NotificationAdapter.testNudgeIdentifier))
        #expect(center.pending.count == 4)
        #expect(manager.scheduled.count == 17)
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

    /// The Icon badge shows the Now badge's count (icon-badge spec, decision 1), set from the plan
    /// that launch, App opened and each event apply. A Done from a notification sets it before the
    /// response handler returns, while the app is still awake.
    @Test func theIconBadgeFollowsTheNowBadgeThroughLaunchAppOpenedEventsAndADoneFromANotification() async throws {
        let store = try ReminderStore(location: .inMemory)
        try store.save(StoredData(reminders: [call], tags: [], histories: [:]))
        let water = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 8, 30), strength: .gentle)
        let (model, notifications) = model(store: store)

        await model.launch()
        await model.waitUntilApplied()
        #expect(center.badgeCounts.last == 0)

        clock.now = NewYork.local(2026, 10, 15, 8, 45)
        await model.appOpened()
        await model.waitUntilApplied()
        #expect(center.badgeCounts.last == 1)

        model.add(water)
        await model.waitUntilApplied()
        #expect(center.badgeCounts.last == 2)

        await chooseDone(on: notifications, nudgeFiredAt: NewYork.local(2026, 10, 15, 8, 40))
        #expect(center.badgeCounts.last == 1)
        #expect(NowScreen.badgeCount(of: model.engine) == 1)
    }

    /// A Relentless reminder rings as an alarm, which tells the app nothing when it comes due with
    /// the app in front. The minute the Now badge redraws, the model re-plans if the count changed,
    /// and only then (icon-badge spec, criterion 8).
    @Test func eachMinuteTheIconBadgeCatchesUpWithTheNowBadgeIfItChanged() async throws {
        let store = try ReminderStore(location: .inMemory)
        let alex = Reminder(title: "Reply to Alex", dueTime: NewYork.local(2026, 10, 15, 8, 40), strength: .relentless)
        let model = await launchedModel(store: store)
        model.add(alex)
        await model.waitUntilApplied()
        #expect(center.badgeCounts.last == 0)

        clock.now = NewYork.local(2026, 10, 15, 8, 40)
        model.minutePassed()
        await model.waitUntilApplied()
        #expect(center.badgeCounts.last == 1)

        let badgeSets = center.badgeCounts.count
        clock.now = NewYork.local(2026, 10, 15, 8, 41)
        model.minutePassed()
        await model.waitUntilApplied()
        #expect(center.badgeCounts.count == badgeSets)
    }

    /// Done from a notification closes Call's occurrence, so the pending notifications of Water, due
    /// while Call was still Nudging, are re-stamped with the lower count (icon-badge spec,
    /// decision 4: `content.badge` is fixed, so a stamp left from before would be wrong).
    @Test func aDoneFromANotificationRestampsThePendingNotifications() async throws {
        let store = try ReminderStore(location: .inMemory)
        let water = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 9), strength: .gentle)
        clock.now = NewYork.local(2026, 10, 15, 8, 45)
        let (model, notifications) = model(store: store)
        await model.launch()
        model.add(call)
        model.add(water)
        await model.waitUntilApplied()
        func waterStamps() -> [Int] {
            center.pending.filter { $0.content.title == water.title }.compactMap { $0.content.badge?.intValue }
        }
        #expect(waterStamps().first == 2)

        await chooseDone(on: notifications, nudgeFiredAt: NewYork.local(2026, 10, 15, 8, 40))

        #expect(!waterStamps().isEmpty && waterStamps().allSatisfy { $0 == 1 })
    }

    /// An occurrence that closes as Missed at its give-up sends no alert, so nothing tells the app
    /// (icon-badge spec, decision 10). The minute tick re-plans, and the pending notifications keep
    /// the stamps of the new plan: the next reminder's nudges carry the count without the one that
    /// gave up.
    @Test func anOccurrenceThatGaveUpLeadsToARebuiltPlanWithFreshStamps() async throws {
        let store = try ReminderStore(location: .inMemory)
        let alex = Reminder(title: "Reply to Alex", dueTime: NewYork.local(2026, 10, 15, 8, 40), strength: .gentle)
        let water = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 16, 9), strength: .gentle)
        clock.now = NewYork.local(2026, 10, 15, 8, 45)
        let model = await launchedModel(store: store)
        model.add(alex)
        model.add(water)
        await model.waitUntilApplied()
        #expect(center.badgeCounts.last == 1)
        // Gentle gives up at +8 h 4 min 4 s, so Water's nudges, tomorrow, find Alex already gone.
        let stampBefore = try #require(center.pending.first { $0.content.title == water.title }).content.badge
        #expect(stampBefore == 1)

        clock.now = NewYork.local(2026, 10, 15, 17)
        model.minutePassed()
        await model.waitUntilApplied()

        #expect(center.badgeCounts.last == 0)
        #expect(model.engine.badgeCount == 0)
        let stamps = center.pending.filter { $0.content.title == water.title }.map(\.content.badge)
        #expect(!stamps.isEmpty && stamps.allSatisfy { $0 == 1 })
    }

    /// A Done the engine ignores, here from a banner left from an earlier occurrence, applies no
    /// plan of its own. The icon may be stale (two reminders came due while the app was
    /// suspended), and the app is awake, so it sets the live count anyway (icon-badge spec,
    /// decision 4).
    @Test func aDoneTheEngineIgnoresStillSetsTheIconBadgeToTheLiveCount() async throws {
        let store = try ReminderStore(location: .inMemory)
        let water = Reminder(title: "Water the plants", dueTime: NewYork.local(2026, 10, 15, 8, 30), strength: .gentle)
        let (model, notifications) = model(store: store)
        await model.launch()
        model.add(call)
        model.add(water)
        await model.waitUntilApplied()
        #expect(center.badgeCounts.last == 0)

        clock.now = NewYork.local(2026, 10, 15, 8, 45)
        await chooseDone(on: notifications, nudgeFiredAt: NewYork.local(2026, 10, 15, 8, 20))

        #expect(model.engine.openOccurrence(for: call.id) != nil)
        #expect(center.badgeCounts.last == 2)
    }

    /// A nudge delivered with the app in front: the last plan was built before its occurrence came
    /// due, so it counted it out. The delivery re-plans, so the plan carries the live count
    /// (icon-badge spec, criterion 8).
    @Test func aNudgeDeliveredWithTheAppInFrontSetsTheIconBadgeToTheLiveCount() async throws {
        let store = try ReminderStore(location: .inMemory)
        let (model, notifications) = model(store: store)
        await model.launch()
        model.add(call)
        await model.waitUntilApplied()
        #expect(center.badgeCounts.last == 0)

        clock.now = NewYork.local(2026, 10, 15, 8, 40)
        notifications.handlePresentation()
        await model.waitUntilApplied()

        #expect(center.badgeCounts.last == 1)
        #expect(NowScreen.badgeCount(of: model.engine) == 1)
    }

    /// The alarm's Open: the ring stops (ticket 02 B), and the app shows the reminder's details,
    /// where Done is then the same `markDone` as everywhere else in the app.
    @Test func openStopsTheAlarmThatRangAndShowsTheRemindersDetailsWhereDoneClosesItsOccurrence() async throws {
        let store = try ReminderStore(location: .inMemory)
        let model = await launchedModel(store: store)
        model.add(call)
        await model.waitUntilApplied()
        let ringing = try #require(manager.scheduled.first { $0.fireDate == NewYork.local(2026, 10, 15, 9, 32, 30) })
        clock.now = NewYork.local(2026, 10, 15, 9, 33)
        manager.ring(ringing.id)

        await model.open(alarmID: ringing.id, reminderID: call.id)

        #expect(manager.stoppedIDs == [ringing.id])
        #expect(model.route == .reminderDetails(call.id))

        model.markDone(call.id)
        await model.waitUntilApplied()
        #expect(model.engine.latestOccurrence(for: call.id)?.state == .done)
        #expect(center.pending.isEmpty)
        #expect(manager.scheduled.isEmpty)
        #expect(try store.load().histories[call.id]?.closedOccurrences[call.dueTime]?.state == .done)
    }

    /// The whole Open, from the intent the alarm runs, through the opener the app registers at
    /// launch. The system resolves that opener only in its own run of the intent, so it is set by
    /// hand here.
    @Test func theOpenIntentStopsItsAlarmAndShowsItsReminderThroughTheAppsOpener() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        model.add(call)
        await model.waitUntilApplied()
        let ringing = try #require(manager.scheduled.first { $0.fireDate == NewYork.local(2026, 10, 15, 9, 32, 30) })
        clock.now = NewYork.local(2026, 10, 15, 9, 33)
        manager.ring(ringing.id)
        let intent = OpenReminderIntent(alarmID: ringing.id, reminderID: call.id)
        intent.opener = model.alarmOpener

        _ = try await intent.perform()

        #expect(manager.stoppedIDs == [ringing.id])
        #expect(model.route == .reminderDetails(call.id))
    }

    /// The alarm's Stop, from the intent it runs, through the refresher the app registers at
    /// launch (set by hand here, as for Open). The icon was stale: the last plan came before the
    /// alarm rang. Stop sets the live count and does nothing else (ADR 0001): no alarm stopped or
    /// cancelled, the occurrence still Nudging, and its 17 alarms all still held.
    @Test func theStopIntentSetsTheIconBadgeToTheLiveCountAndLeavesTheOccurrenceNudging() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        model.add(call)
        await model.waitUntilApplied()
        #expect(center.badgeCounts.last == 0)
        let ringing = try #require(manager.scheduled.first { $0.fireDate == NewYork.local(2026, 10, 15, 9, 32, 30) })
        clock.now = NewYork.local(2026, 10, 15, 9, 33)
        manager.ring(ringing.id)
        let intent = RefreshBadgeIntent()
        intent.refresher = model.badgeRefresher

        _ = try await intent.perform()

        #expect(center.badgeCounts.last == 1)
        #expect(manager.stoppedIDs.isEmpty)
        #expect(manager.cancelledIDs.isEmpty)
        #expect(model.engine.openOccurrence(for: call.id)?.state == .nudging(nudgeNumber: 4))
        #expect(manager.scheduled.count == 17)
    }

    /// A Stop before the first unlock since a restart, when the store can't be read: there is no
    /// count to set, so the icon is left alone until the store opens (as for a queued Done).
    @Test func aStopWhileTheStoreCantBeReadLeavesTheIconBadgeAlone() async throws {
        let model = model(openingStoreWith: { throw StoreWontOpen() }).model

        await model.refreshBadge()

        guard case .storeUnreadable = model.launchState else {
            Issue.record("Launched as \(model.launchState)")
            return
        }
        #expect(center.badgeCounts.isEmpty)
        #expect(manager.scheduleCalls.isEmpty)
    }

    /// An alarm left from a reminder since deleted, for example. The details screen says it isn't
    /// found (ticket 27), rather than the person landing on Now with no word of why.
    @Test func openForAReminderTheAppDoesntHoldShowsItsDetailsToSayNotFound() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        let alarmID = UUID()

        await model.open(alarmID: alarmID, reminderID: call.id)

        #expect(manager.stoppedIDs == [alarmID])
        #expect(model.route == .reminderDetails(call.id))
    }

    /// An alarm already stopped, by its own Stop or a Done, for example. The person still lands on
    /// the reminder.
    @Test func anOpenWhoseAlarmWontStopStillShowsTheRemindersDetails() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        model.add(call)
        manager.stopError = CocoaError(.featureUnsupported)

        await model.open(alarmID: UUID(), reminderID: call.id)

        #expect(model.route == .reminderDetails(call.id))
    }

    /// A Done before the first unlock can leave the store unread (see the test above). Open runs
    /// only once the person has authenticated, so it tries the store again before it routes.
    @Test func anOpenTriesAStoreThatCouldntBeOpenedAgainBeforeItRoutes() async throws {
        let store = try ReminderStore(location: .inMemory)
        try store.save(StoredData(reminders: [call], tags: [], histories: [:]))
        var attempts = 0
        let model = model(openingStoreWith: {
            attempts += 1
            if attempts == 1 { throw StoreWontOpen() }
            return store
        }).model
        await model.launch()

        await model.open(alarmID: UUID(), reminderID: call.id)

        #expect(model.engine.reminders == [call])
        #expect(model.route == .reminderDetails(call.id))
    }

    /// Open launches the app if it isn't running. The ring stops before the store is read, and the
    /// route waits for it: set sooner, the details would show "Reminder Not Found" until it loads.
    @Test func anOpenThatLaunchesTheAppStopsTheRingFirstAndRoutesOnceTheStoreIsRead() async throws {
        let store = try ReminderStore(location: .inMemory)
        try store.save(StoredData(reminders: [call], tags: [], histories: [:]))
        let alarmID = UUID()
        var stoppedBeforeTheStoreOpened: [UUID]?
        let model = model(openingStoreWith: { [manager] in
            stoppedBeforeTheStoreOpened = manager.stoppedIDs
            return store
        }).model

        await model.open(alarmID: alarmID, reminderID: call.id)

        #expect(stoppedBeforeTheStoreOpened == [alarmID])
        #expect(model.route == .reminderDetails(call.id))
        #expect(model.engine.reminders == [call])
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
