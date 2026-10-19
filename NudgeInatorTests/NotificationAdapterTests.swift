import Foundation
import Testing
import NudgeEngine
import UserNotifications
@testable import NudgeInator

/// The notification adapter applies a plan's notification items to the user notification center.
/// Each test hands it a plan, waits for it to finish, and reads what the fake center holds.
@MainActor
struct NotificationAdapterTests {
    static let pills = UUID(uuidString: "6F1C2A4E-0B7D-4E8A-9C3F-1D2E3F4A5B6C")!
    /// The request identifiers of the pills' nudges at 9:10, 9:20, 9:30 and 9:45 in New York
    /// (EDT), which are 13:10, 13:20, 13:30 and 13:45 UTC, for the occurrence due at 9:00 (13:00).
    static let pillsAt0910 = "nudge.6F1C2A4E-0B7D-4E8A-9C3F-1D2E3F4A5B6C.1792155600000.1792156200000"
    static let pillsAt0920 = "nudge.6F1C2A4E-0B7D-4E8A-9C3F-1D2E3F4A5B6C.1792155600000.1792156800000"
    static let pillsAt0930 = "nudge.6F1C2A4E-0B7D-4E8A-9C3F-1D2E3F4A5B6C.1792155600000.1792157400000"
    static let pillsAt0945 = "nudge.6F1C2A4E-0B7D-4E8A-9C3F-1D2E3F4A5B6C.1792155600000.1792158300000"
    /// The pills' occurrence due at 9:00 on 16 October, which the nudges above are for.
    static let pillsDueTime = NewYork.local(2026, 10, 16)

    let clock = FakeClock(now: NewYork.local(2026, 10, 16, 9))
    let center = FakeNotificationCenter()

    func adapter() -> NotificationAdapter {
        NotificationAdapter(center: center, clock: clock)
    }

    func nudge(
        _ nudgeNumber: Int,
        at fireTime: Date,
        _ urgency: Urgency,
        _ deliveryKind: DeliveryKind,
        of reminderID: UUID = pills,
        dueAt dueTime: Date = pillsDueTime,
        title: String = "Take the pills",
        isPastAlarmLimit: Bool = false
    ) -> SchedulePlan.Item {
        SchedulePlan.Item(
            reminderID: reminderID,
            dueTime: dueTime,
            nudgeNumber: nudgeNumber,
            // Every shipped ladder sends 20 before it gives up.
            nudgesInAll: 20,
            fireTime: fireTime,
            urgency: urgency,
            title: title,
            deliveryKind: deliveryKind,
            isPastAlarmLimit: isPastAlarmLimit
        )
    }

    /// The center's requests in identifier order, which is soonest first within one reminder.
    func pending() -> [UNNotificationRequest] {
        center.pending.sorted { $0.identifier < $1.identifier }
    }

    @Test func aPlanOfThreeNotificationsSchedulesThreeRequests() async throws {
        let adapter = adapter()

        adapter.apply(SchedulePlan(items: [
            nudge(1, at: NewYork.local(2026, 10, 16, 9, 10), .normal, .notification),
            nudge(2, at: NewYork.local(2026, 10, 16, 9, 30), .high, .timeSensitiveNotification),
            nudge(3, at: NewYork.local(2026, 10, 16, 9, 45), .high, .notification),
        ]))
        await adapter.waitUntilApplied()

        let requests = pending()
        #expect(requests.map(\.identifier) == [Self.pillsAt0910, Self.pillsAt0930, Self.pillsAt0945])
        #expect(requests.map { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval } == [600, 1800, 2700])
        #expect(requests.map { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.repeats } == [false, false, false])
        #expect(requests.map(\.content.title) == ["Take the pills", "Take the pills", "Take the pills"])
        #expect(requests.map(\.content.body) == ["Nudge 1 of 20 · Normal", "Nudge 2 of 20 · High", "Nudge 3 of 20 · High"])
        #expect(requests.map(\.content.interruptionLevel) == [.active, .timeSensitive, .active])
    }

    @Test func creatingTheAdapterRegistersOneCategoryWithOnlyADoneActionThatNeedsNoUnlock() throws {
        _ = adapter()

        let category = try #require(center.categories?.only)
        let action = try #require(category.actions.only)
        #expect(action.title == "Done")
        // No .foreground (it opens the app) and no .authenticationRequired (it needs an unlocked
        // phone), so Done can run from the Lock Screen.
        #expect(action.options == [])
    }

