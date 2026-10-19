import AlarmKit
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// Ticket 19's device checks: the adapter through the real `AlarmManager`. They act only on the
/// alarms they schedule, under reminder IDs made for the run, and cancel them even when they fail
/// (AGENTS.md: tests on the iPhone leave it as they found it). An apply cancels every alarm of the
/// app's that isn't in the plan, so each check first requires the app to hold no alarms.
///
/// The checks need alarms allowed. They show the AlarmKit prompt only when the run says the app
/// wasn't installed before it (`TEST_RUNNER_NUDGE_FRESH_INSTALL=1`), since uninstalling afterwards
/// is what resets the permission. Otherwise they leave the permission alone and fail if it isn't
/// already allowed.
@MainActor
class AlarmDeviceCheckSuite {
    let reminderID = UUID()
    let clock = SystemClock()
    private(set) var scheduledIDs: [Alarm.ID] = []

    deinit {
        for id in scheduledIDs {
            // Stop first in case it is ringing; cancel deletes one that hasn't rung yet.
            try? AlarmManager.shared.stop(id: id)
            try? AlarmManager.shared.cancel(id: id)
        }
    }

    /// An adapter over the real manager, with alarms allowed and none of the app's scheduled.
    func adapter() async throws -> AlarmAdapter {
        let manager = SystemAlarmManager()
        let adapter = AlarmAdapter(manager: manager, clock: clock)
        // Through the adapter, which reads AlarmKit's state once, off the main thread, and then
        // takes the prompt's answer: reading it straight after the prompt froze the iPhone.
        if await adapter.permissions(updating: PermissionStates()).alarms == .notDetermined,
           ProcessInfo.processInfo.environment["NUDGE_FRESH_INSTALL"] == "1" {
            _ = try await adapter.requestAuthorization()
        }
        try #require(await adapter.permissions(updating: PermissionStates()).alarms == .allowed, "Allow alarms for Nudge-inator, or set TEST_RUNNER_NUDGE_FRESH_INSTALL=1 on a fresh install")
        try #require(try manager.alarms().isEmpty, "Nudge-inator already holds alarms; the check would cancel them")
        return adapter
    }

    func nudge(_ nudgeNumber: Int, at fireTime: Date, title: String) -> SchedulePlan.Item {
        let item = SchedulePlan.Item(
            reminderID: reminderID,
            dueTime: fireTime,
            nudgeNumber: nudgeNumber,
            // Every shipped ladder sends 20 before it gives up.
            nudgesInAll: 20,
            fireTime: fireTime,
            urgency: .urgent,
            title: title,
            deliveryKind: .alarm
        )
        scheduledIDs.append(AlarmAdapter.alarmID(for: item))
        return item
    }

    func states(of ids: [Alarm.ID]) throws -> [Alarm.State?] {
        let alarms = try AlarmManager.shared.alarms
        return ids.map { id in alarms.first { $0.id == id }?.state }
    }
}

@MainActor
@Suite(.enabled(if: DeviceCheck.isPhysicalDevice, "Needs the real AlarmManager on an iPhone"))
final class AlarmDeviceCheck: AlarmDeviceCheckSuite {
    /// The System wrapper's `.alarm(...)` configuration is the one line no fake covers.
    @Test func aPlansAlarmsAreScheduledAndAnEmptyPlanCancelsThem() async throws {
        let adapter = try await adapter()
        // A day out, so neither rings during the check.
        let items = [
            nudge(4, at: .now + 86_400, title: "Nudge-inator device check"),
            nudge(5, at: .now + 86_460, title: "Nudge-inator device check"),
        ]

        adapter.apply(SchedulePlan(items: items))
        await adapter.waitUntilApplied()
        #expect(try states(of: scheduledIDs) == [.scheduled, .scheduled])

        adapter.apply(SchedulePlan(items: []))
        await adapter.waitUntilApplied()
        #expect(try states(of: scheduledIDs) == [nil, nil])
    }
}

/// The acceptance criterion that needs a person: run it with silent mode and a Focus on, and the
/// phone locked. Opt-in, since it rings twice and waits for you:
/// `TEST_RUNNER_NUDGE_RING_CHECK=1 xcodebuild test ... -only-testing:NudgeInatorTests/AlarmRingDeviceCheck`
/// When the first alarm rings, check it shows the title only, then Stop it. The second must still
/// ring a minute later; Stop it too. The check records when each one rang.
@MainActor
@Suite(.enabled(
    if: DeviceCheck.isPhysicalDevice && ProcessInfo.processInfo.environment["NUDGE_RING_CHECK"] == "1",
    "Rings the phone and needs a person: set TEST_RUNNER_NUDGE_RING_CHECK=1"
))
final class AlarmRingDeviceCheck: AlarmDeviceCheckSuite {
    @Test(.timeLimit(.minutes(5)))
    func stoppingOneAlarmLeavesTheNextToRingOnTime() async throws {
        let adapter = try await adapter()
        let first = nudge(4, at: .now + 60, title: "Nudge-inator ring check")
        let second = nudge(5, at: first.fireTime + 60, title: "Nudge-inator ring check")
        adapter.apply(SchedulePlan(items: [first, second]))
        await adapter.waitUntilApplied()
        let ids = scheduledIDs

        var rangAt: [Alarm.ID: Date] = [:]
        var stoppedFirstBeforeSecondRang = false
        // Until both have rung and been stopped, or the second's time is well past.
        while Date.now < second.fireTime + 120 {
            let states = try states(of: ids)
            for (id, state) in zip(ids, states) where state == .alerting && rangAt[id] == nil {
                rangAt[id] = .now
            }
            if states[0] == nil, states[1] == .scheduled {
                stoppedFirstBeforeSecondRang = true
            }
            if states == [nil, nil], rangAt.count == 2 { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        print("Ring check: first rang \(rangAt[ids[0]].map { $0.timeIntervalSince(first.fireTime) } ?? .nan) s after its time, second \(rangAt[ids[1]].map { $0.timeIntervalSince(second.fireTime) } ?? .nan) s")

        let firstRang = try #require(rangAt[ids[0]], "The first alarm never rang")
        let secondRang = try #require(rangAt[ids[1]], "The second alarm never rang")
        #expect(stoppedFirstBeforeSecondRang, "Stop the first alarm before the second rings")
        #expect(abs(firstRang.timeIntervalSince(first.fireTime)) < 5)
        #expect(abs(secondRang.timeIntervalSince(second.fireTime)) < 5)
        #expect(try states(of: ids) == [nil, nil])
    }
}
