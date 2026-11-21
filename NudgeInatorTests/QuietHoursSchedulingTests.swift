import AlarmKit
import Foundation
import NudgeEngine
import Testing
import UserNotifications
@testable import NudgeInator

/// Quiet hours applied when the app builds its plan (#368): what reaches the notification center
/// and the alarm manager with schedules set, changed and cleared, through the app model over the
/// fakes. Which nudges the engine holds is #367's; these check that nothing held is scheduled and
/// that a change re-plans once. A class so `deinit` removes the defaults each test wrote, even when
/// it fails.
@MainActor
final class QuietHoursSchedulingTests {
    let clock = FakeClock(now: NewYork.local(2026, 10, 15, 8))
    let center = FakeNotificationCenter()
    let manager = FakeAlarmManager()
    let suiteName = "QuietHoursSchedulingTests.\(UUID().uuidString)"
    let storeFile = TemporaryStoreFile()

    /// Thursday 15 October 2026 at 8:40, once. Firm sends nudges 1–3 at 8:40, 9:10 and 9:25 as
    /// notifications, then rings nudges 4–20 as alarms from 9:32:30.
    let call = Reminder(title: "Call the bank", dueTime: NewYork.local(2026, 10, 15, 8, 40), strength: .firm, createdAt: NewYork.local(2026, 10, 15, 8))