    /// Apple: without the delegate's `didReceive`, "your app never responds to custom actions".
    @Test func creatingTheAdapterSetsADelegateThatLivesAsLongAsTheAdapter() {
        let adapter = adapter()

        #expect(center.delegate != nil)
        withExtendedLifetime(adapter) {}
    }

    @Test func everyRequestCarriesTheDoneCategoryAndItsReminder() async throws {
        let adapter = adapter()
        let bins = UUID(uuidString: "0A1B2C3D-4E5F-4061-8273-8495A6B7C8D9")!

        adapter.apply(SchedulePlan(items: [
            nudge(1, at: NewYork.local(2026, 10, 16, 9, 10), .normal, .notification),
            nudge(2, at: NewYork.local(2026, 10, 16, 9, 30), .high, .timeSensitiveNotification, of: bins),
        ]))
        await adapter.waitUntilApplied()

        let category = try #require(center.categories?.only)
        let requests = pending()
        #expect(requests.map(\.content.categoryIdentifier) == [category.identifier, category.identifier])
        #expect(requests.map { $0.content.userInfo["reminderID"] as? String } == [
            "0A1B2C3D-4E5F-4061-8273-8495A6B7C8D9",
            "6F1C2A4E-0B7D-4E8A-9C3F-1D2E3F4A5B6C",
        ])
    }

    /// Mirrors the delegate: it reads the nudge from the delivered request's `userInfo`. The fire
    /// time goes along so the engine can tell an earlier occurrence's banner from today's, and the
    /// due time so a Done before the first unlock can name its occurrence (ticket 32).
    @Test func theDoneActionReportsDoneForTheNotificationsNudge() async throws {
        let adapter = adapter()
        let events = FakeNotificationEvents()
        adapter.events = events
        adapter.apply(SchedulePlan(items: [nudge(1, at: NewYork.local(2026, 10, 16, 9, 10), .normal, .notification)]))
        await adapter.waitUntilApplied()
        let delivered = try #require(pending().only)

        await adapter.handleResponse(
            actionIdentifier: NotificationAdapter.doneActionIdentifier,
            nudge: NotificationAdapter.deliveredNudge(in: delivered.content.userInfo)
        )

        #expect(events.dones == [DeliveredNudge(reminderID: Self.pills, dueTime: Self.pillsDueTime, fireTime: NewYork.local(2026, 10, 16, 9, 10))])
    }

    /// The engine closes the occurrence only if the nudge fired at or after its due time, so the
    /// fire time must come back exactly. Real due times have fractions of a second; on the iPhone
    /// a Done was ignored because the fire time came back a hair early (ticket 21).
    @Test(arguments: [0.1234567, 0.5, 0.999_999_9, 0.000_000_1])
    func aDeliveredNudgeCarriesItsFireTimeExactly(fraction: Double) async throws {
        let adapter = adapter()
        let fireTime = NewYork.local(2026, 10, 16, 9, 10) + fraction
        adapter.apply(SchedulePlan(items: [nudge(1, at: fireTime, .normal, .notification)]))
        await adapter.waitUntilApplied()
        let delivered = try #require(pending().only)

        #expect(NotificationAdapter.deliveredNudge(in: delivered.content.userInfo)?.fireTime == fireTime)
    }

    /// A Done before the first unlock stops its occurrence's nudges with no store to plan from
    /// (ticket 32). Only that occurrence's: the next one's ladder, another reminder's nudges and
    /// the test nudge stay.
    @Test func cancellingAnOccurrencesNudgesRemovesOnlyItsPendingRequests() async throws {
        let adapter = adapter()
        let bins = UUID(uuidString: "0A1B2C3D-4E5F-4061-8273-8495A6B7C8D9")!
        let tomorrow = NewYork.local(2026, 10, 17)
        adapter.apply(SchedulePlan(items: [
            nudge(1, at: NewYork.local(2026, 10, 16, 9, 10), .normal, .notification),
            nudge(2, at: NewYork.local(2026, 10, 16, 9, 20), .normal, .notification),
            nudge(1, at: NewYork.local(2026, 10, 17, 9, 10), .normal, .notification, dueAt: tomorrow),
            nudge(1, at: NewYork.local(2026, 10, 16, 9, 30), .normal, .notification, of: bins),
        ]))
        await adapter.sendTestNudge()
        await adapter.waitUntilApplied()

        await adapter.cancelNudges(of: Self.pills, dueAt: Self.pillsDueTime)

        #expect(Set(center.pending.map(\.identifier)) == [
            "nudge.6F1C2A4E-0B7D-4E8A-9C3F-1D2E3F4A5B6C.1792242000000.1792242600000",
            "nudge.0A1B2C3D-4E5F-4061-8273-8495A6B7C8D9.1792155600000.1792157400000",
            NotificationAdapter.testNudgeIdentifier,
        ])
    }

    /// The Done action can launch the app in the background, and the response may come before the
    /// app model is listening (ticket 21). It waits rather than being lost.
    @Test func aDoneBeforeAnyoneListensIsReportedOnceSomeoneDoes() async {
        let adapter = adapter()
        let events = FakeNotificationEvents()
        let nudge = DeliveredNudge(reminderID: Self.pills, dueTime: Self.pillsDueTime, fireTime: NewYork.local(2026, 10, 16, 9, 10))

        await adapter.handleResponse(actionIdentifier: NotificationAdapter.doneActionIdentifier, nudge: nudge)
        adapter.events = events
        adapter.events = events
        for _ in 0..<100 where events.dones.isEmpty {
            await Task.yield()
        }

        #expect(events.dones == [nudge])
    }

    @Test(arguments: [
        UNNotificationDefaultActionIdentifier,
        UNNotificationDismissActionIdentifier,
    ])
    func openingOrDismissingANotificationIsNotDone(actionIdentifier: String) async {
        let adapter = adapter()
        let events = FakeNotificationEvents()
        adapter.events = events

        await adapter.handleResponse(
            actionIdentifier: actionIdentifier,
            nudge: DeliveredNudge(reminderID: Self.pills, dueTime: Self.pillsDueTime, fireTime: NewYork.local(2026, 10, 16, 9, 10))
        )

        #expect(events.dones.isEmpty)
    }

    /// `UNAuthorizationOptions.timeSensitive` is deprecated: the entitlement and the interruption
    /// level make a notification Time Sensitive, not the prompt.
    @Test func authorizationIsRequestedForAlertsAndSoundsOnly() async throws {
        let adapter = adapter()

        _ = try await adapter.requestAuthorization()

        #expect(center.requestedAuthorizationOptions == [[.alert, .sound]])
    }

    /// No notifications not-determined state: until the person answers, nothing is denied, and
    /// Time Sensitive reads on as on a fresh install.
    @Test(arguments: [
        (UNAuthorizationStatus.notDetermined, UNNotificationSetting.notSupported, NotificationPermission.allowed, TimeSensitiveSetting.on),
        (.notDetermined, .disabled, .allowed, .on),
        (.authorized, .enabled, .allowed, .on),
        (.authorized, .disabled, .allowed, .off),
        (.authorized, .notSupported, .allowed, .off),
        (.provisional, .enabled, .allowed, .on),
        (.provisional, .disabled, .allowed, .off),
        (.ephemeral, .enabled, .allowed, .on),
        (.denied, .disabled, .denied, .off),
        (.denied, .enabled, .denied, .on),
    ])
    func theCentersSettingsBecomeTheEnginesPermissionInputs(
        status: UNAuthorizationStatus,
        timeSensitiveSetting: UNNotificationSetting,
        notifications: NotificationPermission,
        timeSensitive: TimeSensitiveSetting
    ) async {
        let adapter = adapter()
        center.settings = NotificationSettingsSnapshot(authorizationStatus: status, timeSensitiveSetting: timeSensitiveSetting)

        let states = await adapter.permissions(updating: PermissionStates(alarms: .denied))

        #expect(states == PermissionStates(notifications: notifications, alarms: .denied, timeSensitive: timeSensitive))
    }

    /// Apple: scheduling while not authorized fails with `notificationsNotAllowed`.
    @Test func aRefusedRequestIsReportedOncePerPlan() async throws {
        let adapter = adapter()
        let events = FakeNotificationEvents()
        adapter.events = events
        center.addError = UNError(.notificationsNotAllowed)

        adapter.apply(SchedulePlan(items: [
            nudge(1, at: NewYork.local(2026, 10, 16, 9, 10), .normal, .notification),
            nudge(2, at: NewYork.local(2026, 10, 16, 9, 30), .high, .timeSensitiveNotification),
        ]))
        await adapter.waitUntilApplied()

        let error = try #require(events.schedulingErrors.only as? UNError)
        #expect(error.code == .notificationsNotAllowed)
    }

    /// Privacy: notifications carry the title and "Nudge N of 20 · Urgency", never notes or tags.
    /// Through the engine, so the plan is a real one.
    @Test func noRequestCarriesTheRemindersNotesOrTags() async throws {
        let adapter = adapter()
        let health = Tag(name: "health")
        var engine = Engine(clock: clock, scheduler: adapter, timeZone: NewYork.timeZone)
        engine.update(tags: [health])

        engine.update(reminders: [
            Reminder(
                title: "Take the pills",
                notes: "With food",
                tagIDs: [health.id],
                dueTime: NewYork.local(2026, 10, 16, 9, 5),
                strength: .gentle,
                breakThroughFocus: false
            ),
        ])
        await adapter.waitUntilApplied()

        let requests = pending()
        #expect(requests.count == 20)
        for request in requests {
            let content = request.content
            let text = [content.title, content.subtitle, content.body] + content.userInfo.values.map { "\($0)" }
            #expect(!text.contains { $0.localizedStandardContains("With food") || $0.localizedStandardContains("health") })
            #expect(Set(content.userInfo.keys.compactMap { $0 as? String }) == ["reminderID", "dueTime", "fireTime"])
        }
    }

    /// The person turned Time Sensitive off after the first one arrived: on the next foreground the
    /// adapter reads it, the engine re-plans, and High nudges come as ordinary notifications.
    @Test func timeSensitiveTurnedOffReachesTheEngineAndHighNudgesBecomeOrdinary() async throws {
        let adapter = adapter()
        center.settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: .enabled)
        var engine = Engine(
            clock: clock,
            scheduler: adapter,
            timeZone: NewYork.timeZone,
            permissions: await adapter.permissions(updating: PermissionStates(alarms: .allowed))
        )
        engine.update(reminders: [
            Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 16, 9, 5), strength: .firm),
        ])
        await adapter.waitUntilApplied()
        #expect(pending().contains { $0.content.interruptionLevel == .timeSensitive })

        center.settings = NotificationSettingsSnapshot(authorizationStatus: .authorized, timeSensitiveSetting: .disabled)
        engine.update(permissions: await adapter.permissions(updating: PermissionStates(alarms: .allowed)))
        await adapter.waitUntilApplied()

        #expect(!pending().isEmpty)
        #expect(!pending().contains { $0.content.interruptionLevel == .timeSensitive })
    }

    @Test func aSmallerPlanRemovesTheRequestsNoLongerInIt() async throws {
        let adapter = adapter()
        let first = nudge(1, at: NewYork.local(2026, 10, 16, 9, 10), .normal, .notification)
        let second = nudge(2, at: NewYork.local(2026, 10, 16, 9, 30), .high, .notification)
        adapter.apply(SchedulePlan(items: [first, second]))

        adapter.apply(SchedulePlan(items: [second]))
        await adapter.waitUntilApplied()

        #expect(pending().map(\.identifier) == [Self.pillsAt0930])
    }

    @Test func anEmptyPlanRemovesEveryRequestOfTheAdaptersAndLeavesOthers() async throws {
        let adapter = adapter()
        let testNudge = UNNotificationRequest(identifier: "test-nudge", content: UNNotificationContent(), trigger: nil)
        try await center.add(testNudge)
        adapter.apply(SchedulePlan(items: [
            nudge(1, at: NewYork.local(2026, 10, 16, 9, 10), .normal, .notification),
            nudge(1, at: NewYork.local(2026, 10, 16, 9, 20), .normal, .notification, of: UUID(), title: "Put the bins out"),
        ]))

        adapter.apply(SchedulePlan(items: []))
        await adapter.waitUntilApplied()

        #expect(pending().map(\.identifier) == ["test-nudge"])
    }

    @Test func alarmItemsAreLeftToTheAlarmAdapter() async throws {
        let adapter = adapter()

        adapter.apply(SchedulePlan(items: [
            nudge(4, at: NewYork.local(2026, 10, 16, 9, 10), .urgent, .alarm),
            nudge(5, at: NewYork.local(2026, 10, 16, 9, 20), .urgent, .timeSensitiveNotification, isPastAlarmLimit: true),
        ]))
        await adapter.waitUntilApplied()

        #expect(pending().map(\.identifier) == [Self.pillsAt0920])
    }

    @Test func atMostTheSoonestSixtyFourNotificationsArePending() async throws {
        let adapter = adapter()
        let reminders = (0..<4).map { _ in UUID() }
        // Four full ladders, interleaved: reminder r's nudge n fires 4n + r minutes from now.
        let items = (1...20).flatMap { nudgeNumber in
            reminders.enumerated().map { offset, reminderID in
                nudge(
                    nudgeNumber,
                    at: clock.now + TimeInterval((4 * nudgeNumber + offset) * 60),
                    .normal,
                    .notification,
                    of: reminderID
                )
            }
        }

        adapter.apply(SchedulePlan(items: items.reversed()))
        await adapter.waitUntilApplied()

        let intervals = center.pending.compactMap { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval }
        #expect(intervals.sorted() == (4...67).map { TimeInterval($0 * 60) })
    }

    /// The system's 64 counts every pending request, so one the adapter didn't make takes a place.
    @Test func anotherPendingRequestLeavesRoomForSixtyThreeNudges() async throws {
        let adapter = adapter()
        try await center.add(UNNotificationRequest(identifier: "test-nudge", content: UNNotificationContent(), trigger: nil))
        let items = (1...70).map { minute in
            nudge(1, at: clock.now + TimeInterval(minute * 60), .normal, .notification, of: UUID())
        }

        adapter.apply(SchedulePlan(items: items))
        await adapter.waitUntilApplied()

        let intervals = center.pending.compactMap { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval }
        #expect(center.pending.count == 64)
        #expect(intervals.sorted() == (1...63).map { TimeInterval($0 * 60) })
    }

    @Test func aNewTitleReplacesThePendingRequestsContent() async throws {
        let adapter = adapter()
        let fireTime = NewYork.local(2026, 10, 16, 9, 10)
        adapter.apply(SchedulePlan(items: [nudge(2, at: fireTime, .high, .notification)]))

        adapter.apply(SchedulePlan(items: [
            nudge(2, at: fireTime, .high, .notification, title: "Take the blue pills"),
        ]))
        await adapter.waitUntilApplied()

        let request = try #require(pending().only)
        #expect(request.content.title == "Take the blue pills")
    }

    @Test func applyingTheSamePlanAgainAddsNothing() async throws {
        let adapter = adapter()
        let plan = SchedulePlan(items: [
            nudge(1, at: NewYork.local(2026, 10, 16, 9, 10), .normal, .notification),
            nudge(2, at: NewYork.local(2026, 10, 16, 9, 30), .high, .timeSensitiveNotification),
        ])
        adapter.apply(plan)
        await adapter.waitUntilApplied()
        let addedBefore = center.added.count

        adapter.apply(plan)
        await adapter.waitUntilApplied()

        #expect(center.added.count == addedBefore)
        #expect(pending().count == 2)
    }

    /// Ticket 13: the plan still holds an open ladder's passed nudges, which were delivered.
    @Test(arguments: [
        NewYork.local(2026, 10, 16, 8, 50),
        NewYork.local(2026, 10, 16, 9),
    ])
    func aNudgeWhoseFireTimeHasPassedIsNotScheduledAgain(firedAt fireTime: Date) async throws {
        let adapter = adapter()

        adapter.apply(SchedulePlan(items: [
            nudge(1, at: fireTime, .normal, .notification),
            nudge(2, at: NewYork.local(2026, 10, 16, 9, 30), .normal, .notification),
        ]))
        await adapter.waitUntilApplied()

        #expect(pending().map(\.identifier) == [Self.pillsAt0930])
    }
}
