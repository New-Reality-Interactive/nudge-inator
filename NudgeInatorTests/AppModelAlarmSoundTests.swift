import ActivityKit
import AlarmKit
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// A reminder's alarm sound through the app model (spec #129, seam 1, #227): what the fake alarm
/// manager is asked to ring with, and what the notification nudges keep.
extension AppModelTests {
    /// Each tone rings with its bundled file, named with the extension: on iOS 26.5 `.named` played
    /// the default sound without it (spec #129, research), a device check.
    @Test(arguments: [
        (AlarmSound.chime, "chime.caf"),
        (.bell, "bell.caf"),
        (.pulse, "pulse.caf"),
        (.beacon, "beacon.caf"),
        (.rise, "rise.caf"),
        (.siren, "siren.caf"),
    ])
    func aRemindersToneReachesEveryAlarmAsItsFile(sound: AlarmSound, fileName: String) async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        var chosen = call
        chosen.alarmSound = sound

        model.add(chosen)
        await model.waitUntilApplied()

        #expect(manager.scheduled.count == 17)
        #expect(manager.scheduled.allSatisfy { $0.sound == .named(fileName) })
    }

    /// Default rings exactly as before 1.5.0: with AlarmKit's own default sound.
    @Test func aDefaultReminderRingsWithAlarmKitsDefaultSound() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        #expect(call.alarmSound == .default)

        model.add(call)
        await model.waitUntilApplied()

        #expect(manager.scheduled.count == 17)
        #expect(manager.scheduled.allSatisfy { $0.sound == .default })
    }

    /// The bank call at 9:40, Nudging, its first alarm due at 9:32:30, and the ID of that alarm,
    /// still ringing when `ringing` is set.
    private func nudgingCall(ringing: Bool = false) async throws -> (model: AppModel, firstAlarm: Alarm.ID) {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        model.add(call)
        await model.waitUntilApplied()
        let firstAlarm = try #require(manager.scheduled.first { $0.fireDate == NewYork.local(2026, 10, 15, 9, 32, 30) }).id
        clock.now = NewYork.local(2026, 10, 15, 9, 40)
        if ringing { manager.ring(firstAlarm) }
        await model.appOpened()
        await model.waitUntilApplied()
        let state = try #require(model.engine.openOccurrence(for: call.id)?.state)
        if case .nudging = state {} else { Issue.record("The bank call isn't Nudging at 9:40: \(state)") }
        return (model, firstAlarm)
    }

    /// AlarmKit can't say what an alarm rings with, so the alarms yet to ring are replaced, as a
    /// title edit does.
    @Test func aSoundChangeOnANudgingReminderReplacesItsAlarmsYetToRing() async throws {
        let model = try await nudgingCall().model
        let pending = manager.scheduled.filter { $0.fireDate.map { $0 > clock.now } ?? false }
        #expect(!pending.isEmpty)
        var edited = call
        edited.alarmSound = .chime

        try model.edit(edited)
        await model.waitUntilApplied()

        #expect(Set(manager.cancelledIDs).isSuperset(of: pending.map(\.id)))
        #expect(manager.scheduled.map(\.fireDate) == pending.map(\.fireDate))
        #expect(manager.scheduled.allSatisfy { $0.sound == .named("chime.caf") })
    }

    /// The edit gives the ringing nudge a new ID too, yet a re-plan never cancels a ring: the person
    /// would be left with no Stop button.
    @Test func aSoundChangeLeavesTheRemindersRingingAlarmRinging() async throws {
        let (model, ringing) = try await nudgingCall(ringing: true)
        var edited = call
        edited.alarmSound = .siren

        try model.edit(edited)
        await model.waitUntilApplied()

        #expect(state(of: ringing) == .alerting)
        #expect(!manager.cancelledIDs.contains(ringing))
        #expect(manager.stoppedIDs.isEmpty)
    }

    /// A tone is for alarms only. Nudges that fall back to a notification keep the standard sound:
    /// the app sets none on them, as on every notification nudge.
    @Test func withAlarmsDeniedATonesNudgesComeAsNotificationsWithTheStandardSound() async throws {
        manager.authorizationState = .denied
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))

        model.add(Reminder(title: "Pay rent", dueTime: NewYork.local(2026, 10, 15, 9), strength: .relentless, alarmSound: .siren))
        await model.waitUntilApplied()

        #expect(manager.scheduleCalls.isEmpty)
        #expect(center.pending.count == 20)
        #expect(center.pending.allSatisfy { $0.content.sound == nil })
    }

    @Test func pastTheAlarmLimitATonesNudgesComeAsNotificationsWithTheStandardSound() async throws {
        manager.alarmLimit = 2
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        var chosen = call
        chosen.alarmSound = .bell

        model.add(chosen)
        await model.waitUntilApplied()

        #expect(manager.scheduled.map(\.sound) == [.named("bell.caf"), .named("bell.caf")])
        #expect(center.pending.count == 18)
        #expect(center.pending.allSatisfy { $0.content.sound == nil })
    }

    /// Send a Test Nudge shows how a notification nudge looks, whatever sound a reminder has.
    @Test func aTestNudgeIsOneOrdinaryNotificationBesideAReminderWithATone() async throws {
        let model = await launchedModel(store: try ReminderStore(location: .inMemory))
        var chosen = call
        chosen.alarmSound = .rise
        model.add(chosen)
        await model.waitUntilApplied()

        await model.sendTestNudge()

        let testNudges = center.pending.filter { $0.identifier == NotificationAdapter.testNudgeIdentifier }
        let testNudge = try #require(testNudges.only)
        #expect(testNudge.content.sound == nil)
        #expect(testNudge.content.interruptionLevel == .active)
    }
}
