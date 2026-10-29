import AlarmKit
import AppIntents
import Foundation
import NudgeEngine
import NudgeShared
import SwiftUI
import Testing
@testable import NudgeInator

/// The alarm adapter applies a plan's alarm items through AlarmKit. Each test hands it a plan,
/// waits for it to finish, and reads what the fake manager holds.
@MainActor
struct AlarmAdapterTests {
    static let pills = UUID(uuidString: "6F1C2A4E-0B7D-4E8A-9C3F-1D2E3F4A5B6C")!

    let clock = FakeClock(now: NewYork.local(2026, 10, 16, 9))
    let manager = FakeAlarmManager()

    func adapter() -> AlarmAdapter {
        AlarmAdapter(manager: manager, clock: clock)
    }

    func nudge(
        _ nudgeNumber: Int,
        at fireTime: Date,
        _ deliveryKind: DeliveryKind = .alarm,
        of reminderID: UUID = pills,
        dueAt dueTime: Date = NewYork.local(2026, 10, 16),
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
            urgency: .urgent,
            title: title,
            deliveryKind: deliveryKind,
            isPastAlarmLimit: isPastAlarmLimit
        )
    }

    @Test func aPlanOfFourAlarmsSchedulesFourTitleOnlyAlarmsAtTheirFireTimes() async throws {
        let adapter = adapter()
        let fireTimes = [
            NewYork.local(2026, 10, 16, 9, 10),
            NewYork.local(2026, 10, 16, 9, 15),
            NewYork.local(2026, 10, 16, 9, 18),
            NewYork.local(2026, 10, 16, 9, 20),
        ]

        adapter.apply(SchedulePlan(items: fireTimes.enumerated().map { nudge($0.offset + 4, at: $0.element) }))
        await adapter.waitUntilApplied()

        let calls = manager.scheduleCalls
        #expect(calls.count == 4)
        #expect(calls.map(\.schedule) == fireTimes.map { .fixed($0) })
        #expect(Set(calls.map(\.id)).count == 4)
        for call in calls {
            let alert = call.attributes.presentation.alert
            // The title alone: no "Nudge N of 20", no urgency, no notes or tags.
            #expect(String(localized: alert.title) == "Take the pills")
            #expect(call.attributes.presentation.countdown == nil)
            #expect(call.attributes.presentation.paused == nil)
            #expect(call.attributes.metadata == NudgeAlarmMetadata())
        }
    }

    /// DESIGN.md's `alarm-tint` is `accent-dark`, #07DDE6, pinned in every appearance.
    @Test(arguments: [ColorScheme.light, .dark])
    func theAlarmIsTintedWithTheDesignsAlarmTint(in colorScheme: ColorScheme) async throws {
        let adapter = adapter()

        adapter.apply(SchedulePlan(items: [nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))]))
        await adapter.waitUntilApplied()

        var environment = EnvironmentValues()
        environment.colorScheme = colorScheme
        let tint = try #require(manager.scheduleCalls.first).attributes.tintColor.resolve(in: environment)
        #expect(abs(Double(tint.red) - 0x07 / 255.0) < 0.002)
        #expect(abs(Double(tint.green) - 0xDD / 255.0) < 0.002)
        #expect(abs(Double(tint.blue) - 0xE6 / 255.0) < 0.002)
        #expect(tint.opacity == 1)
    }

    /// Until ticket 20's Open intent is passed in, the alert has the system Stop button only: an
    /// Open button with no intent would do nothing, and ticket 02 showed Open without `stop(id:)`
    /// can leave a locked phone ringing.
    @Test func withoutAnOpenIntentTheAlertHasNoSecondaryButton() async throws {
        let adapter = adapter()

        adapter.apply(SchedulePlan(items: [nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))]))
        await adapter.waitUntilApplied()

        let call = try #require(manager.scheduleCalls.first)
        #expect(call.attributes.presentation.alert.secondaryButton == nil)
        #expect(call.attributes.presentation.alert.secondaryButtonBehavior == nil)
        #expect(call.secondaryIntent == nil)
    }

    /// Only what changed reaches AlarmKit (ticket 02's bulk-scheduling caution).
    @Test func replacingAPlanCancelsTheAlarmsNotInItAndSchedulesOnlyTheNewOnes() async throws {
        let adapter = adapter()
        let at0910 = nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))
        let at0915 = nudge(5, at: NewYork.local(2026, 10, 16, 9, 15))
        let at0918 = nudge(6, at: NewYork.local(2026, 10, 16, 9, 18))
        adapter.apply(SchedulePlan(items: [at0910, at0915]))
        await adapter.waitUntilApplied()
        let firstIDs = manager.scheduleCalls.map(\.id)

        adapter.apply(SchedulePlan(items: [at0915, at0918]))
        await adapter.waitUntilApplied()

        #expect(manager.cancelledIDs == [firstIDs[0]])
        #expect(manager.scheduleCalls.count == 3)
        #expect(manager.scheduled.compactMap(\.fireDate) == [at0915.fireTime, at0918.fireTime])
    }

    /// Nothing is saved: the IDs come from the nudges, so a relaunched adapter finds the alarms the
    /// last one scheduled.
    @Test func afterARelaunchTheSamePlanSchedulesAndCancelsNothing() async throws {
        let plan = SchedulePlan(items: [
            nudge(4, at: NewYork.local(2026, 10, 16, 9, 10)),
            nudge(5, at: NewYork.local(2026, 10, 16, 9, 15)),
        ])
        let first = adapter()
        first.apply(plan)
        await first.waitUntilApplied()

        let relaunched = adapter()
        relaunched.apply(plan)
        await relaunched.waitUntilApplied()

        #expect(manager.scheduleCalls.count == 2)
        #expect(manager.cancelledIDs.isEmpty)
    }

    /// AlarmKit can't say what a scheduled alarm shows, so a title Edit must replace the alarm.
    @Test func aNewTitleReplacesTheAlarm() async throws {
        let adapter = adapter()
        let fireTime = NewYork.local(2026, 10, 16, 9, 10)
        adapter.apply(SchedulePlan(items: [nudge(4, at: fireTime)]))
        await adapter.waitUntilApplied()

        adapter.apply(SchedulePlan(items: [nudge(4, at: fireTime, title: "Take the blue pills")]))
        await adapter.waitUntilApplied()

        let alarm = try #require(manager.scheduled.only)
        #expect(String(localized: alarm.attributes.presentation.alert.title) == "Take the blue pills")
        #expect(manager.cancelledIDs.count == 1)
    }

    /// Ticket 20's Open intent finds its alarm by this ID, so it is pinned to a value worked out
    /// independently (Python's `hashlib.sha1` with the same namespace and names): the first half
    /// names the occurrence (reminder and due time, ticket 32), the second the nudge (fire time and
    /// title), with RFC 9562's version 8 and variant bits.
    @Test func theAlarmIDIsAVersionEightUUIDOfTheOccurrenceAndTheNudge() {
        let id = AlarmAdapter.alarmID(for: nudge(4, at: NewYork.local(2026, 10, 16, 9, 10)))

        #expect(id.uuidString == "B922D948-47D5-8D7E-90E9-107121305AE8")
    }

    /// A Done before the first unlock stops its occurrence's alarms with no store, so no title, to
    /// plan from (ticket 32). Only that occurrence's alarms yet to ring: the next one's ladder,
    /// another reminder's alarms, and one already ringing, stay.
    @Test func cancellingAnOccurrencesNudgesCancelsOnlyItsAlarmsYetToRing() async throws {
        let adapter = adapter()
        let bins = UUID(uuidString: "0A1B2C3D-4E5F-4061-8273-8495A6B7C8D9")!
        let ringing = nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))
        let open = nudge(5, at: NewYork.local(2026, 10, 16, 9, 15))
        let next = nudge(4, at: NewYork.local(2026, 10, 17, 9, 10), dueAt: NewYork.local(2026, 10, 17))
        let other = nudge(4, at: NewYork.local(2026, 10, 16, 9, 12), of: bins)
        adapter.apply(SchedulePlan(items: [ringing, open, next, other]))
        await adapter.waitUntilApplied()
        manager.ring(AlarmAdapter.alarmID(for: ringing))

        await adapter.cancelNudges(of: Self.pills, dueAt: NewYork.local(2026, 10, 16))

        #expect(manager.cancelledIDs == [AlarmAdapter.alarmID(for: open)])
        #expect(Set(manager.scheduled.map(\.id)) == Set([ringing, next, other].map(AlarmAdapter.alarmID(for:))))
    }

    /// Ticket 13: the plan still holds an open ladder's passed nudges, which were delivered.
    @Test(arguments: [
        NewYork.local(2026, 10, 16, 8, 50),
        NewYork.local(2026, 10, 16, 9),
    ])
    func aNudgeWhoseFireTimeHasPassedIsNotScheduled(firedAt fireTime: Date) async throws {
        let adapter = adapter()

        adapter.apply(SchedulePlan(items: [
            nudge(4, at: fireTime),
            nudge(5, at: NewYork.local(2026, 10, 16, 9, 15)),
        ]))
        await adapter.waitUntilApplied()

        #expect(manager.scheduled.compactMap(\.fireDate) == [NewYork.local(2026, 10, 16, 9, 15)])
    }

    /// Notifications are the notification adapter's, including Urgent nudges past the alarm limit.
    @Test func notificationItemsAreLeftToTheNotificationAdapter() async throws {
        let adapter = adapter()

        adapter.apply(SchedulePlan(items: [
            nudge(1, at: NewYork.local(2026, 10, 16, 9, 10), .notification),
            nudge(2, at: NewYork.local(2026, 10, 16, 9, 12), .timeSensitiveNotification),
            nudge(4, at: NewYork.local(2026, 10, 16, 9, 15), .timeSensitiveNotification, isPastAlarmLimit: true),
            nudge(5, at: NewYork.local(2026, 10, 16, 9, 18)),
        ]))
        await adapter.waitUntilApplied()

        #expect(manager.scheduled.compactMap(\.fireDate) == [NewYork.local(2026, 10, 16, 9, 18)])
    }

    /// A re-plan, such as an Edit to another reminder, must not silence a nudge that is ringing:
    /// Stop and Open end the ring.
    @Test func aRingingAlarmIsNotCancelled() async throws {
        let adapter = adapter()
        let ringing = nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))
        let next = nudge(5, at: NewYork.local(2026, 10, 16, 9, 15))
        adapter.apply(SchedulePlan(items: [ringing, next]))
        await adapter.waitUntilApplied()
        manager.ring(AlarmAdapter.alarmID(for: ringing))
        clock.now = ringing.fireTime + 30

        adapter.apply(SchedulePlan(items: [ringing, next]))
        await adapter.waitUntilApplied()

        #expect(manager.cancelledIDs.isEmpty)
        #expect(manager.scheduled.map(\.state) == [.alerting, .scheduled])
    }

    /// Ticket 15: soonest first, so if AlarmKit runs out of room the latest nudges are the ones
    /// that fall back. Ties go by reminder ID, as in the engine's alarm cap.
    @Test func alarmsAreScheduledSoonestFirstWithTiesByReminderID() async throws {
        let adapter = adapter()
        let bins = UUID(uuidString: "0A1B2C3D-4E5F-4061-8273-8495A6B7C8D9")!

        adapter.apply(SchedulePlan(items: [
            nudge(6, at: NewYork.local(2026, 10, 16, 9, 18)),
            nudge(5, at: NewYork.local(2026, 10, 16, 9, 15)),
            nudge(4, at: NewYork.local(2026, 10, 16, 9, 10)),
            nudge(4, at: NewYork.local(2026, 10, 16, 9, 10), of: bins, title: "Put the bins out"),
        ]))
        await adapter.waitUntilApplied()

        #expect(manager.scheduleCalls.map { String(localized: $0.attributes.presentation.alert.title) } == [
            "Put the bins out", "Take the pills", "Take the pills", "Take the pills",
        ])
        #expect(manager.scheduleCalls.compactMap(\.fireDate) == [
            NewYork.local(2026, 10, 16, 9, 10),
            NewYork.local(2026, 10, 16, 9, 10),
            NewYork.local(2026, 10, 16, 9, 15),
            NewYork.local(2026, 10, 16, 9, 18),
        ])
    }

    /// Ticket 15: each `maximumLimitReached` goes to the engine, which hands back a plan with that
    /// nudge as a marked Time Sensitive notification, and the adapter applies it. Through a real
    /// engine, so the plan is a real one.
    @Test func eachAlarmPastTheSystemsLimitIsReportedAndTheReturnedPlanApplied() async throws {
        let adapter = adapter()
        let events = FakeAlarmEvents()
        adapter.events = events
        let scheduler = RecordingScheduler(passingTo: adapter)
        manager.alarmLimit = 2
        events.engine = Engine(clock: clock, scheduler: scheduler, timeZone: NewYork.timeZone)

        events.engine?.update(reminders: [
            Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 16, 9, 5), strength: .relentless),
        ])
        await adapter.waitUntilApplied()

        let firstAlarms = try #require(scheduler.appliedPlans.first).items.filter { $0.deliveryKind == .alarm }
        let plan = try #require(scheduler.lastPlan)
        #expect(firstAlarms.count > 2)
        #expect(manager.scheduled.compactMap(\.fireDate) == firstAlarms.prefix(2).map(\.fireTime))
        #expect(events.limitReports.map(\.fireTime) == firstAlarms.dropFirst(2).map(\.fireTime))
        #expect(plan.items.filter { $0.deliveryKind == .alarm }.map(\.fireTime) == firstAlarms.prefix(2).map(\.fireTime))
        #expect(plan.items.filter(\.isPastAlarmLimit).map(\.fireTime) == firstAlarms.dropFirst(2).map(\.fireTime))
    }

    /// Only the latest plan matters, so one replaced while it waited never reaches AlarmKit.
    @Test func aPlanReplacedBeforeItsTurnIsNotApplied() async throws {
        let adapter = adapter()

        adapter.apply(SchedulePlan(items: [nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))]))
        adapter.apply(SchedulePlan(items: [nudge(5, at: NewYork.local(2026, 10, 16, 9, 15))]))
        adapter.apply(SchedulePlan(items: [nudge(6, at: NewYork.local(2026, 10, 16, 9, 18))]))
        await adapter.waitUntilApplied()

        #expect(manager.scheduleCalls.compactMap(\.fireDate).allSatisfy { $0 != NewYork.local(2026, 10, 16, 9, 15) })
        #expect(manager.scheduled.compactMap(\.fireDate) == [NewYork.local(2026, 10, 16, 9, 18)])
    }

    @Test(arguments: [
        (AlarmManager.AuthorizationState.authorized, AlarmPermission.allowed),
        (.denied, .denied),
        (.notDetermined, .notDetermined),
    ])
    func alarmKitsAuthorizationBecomesTheEnginesAlarmPermission(
        state: AlarmManager.AuthorizationState,
        alarms: AlarmPermission
    ) async {
        let adapter = adapter()
        manager.authorizationState = state
        let others = PermissionStates(notifications: .denied, alarms: .allowed, timeSensitive: .off)

        let states = await adapter.permissions(updating: others)

        #expect(states == PermissionStates(notifications: .denied, alarms: alarms, timeSensitive: .off))
    }

    /// The acceptance criterion, through a real engine: denied reaches the engine as alarms
    /// denied, the engine plans no alarms, and nothing is scheduled.
    @Test func deniedAuthorizationReachesTheEngineAndNothingIsScheduled() async throws {
        let adapter = adapter()
        manager.authorizationState = .denied
        var engine = Engine(
            clock: clock,
            scheduler: adapter,
            timeZone: NewYork.timeZone,
            permissions: await adapter.permissions(updating: PermissionStates())
        )

        engine.update(reminders: [
            Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 16, 9, 5), strength: .relentless),
        ])
        await adapter.waitUntilApplied()

        #expect(engine.reach.urgent == .timeSensitiveNotification)
        #expect(manager.scheduleCalls.isEmpty)
    }

    /// The engine still thinks alarms are allowed (the person turned them off since the last
    /// read). AlarmKit would turn every one down, so none is tried, and one report per plan tells
    /// the app model to read the permissions again.
    @Test func whileDeniedAStalePlansAlarmsAreNotTriedAndTheRefusalIsReportedOnce() async throws {
        let adapter = adapter()
        let events = FakeAlarmEvents()
        adapter.events = events
        manager.authorizationState = .denied

        adapter.apply(SchedulePlan(items: [
            nudge(4, at: NewYork.local(2026, 10, 16, 9, 10)),
            nudge(5, at: NewYork.local(2026, 10, 16, 9, 15)),
        ]))
        await adapter.waitUntilApplied()

        #expect(manager.scheduleCalls.isEmpty)
        let error = try #require(events.schedulingErrors.only as? AlarmAdapterError)
        #expect(error == .alarmsNotAllowed)
    }

    /// The rest are still tried, but one report per plan, as the notification adapter does.
    @Test func anotherSchedulingErrorIsReportedOncePerPlan() async throws {
        let adapter = adapter()
        let events = FakeAlarmEvents()
        adapter.events = events
        manager.scheduleError = CocoaError(.featureUnsupported)

        adapter.apply(SchedulePlan(items: [
            nudge(4, at: NewYork.local(2026, 10, 16, 9, 10)),
            nudge(5, at: NewYork.local(2026, 10, 16, 9, 15)),
        ]))
        await adapter.waitUntilApplied()

        #expect(manager.scheduleCalls.count == 2)
        let error = try #require(events.schedulingErrors.only as? CocoaError)
        #expect(error.code == .featureUnsupported)
        #expect(events.limitReports.isEmpty)
    }

    /// Without the list there's nothing to diff against: scheduling could duplicate what's there
    /// and nothing is known to be stale. The plan waits for the next apply.
    @Test func whenTheAlarmsCantBeReadNothingChangesAndTheErrorIsReported() async throws {
        let adapter = adapter()
        let events = FakeAlarmEvents()
        adapter.events = events
        adapter.apply(SchedulePlan(items: [nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))]))
        await adapter.waitUntilApplied()
        manager.alarmsError = CocoaError(.fileReadUnknown)

        adapter.apply(SchedulePlan(items: [nudge(5, at: NewYork.local(2026, 10, 16, 9, 15))]))
        await adapter.waitUntilApplied()

        #expect(manager.scheduleCalls.count == 1)
        #expect(manager.cancelledIDs.isEmpty)
        let error = try #require(events.schedulingErrors.only as? CocoaError)
        #expect(error.code == .fileReadUnknown)
    }

    @Test(arguments: [
        (AlarmManager.AuthorizationState.authorized, true),
        (.denied, false),
    ])
    func requestingAuthorizationSaysWhetherThePersonAllowedAlarms(
        answer: AlarmManager.AuthorizationState,
        isAllowed: Bool
    ) async throws {
        let adapter = adapter()
        manager.authorizationState = .notDetermined
        manager.promptAnswer = answer

        #expect(try await adapter.requestAuthorization() == isAllowed)
        #expect(manager.authorizationRequests == 1)
    }

    /// The person can turn alarms off in Settings at any time. The app model then reads the
    /// permissions again and hands them to the engine (ticket 21).
    @Test func aChangeInAlarmAuthorizationIsReported() async throws {
        let adapter = adapter()
        let events = FakeAlarmEvents()
        adapter.events = events

        manager.changeAuthorization(to: .denied)
        for _ in 0..<100 where events.authorizationChanges == 0 {
            await Task.yield()
        }

        #expect(events.authorizationChanges == 1)
        #expect(await adapter.permissions(updating: PermissionStates()).alarms == .denied)
    }

    /// AlarmKit's state read is a synchronous call to the system, and right after a prompt is
    /// answered it froze the iPhone's main thread for 69 s, once for good (ticket 22's device
    /// runs). So the adapter reads it once, before any prompt, and then takes the state from
    /// AlarmKit's updates.
    @Test func afterAnUpdateTheStateIsNotReadAgain() async throws {
        let adapter = adapter()
        let events = FakeAlarmEvents()
        adapter.events = events
        manager.authorizationState = .notDetermined
        #expect(await adapter.permissions(updating: PermissionStates()).alarms == .notDetermined)

        manager.changeAuthorization(to: .authorized)
        for _ in 0..<100 where events.authorizationChanges == 0 {
            await Task.yield()
        }
        let afterUpdate = await adapter.permissions(updating: PermissionStates())
        adapter.apply(SchedulePlan(items: [nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))]))
        await adapter.waitUntilApplied()

        #expect(afterUpdate.alarms == .allowed)
        #expect(manager.scheduled.count == 1)
        #expect(manager.authorizationReads == 1)
    }

    /// AlarmKit prompts by itself on the first `schedule` if the app hasn't asked, so until
    /// onboarding asks, a plan's alarms wait (ticket 31). The prompt's answer re-plans them.
    @Test func noAlarmIsScheduledUntilThePersonHasBeenAsked() async throws {
        let adapter = adapter()
        manager.authorizationState = .notDetermined
        manager.promptAnswer = .authorized
        let plan = SchedulePlan(items: [nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))])

        adapter.apply(plan)
        await adapter.waitUntilApplied()
        #expect(manager.scheduleCalls.isEmpty)

        _ = try await adapter.requestAuthorization()
        adapter.apply(plan)
        await adapter.waitUntilApplied()
        #expect(manager.scheduled.count == 1)
    }

    /// The prompt's answer is the state: reading it straight after is what froze the iPhone.
    @Test func theAnswerToThePromptIsUsedWithoutReadingTheState() async throws {
        let adapter = adapter()
        manager.authorizationState = .notDetermined
        manager.promptAnswer = .denied

        _ = try await adapter.requestAuthorization()

        #expect(await adapter.permissions(updating: PermissionStates()).alarms == .denied)
        #expect(manager.authorizationReads == 0)
    }

    /// A read that never answers (the iPhone's worst case) can't hold up launch: after the time
    /// limit the state counts as not determined, and AlarmKit's updates fill it in.
    @Test func aStateReadThatNeverAnswersDoesNotHoldUpThePermissions() async throws {
        let adapter = AlarmAdapter(manager: manager, clock: clock, authorizationReadLimit: .milliseconds(50))
        manager.authorizationReadHangs = true

        #expect(await adapter.permissions(updating: PermissionStates()).alarms == .notDetermined)

        manager.changeAuthorization(to: .authorized)
        var alarms = AlarmPermission.notDetermined
        for _ in 0..<100 where alarms != .allowed {
            await Task.yield()
            alarms = await adapter.permissions(updating: PermissionStates()).alarms
        }
        #expect(alarms == .allowed)
    }

    /// Ticket 30's device check (iPhone 15, iOS 27.0.1): with the app suspended, alarms were turned
    /// off in Settings and `authorizationUpdates` said nothing, while a read off the main thread
    /// answered `denied` at once. So the adapter reads again each time the app comes forward.
    @Test func aChangeMadeInSettingsWithNoUpdateIsReadWhenTheAppComesForward() async throws {
        let adapter = adapter()
        manager.authorizationState = .authorized
        #expect(await adapter.permissions(updating: PermissionStates()).alarms == .allowed)

        manager.authorizationState = .denied
        #expect(await adapter.permissions(updating: PermissionStates()).alarms == .allowed)
        await adapter.refreshAuthorization()

        #expect(await adapter.permissions(updating: PermissionStates()).alarms == .denied)
    }

    /// A read that doesn't answer may still be stuck in AlarmKit, so a later refresh starts no
    /// second one, and the state stays as it was.
    @Test func aRefreshThatNeverAnswersKeepsTheStateAndStartsNoSecondRead() async throws {
        let adapter = AlarmAdapter(manager: manager, clock: clock, authorizationReadLimit: .milliseconds(50))
        manager.authorizationState = .authorized
        #expect(await adapter.permissions(updating: PermissionStates()).alarms == .allowed)
        manager.authorizationReadHangs = true
        manager.authorizationState = .denied

        await adapter.refreshAuthorization()
        await adapter.refreshAuthorization()

        #expect(await adapter.permissions(updating: PermissionStates()).alarms == .allowed)
        #expect(manager.authorizationReads == 2)
    }

    /// An update, or the prompt's answer, that comes while a read waits is newer than that read.
    @Test func anUpdateThatComesWhileARefreshWaitsIsNotOverwrittenByTheOlderRead() async throws {
        let adapter = adapter()
        manager.authorizationState = .authorized
        #expect(await adapter.permissions(updating: PermissionStates()).alarms == .allowed)
        manager.holdsAuthorizationReads = true
        let refresh = Task { await adapter.refreshAuthorization() }
        for _ in 0..<100 where manager.heldAuthorizationReadCount == 0 {
            await Task.yield()
        }
        #expect(manager.heldAuthorizationReadCount == 1)

        manager.changeAuthorization(to: .denied)
        // The update has landed before the older read is let go, or the test proves nothing.
        var alarms = AlarmPermission.allowed
        for _ in 0..<100 where alarms != .denied {
            await Task.yield()
            alarms = await adapter.permissions(updating: PermissionStates()).alarms
        }
        #expect(alarms == .denied)
        manager.releaseLatestAuthorizationRead(returning: .authorized)
        await refresh.value

        #expect(await adapter.permissions(updating: PermissionStates()).alarms == .denied)
    }

    /// Privacy: alarms carry only the title. Every field of each alarm's attributes is checked,
    /// through a real engine so the plan is a real one.
    @Test func noAlarmCarriesTheRemindersNotesTagsOrNudgeCount() async throws {
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
                strength: .relentless
            ),
        ])
        await adapter.waitUntilApplied()

        #expect(manager.scheduled.count == 20)
        for alarm in manager.scheduled {
            let presentation = alarm.attributes.presentation
            #expect(String(localized: presentation.alert.title) == "Take the pills")
            #expect(presentation.alert.secondaryButton == nil)
            #expect(presentation.countdown == nil)
            #expect(presentation.paused == nil)
            #expect(alarm.attributes.metadata == NudgeAlarmMetadata())
        }
    }

    /// Done ends the nudging: the plan drops the occurrence, and its alarms are cancelled.
    @Test func doneCancelsEveryAlarmOfTheOccurrence() async throws {
        let adapter = adapter()
        var engine = Engine(clock: clock, scheduler: adapter, timeZone: NewYork.timeZone)
        let reminder = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 16, 9, 5), strength: .relentless)
        engine.update(reminders: [reminder])
        await adapter.waitUntilApplied()
        let scheduledIDs = Set(manager.scheduled.map(\.id))
        clock.now = NewYork.local(2026, 10, 16, 9, 6)

        engine.markDone(reminder.id)
        await adapter.waitUntilApplied()

        #expect(!scheduledIDs.isEmpty)
        #expect(manager.scheduled.isEmpty)
        #expect(Set(manager.cancelledIDs) == scheduledIDs)
    }

    /// Review: at its fire time an alarm can still read `scheduled` for a moment before it rings.
    /// The plan still holds it (ticket 13), so a re-plan then must not cancel it.
    @Test func anAlarmAtItsFireTimeThatHasntRungYetIsNotCancelled() async throws {
        let adapter = adapter()
        let due = nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))
        adapter.apply(SchedulePlan(items: [due]))
        await adapter.waitUntilApplied()
        clock.now = due.fireTime

        adapter.apply(SchedulePlan(items: [due]))
        await adapter.waitUntilApplied()

        #expect(manager.cancelledIDs.isEmpty)
        #expect(manager.scheduled.count == 1)
    }

    /// Review: a plan replaced while it is still scheduling stops, rather than scheduling the rest
    /// of what the newer plan has dropped (ticket 02's bulk-scheduling caution).
    @Test func aPlanReplacedPartWayThroughStopsScheduling() async throws {
        let adapter = adapter()
        manager.whileScheduling = { [manager] in
            manager.whileScheduling = nil
            adapter.apply(SchedulePlan(items: []))
        }

        adapter.apply(SchedulePlan(items: [
            nudge(4, at: NewYork.local(2026, 10, 16, 9, 10)),
            nudge(5, at: NewYork.local(2026, 10, 16, 9, 15)),
            nudge(6, at: NewYork.local(2026, 10, 16, 9, 18)),
        ]))
        await adapter.waitUntilApplied()

        #expect(manager.scheduleCalls.count == 1)
        #expect(manager.scheduled.isEmpty)
    }

    /// Review: the same nudge twice in a plan is one alarm.
    @Test func theSameNudgeTwiceInAPlanIsScheduledOnce() async throws {
        let adapter = adapter()
        let item = nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))

        adapter.apply(SchedulePlan(items: [item, item]))
        await adapter.waitUntilApplied()

        #expect(manager.scheduleCalls.count == 1)
    }

    /// Review: a cancel AlarmKit turns down leaves a stale alarm to ring, so it is reported too.
    @Test func aRefusedCancelIsReported() async throws {
        let adapter = adapter()
        let events = FakeAlarmEvents()
        adapter.events = events
        adapter.apply(SchedulePlan(items: [nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))]))
        await adapter.waitUntilApplied()
        manager.cancelError = CocoaError(.featureUnsupported)

        adapter.apply(SchedulePlan(items: []))
        await adapter.waitUntilApplied()

        let error = try #require(events.schedulingErrors.only as? CocoaError)
        #expect(error.code == .featureUnsupported)
    }

    /// Ticket 20 passes its Open intent in. The button runs it (`.custom`) for the nudge that rang,
    /// with that alarm's ID, which the intent stops.
    @Test func anOpenIntentAddsAnOpenButtonThatRunsItForThatNudgesAlarm() async throws {
        let adapter = AlarmAdapter(manager: manager, clock: clock, openIntent: { item, alarmID in
            TestOpenIntent(alarmID: alarmID, reminderID: item.reminderID)
        })

        adapter.apply(SchedulePlan(items: [nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))]))
        await adapter.waitUntilApplied()

        let call = try #require(manager.scheduleCalls.first)
        let button = try #require(call.attributes.presentation.alert.secondaryButton)
        #expect(String(localized: button.text) == "Open")
        #expect(button.systemImageName == "arrow.up.forward.app")
        #expect(button.textColor == .black)
        #expect(call.attributes.presentation.alert.secondaryButtonBehavior == .custom)
        let intent = try #require(call.secondaryIntent as? TestOpenIntent)
        #expect(intent.alarmID == call.id)
        #expect(intent.reminderID == Self.pills)
    }

    /// Ticket 87 passes the Stop intent in, which refreshes the badge. Every alarm carries one, so
    /// any Stop runs app code.
    @Test func aStopIntentGoesOnEveryAlarm() async throws {
        let adapter = AlarmAdapter(manager: manager, clock: clock, stopIntent: { TestStopIntent() })

        adapter.apply(SchedulePlan(items: [
            nudge(4, at: NewYork.local(2026, 10, 16, 9, 10)),
            nudge(5, at: NewYork.local(2026, 10, 16, 9, 20)),
        ]))
        await adapter.waitUntilApplied()

        #expect(manager.scheduleCalls.count == 2)
        #expect(manager.scheduleCalls.allSatisfy { $0.stopIntent is TestStopIntent })
    }

    /// Without one, Stop is the system's alone and runs no app code.
    @Test func withoutAStopIntentTheAlarmCarriesNone() async throws {
        let adapter = adapter()

        adapter.apply(SchedulePlan(items: [nudge(4, at: NewYork.local(2026, 10, 16, 9, 10))]))
        await adapter.waitUntilApplied()

        let call = try #require(manager.scheduleCalls.first)
        #expect(call.stopIntent == nil)
    }
}

/// Stands in for ticket 87's Stop intent.
struct TestStopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop"

    func perform() async throws -> some IntentResult {
        .result()
    }
}

/// Stands in for ticket 20's Open intent.
struct TestOpenIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Open"
    var alarmID = UUID()
    var reminderID = UUID()

    func perform() async throws -> some IntentResult {
        .result()
    }
}