    deinit {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: suiteName))
    }

    /// A model before launch, as each launch makes one, over this test's schedules record and store
    /// file and new adapters on the shared fakes.
    func model() throws -> AppModel {
        AppModel(
            clock: clock,
            openStore: { [storeFile] in try ReminderStore(location: .file(storeFile.url)) },
            notifications: NotificationAdapter(center: center, clock: clock),
            alarms: AlarmAdapter(manager: manager, clock: clock),
            settingsRecords: .temporary(quietHours: QuietHoursRecord(defaults: try defaults())),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
    }

    func launchedModel() async throws -> AppModel {
        let model = try model()
        await model.launch()
        return model
    }

    /// A window on the days it starts on, in whole hours and minutes.
    func window(
        _ start: (Int, Int), to end: (Int, Int), days: Set<RepeatRule.Weekday> = [.thursday], isOn: Bool = true
    ) throws -> QuietHours {
        QuietHours(schedules: [
            try QuietHoursSchedule(
                start: TimeOfDay(hour: start.0, minute: start.1), end: TimeOfDay(hour: end.0, minute: end.1), days: days, isOn: isOn
            ),
        ])
    }

    /// Every nudge on the Thursday the tests run on.
    func allOfThursday() throws -> QuietHours {
        try window((0, 0), to: (23, 59))
    }

    func state(of id: Alarm.ID) -> Alarm.State? {
        manager.scheduled.first { $0.id == id }?.state
    }

    /// Whether nothing was ever handed to either scheduler.
    func expectNothingScheduled() {
        #expect(center.added.isEmpty)
        #expect(center.pending.isEmpty)
        #expect(manager.scheduleCalls.isEmpty)
        #expect(manager.scheduled.isEmpty)
    }

    // MARK: Nothing held reaches the schedulers

    struct Kind: Sendable, CustomTestStringConvertible {
        let strength: Strength
        let breakThroughFocus: Bool
        let testDescription: String
    }

    /// A notification, a Time Sensitive notification and an alarm, each as the engine plans them,
    /// and a Relentless reminder, which always breaks through Focus.
    nonisolated static let kinds = [
        Kind(strength: .gentle, breakThroughFocus: false, testDescription: "gentle, notifications"),
        Kind(strength: .gentle, breakThroughFocus: true, testDescription: "gentle, Break through Focus"),
        Kind(strength: .firm, breakThroughFocus: false, testDescription: "firm, Time Sensitive and alarms"),
        Kind(strength: .firm, breakThroughFocus: true, testDescription: "firm, Break through Focus"),
        Kind(strength: .relentless, breakThroughFocus: true, testDescription: "relentless"),
    ]

    func reminder(_ kind: Kind) -> Reminder {
        var reminder = call
        reminder.strength = kind.strength
        reminder.breakThroughFocus = kind.breakThroughFocus
        return reminder
    }

    @Test(arguments: kinds)
    func aWindowThatCoversEveryNudgeSchedulesNothing(_ kind: Kind) async throws {
        let model = try await launchedModel()
        model.quietHours = try allOfThursday()

        model.add(reminder(kind))
        await model.waitUntilApplied()

        expectNothingScheduled()
    }

    @Test(arguments: kinds)
    func theSameReminderWithNoScheduleIsScheduled(_ kind: Kind) async throws {
        let model = try await launchedModel()

        model.add(reminder(kind))
        await model.waitUntilApplied()

        #expect(!center.pending.isEmpty || !manager.scheduled.isEmpty)
    }

    /// The schedules are read from the record when the model launches, before its first plan.
    @Test func schedulesSavedBeforeALaunchHoldFromTheFirstPlan() async throws {
        let first = try model()
        first.quietHours = try allOfThursday()
        let store = try ReminderStore(location: .file(storeFile.url))
        try store.save(StoredData(reminders: [call], tags: [], histories: [:]))

        let relaunched = try await launchedModel()
        await relaunched.waitUntilApplied()

        #expect(relaunched.engine.reminders == [call])
        expectNothingScheduled()
    }

    @Test func aWindowOnlyHoldsWhatFallsInsideIt() async throws {
        let model = try await launchedModel()
        // From 9:20 on: the third notification (9:25) and every alarm are held.
        model.quietHours = try window((9, 20), to: (23, 59))

        model.add(call)
        await model.waitUntilApplied()

        #expect(center.pending.count == 2)
        #expect(manager.scheduled.isEmpty)
    }

    @Test func aScheduleThatIsOffHoldsNothing() async throws {
        let model = try await launchedModel()
        model.quietHours = try window((0, 0), to: (23, 59), isOn: false)

        model.add(call)
        await model.waitUntilApplied()

        #expect(center.pending.count == 3)
        #expect(manager.scheduled.count == 17)
    }

    /// A schedule on another day than the nudges' holds none of them.
    @Test func aScheduleOnAnotherDayHoldsNothing() async throws {
        let model = try await launchedModel()
        model.quietHours = try window((0, 0), to: (23, 59), days: [.friday])

        model.add(call)
        await model.waitUntilApplied()

        #expect(center.pending.count == 3)
        #expect(manager.scheduled.count == 17)
    }

    @Test func aReceivedReminderIsHeldInAWindowToo() async throws {
        let model = try await launchedModel()
        model.quietHours = try allOfThursday()
        let sent = Reminder(title: "Take the pills", dueTime: NewYork.local(2026, 10, 15, 9), strength: .firm)
        let copy = SentReminder(reminder: sent, revision: 0).copy(through: UUID(), deliveryMode: .startRightAway, alarmSound: .chime)

        try model.keep(copy)
        await model.waitUntilApplied()

        #expect(model.engine.reminders.count == 1)
        #expect(center.pending.isEmpty)
        #expect(manager.scheduleCalls.isEmpty)
    }

    @Test func theTestNudgeIsStillAnOrdinaryNotificationInAWindow() async throws {
        let model = try await launchedModel()
        model.quietHours = try allOfThursday()

        await model.sendTestNudge()

        let request = try #require(center.pending.first)
        #expect(request.identifier == NotificationAdapter.testNudgeIdentifier)
        #expect(request.content.interruptionLevel == .active)
        #expect(request.trigger is UNTimeIntervalNotificationTrigger)
    }

    // MARK: Default install

    /// A model with a schedule that is off schedules exactly what one with none does, alarm IDs
    /// included.
    @Test func noScheduleAndAnOffScheduleMakeTheSamePlanWithTheSameAlarmIDs() async throws {
        let plain = try await launchedModel()
        plain.add(call)
        await plain.waitUntilApplied()
        let pending = Set(center.pending.map(\.identifier))
        let alarms = Set(manager.scheduled.map(\.id))
        #expect(pending.count == 3)
        #expect(alarms.count == 17)

        let off = try window((0, 0), to: (23, 59), isOn: false)
        let other = FakeNotificationCenter()
        let otherManager = FakeAlarmManager()
        let store = try ReminderStore(location: .inMemory)
        let withOffSchedule = AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: other, clock: clock),
            alarms: AlarmAdapter(manager: otherManager, clock: clock),
            settingsRecords: .temporary(quietHours: QuietHoursRecord(defaults: try defaults())),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
        withOffSchedule.quietHours = off
        await withOffSchedule.launch()
        withOffSchedule.add(call)
        await withOffSchedule.waitUntilApplied()

        #expect(Set(other.pending.map(\.identifier)) == pending)
        #expect(Set(otherManager.scheduled.map(\.id)) == alarms)
    }

    /// An update from the previous version has no schedules saved: it plans what is already
    /// pending, and adds and cancels nothing.
    @Test func aLaunchWithNoSchedulesSavedCancelsAndReschedulesNothing() async throws {
        let model = try await launchedModel()
        model.add(call)
        await model.waitUntilApplied()
        let pending = Set(center.pending.map(\.identifier))
        let alarms = Set(manager.scheduled.map(\.id))
        let added = center.added.count
        let scheduled = manager.scheduleCalls.count

        let relaunched = try await launchedModel()
        await relaunched.waitUntilApplied()

        #expect(Set(center.pending.map(\.identifier)) == pending)
        #expect(Set(manager.scheduled.map(\.id)) == alarms)
        #expect(center.added.count == added)
        #expect(manager.scheduleCalls.count == scheduled)
        #expect(manager.cancelledIDs.isEmpty)
    }

    // MARK: Changing a schedule

    @Test func aNewScheduleCancelsWhatItHoldsOnceAndKeepsTheRest() async throws {
        let model = try await launchedModel()
        model.add(call)
        await model.waitUntilApplied()
        let before = Set(manager.scheduled.map(\.id))
        #expect(center.pending.count == 3)
        #expect(before.count == 17)

        model.quietHours = try window((9, 20), to: (23, 59))
        await model.waitUntilApplied()

        #expect(center.pending.count == 2)
        #expect(manager.scheduled.isEmpty)
        #expect(Set(manager.cancelledIDs) == before)
        #expect(manager.cancelledIDs.count == 17)
    }

    @Test func clearingTheScheduleSchedulesWhatItHeldOnceWithTheSameAlarmIDs() async throws {
        let model = try await launchedModel()
        model.quietHours = try window((9, 20), to: (23, 59))
        model.add(call)
        await model.waitUntilApplied()
        #expect(manager.scheduled.isEmpty)
        #expect(center.pending.count == 2)
        let added = center.added.count

        model.quietHours = QuietHours()
        await model.waitUntilApplied()

        #expect(center.pending.count == 3)
        #expect(manager.scheduled.count == 17)
        #expect(manager.scheduleCalls.count == 17)
        #expect(center.added.count == added + 1)
        // The ones the plan had all along were not scheduled again.
        let withNoSchedule = Set(manager.scheduled.map(\.id))
        let plain = try await launchedModelOverFreshFakes()
        #expect(Set(plain.manager.scheduled.map(\.id)) == withNoSchedule)
    }

    /// A model over fakes of its own with the call added and no schedule, for comparing IDs.
    func launchedModelOverFreshFakes() async throws -> (model: AppModel, manager: FakeAlarmManager) {
        let otherManager = FakeAlarmManager()
        let store = try ReminderStore(location: .inMemory)
        let model = AppModel(
            clock: clock,
            openStore: { store },
            notifications: NotificationAdapter(center: FakeNotificationCenter(), clock: clock),
            alarms: AlarmAdapter(manager: otherManager, clock: clock),
            settingsRecords: .temporary(quietHours: QuietHoursRecord(defaults: UserDefaults(suiteName: "\(suiteName).other")!)),
            doneQueue: .temporary,
            timeZone: NewYork.timeZone
        )
        await model.launch()
        model.add(call)
        await model.waitUntilApplied()
        return (model, otherManager)
    }

    /// Ones already sent stay sent: the nudge numbers and what the person has in Notification
    /// Center don't move when a schedule that covers the rest of the day is saved.
    @Test func nudgesAlreadySentStaySentWhenAScheduleIsSaved() async throws {
        let model = try await launchedModel()
        model.add(call)
        clock.now = NewYork.local(2026, 10, 15, 9, 12)
        await model.appOpened()
        await model.waitUntilApplied()
        let state = try #require(model.engine.openOccurrence(for: call.id)?.state)
        #expect(state == .nudging(nudgeNumber: 2))
        let added = center.added.count

        model.quietHours = try window((9, 0), to: (23, 59))
        await model.waitUntilApplied()

        #expect(model.engine.openOccurrence(for: call.id)?.state == state)
        #expect(center.added.count == added)
        #expect(manager.scheduled.isEmpty)
        #expect(center.pending.isEmpty)
    }

    @Test func savingTheSameScheduleAgainChangesNothing() async throws {
        let model = try await launchedModel()
        model.quietHours = try window((9, 20), to: (23, 59))
        model.add(call)
        await model.waitUntilApplied()
        let added = center.added.count
        let scheduled = manager.scheduleCalls.count
        let cancelled = manager.cancelledIDs.count

        model.quietHours = try window((9, 20), to: (23, 59))
        await model.waitUntilApplied()

        #expect(center.added.count == added)
        #expect(manager.scheduleCalls.count == scheduled)
        #expect(manager.cancelledIDs.count == cancelled)
        #expect(model.engine.replacedQuietHours.count == 1)
    }

    // MARK: A ringing alarm

    /// The call's alarm at 9:32:30, ringing at 9:58.
    func modelWithTheCallsFirstAlarmRinging() async throws -> (model: AppModel, ringing: Alarm.ID) {
        let model = try await launchedModel()
        model.add(call)
        await model.waitUntilApplied()
        let ringing = try #require(manager.scheduled.first { $0.fireDate == NewYork.local(2026, 10, 15, 9, 32, 30) }).id
        clock.now = NewYork.local(2026, 10, 15, 9, 58)
        manager.ring(ringing)
        return (model, ringing)
    }

    @Test func aScheduleSavedWhileAnAlarmRingsLeavesItRingingAndHoldsTheRest() async throws {
        let (model, ringing) = try await modelWithTheCallsFirstAlarmRinging()

        model.quietHours = try window((9, 0), to: (23, 59))
        await model.waitUntilApplied()

        #expect(state(of: ringing) == .alerting)
        #expect(!manager.cancelledIDs.contains(ringing))
        // Every alarm still to come is held and cancelled. What is left fired before the change, the
        // ringing one among them, and the plan keeps it as it was.
        #expect(manager.scheduled.contains { $0.id == ringing })
        #expect(manager.scheduled.compactMap(\.fireDate).allSatisfy { $0 <= clock.now })
        let cancelled = manager.scheduleCalls.filter { manager.cancelledIDs.contains($0.id) }
        #expect(!cancelled.isEmpty)
        #expect(cancelled.compactMap(\.fireDate).allSatisfy { $0 > clock.now })
    }

    @Test func aScheduleChangedAgainWhileAnAlarmRingsLeavesItRinging() async throws {
        let (model, ringing) = try await modelWithTheCallsFirstAlarmRinging()
        model.quietHours = try window((9, 0), to: (23, 59))
        await model.waitUntilApplied()

        model.quietHours = try window((22, 0), to: (23, 59))
        await model.waitUntilApplied()
        #expect(state(of: ringing) == .alerting)

        model.quietHours = QuietHours()
        await model.waitUntilApplied()
        #expect(state(of: ringing) == .alerting)
        #expect(!manager.cancelledIDs.contains(ringing))
    }

    /// A window that starts after the alarm fired, while it rings: the next re-plan leaves it.
    @Test func aWindowThatStartsWhileAnAlarmRingsLeavesItRinging() async throws {
        let model = try await launchedModel()
        model.quietHours = try window((9, 40), to: (23, 59))
        model.add(call)
        await model.waitUntilApplied()
        let ringing = try #require(manager.scheduled.first { $0.fireDate == NewYork.local(2026, 10, 15, 9, 32, 30) }).id
        clock.now = NewYork.local(2026, 10, 15, 9, 45)
        manager.ring(ringing)

        await model.appOpened()
        await model.waitUntilApplied()

        #expect(state(of: ringing) == .alerting)
        #expect(!manager.cancelledIDs.contains(ringing))
    }

    // MARK: The alarm limit

    /// Held alarms take no slot: with a limit of exactly the alarms left after the window, every
    /// one of them is scheduled as an alarm, with none falling back to a notification.
    @Test func heldNudgesDontCountAgainstTheAlarmLimit() async throws {
        let fireDates = try await launchedModelOverFreshFakes().manager.scheduled.compactMap(\.fireDate).sorted()
        #expect(fireDates.count == 17)
        // A window to the minute the sixth alarm falls in holds the notifications and the first five.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NewYork.timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: fireDates[5])
        let hour = try #require(parts.hour), minute = try #require(parts.minute)
        #expect(fireDates[4] < NewYork.local(2026, 10, 15, hour, minute))
        let model = try await launchedModel()
        manager.alarmLimit = 12
        model.quietHours = try window((0, 0), to: (hour, minute))

        model.add(call)
        await model.waitUntilApplied()

        #expect(manager.scheduled.count == 12)
        #expect(manager.scheduleCalls.count == 12)
        #expect(center.pending.isEmpty)
    }

    // MARK: Kept on the phone

    /// 8:40 and 9:10 fall inside the window the person later turned off, 9:25 doesn't. A Done at
    /// 9:31 reads the held count under the schedules as they were when each nudge was due, so
    /// quiet hours turned off since still shows two held, also after a relaunch.
    @Test func theReplacedSchedulesAreSavedAndHandedBackAtLaunchSoAHeldCountReadsAsItWas() async throws {
        let model = try await launchedModel()
        model.add(call)
        model.quietHours = try window((8, 0), to: (9, 20))
        clock.now = NewYork.local(2026, 10, 15, 9, 30)
        await model.appOpened()
        model.quietHours = QuietHours()
        await model.waitUntilApplied()

        let relaunched = try await launchedModel()
        await relaunched.waitUntilApplied()
        clock.now = NewYork.local(2026, 10, 15, 9, 31)
        relaunched.markDone(call.id)

        #expect(relaunched.quietHours == QuietHours())
        #expect(relaunched.engine.replacedQuietHours == model.engine.replacedQuietHours)
        let closed = try #require(relaunched.engine.closedOccurrence(of: call.id, dueAt: call.dueTime))
        #expect(closed.nudgesSent == 3)
        #expect(closed.nudgesHeld == 2)
    }

    @Test func aReplacedEntryTheRecordCantReadIsLeftOutAndTheOthersAreKept() async throws {
        let model = try await launchedModel()
        model.quietHours = try window((8, 0), to: (9, 20))
        model.quietHours = try window((10, 0), to: (11, 0))
        model.quietHours = QuietHours()
        let saved = model.engine.replacedQuietHours
        #expect(saved.count == 3)
        var entries = try #require(defaults().array(forKey: QuietHoursRecord.replacedKey))
        entries.insert("not an entry", at: 1)
        try defaults().set(entries, forKey: QuietHoursRecord.replacedKey)

        let relaunched = try await launchedModel()

        #expect(relaunched.engine.replacedQuietHours == saved)
    }

    @Test func deleteAllDataClearsTheReplacedSchedulesToo() async throws {
        let model = try await launchedModel()
        model.quietHours = try window((8, 0), to: (9, 20))
        model.quietHours = QuietHours()
        // Each change keeps the schedules it replaced: none, then the window.
        #expect(model.engine.replacedQuietHours.count == 2)
        #expect(try defaults().object(forKey: QuietHoursRecord.replacedKey) != nil)

        try await model.deleteAllData()

        #expect(model.engine.replacedQuietHours.isEmpty)
        #expect(try defaults().object(forKey: QuietHoursRecord.replacedKey) == nil)
        let relaunched = try await launchedModel()
        #expect(relaunched.engine.replacedQuietHours.isEmpty)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
