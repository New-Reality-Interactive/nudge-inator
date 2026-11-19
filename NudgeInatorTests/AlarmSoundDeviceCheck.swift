import ActivityKit
import AlarmKit
import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// #227's device checks: a tone through the real `AlarmManager`. Each rings the phone about a
/// minute after it starts and waits for a person to listen and tap Stop, so it is opt-in, and each
/// is run alone:
/// `TEST_RUNNER_NUDGE_SOUND_CHECK=1 xcodebuild test ... -only-testing:NudgeInatorTests/AlarmSoundDeviceCheck/<test>()`
/// The person reports what they heard; the check records when each alarm rang and was stopped, and
/// cancels every alarm it scheduled, even when it fails (`AlarmDeviceCheckSuite`).
@MainActor
@Suite(.enabled(
    if: DeviceCheck.isPhysicalDevice && ProcessInfo.processInfo.environment["NUDGE_SOUND_CHECK"] == "1",
    "Rings the phone and needs a person: set TEST_RUNNER_NUDGE_SOUND_CHECK=1"
))
final class AlarmSoundDeviceCheck: AlarmDeviceCheckSuite {
    /// When the alarm rings, it should be Chime, not the standard alarm sound: hearing Chime is what
    /// shows AlarmKit took the 25 second file, since it falls back to the standard sound for a file
    /// it won't use. Let it ring for at least 40 seconds, past the file's end, and report whether
    /// the sound kept going or went silent after one play; then Stop. The check sees only how long
    /// the alarm stayed ringing, not whether it made a sound.
    @Test(.timeLimit(.minutes(5)))
    func aToneScheduledWithItsExtensionRingsUntilStop() async throws {
        let adapter = try await adapter()
        let item = nudge(4, at: .now + 60, title: "Nudge-inator sound check: Chime", alarmSound: .chime)

        adapter.apply(SchedulePlan(items: [item]))
        await adapter.waitUntilApplied()
        let id = AlarmAdapter.alarmID(for: item)
        #expect(try states(of: [id]) == [.scheduled])

        let ring = try await ringAndStop(of: id, dueAt: item.fireTime)
        #expect(ring.lasted > 35, "Let it ring at least 40 seconds before Stop")
    }

    /// The same tone named without `.caf`, past the adapter. Developers report AlarmKit plays the
    /// standard alarm sound then (spec #129, research). Report which you hear, then Stop.
    @Test(.timeLimit(.minutes(5)))
    func aToneScheduledWithoutItsExtensionRingsUntilStop() async throws {
        _ = try await adapter()
        let item = nudge(4, at: .now + 60, title: "Nudge-inator sound check: no extension", alarmSound: .chime)
        let id = AlarmAdapter.alarmID(for: item)

        try await SystemAlarmManager().schedule(
            id: id,
            schedule: .fixed(item.fireTime),
            attributes: AlarmAdapter.attributes(for: item, hasOpenButton: false),
            stopIntent: nil,
            secondaryIntent: nil,
            sound: .named("chime")
        )
        #expect(try states(of: [id]) == [.scheduled])

        _ = try await ringAndStop(of: id, dueAt: item.fireTime)
    }

    /// An Edit of the sound before the alarm rings: the Chime alarm is cancelled and a Siren one
    /// scheduled for the same time. When it rings, it should be Siren (it grows more insistent after
    /// each break). Report what you hear, then Stop.
    @Test(.timeLimit(.minutes(5)))
    func editingTheSoundReplacesTheAlarmAndTheNewToneRings() async throws {
        let adapter = try await adapter()
        let fireTime = Date.now + 60
        let chime = nudge(4, at: fireTime, title: "Nudge-inator sound check: Siren", alarmSound: .chime)
        let siren = nudge(4, at: fireTime, title: "Nudge-inator sound check: Siren", alarmSound: .siren)
        let ids = [chime, siren].map(AlarmAdapter.alarmID(for:))
        adapter.apply(SchedulePlan(items: [chime]))
        await adapter.waitUntilApplied()
        #expect(try states(of: ids) == [.scheduled, nil])

        adapter.apply(SchedulePlan(items: [siren]))
        await adapter.waitUntilApplied()
        #expect(try states(of: ids) == [nil, .scheduled])

        _ = try await ringAndStop(of: ids[1], dueAt: fireTime)
    }

    /// Waits for the alarm to ring and then to be stopped, up to 3 minutes past its time, and
    /// prints when each happened.
    private func ringAndStop(of id: Alarm.ID, dueAt fireTime: Date) async throws -> (rang: Date, lasted: TimeInterval) {
        var rangAt: Date?
        var stoppedAt: Date?
        while Date.now < fireTime + 180, stoppedAt == nil {
            let state = try states(of: [id])[0]
            if state == .alerting, rangAt == nil { rangAt = .now }
            if state == nil, rangAt != nil { stoppedAt = .now }
            try await Task.sleep(for: .milliseconds(250))
        }
        let rang = try #require(rangAt, "The alarm never rang")
        let stopped = try #require(stoppedAt, "The alarm wasn't stopped within 3 minutes of its time")
        let lasted = stopped.timeIntervalSince(rang)
        print("Sound check: rang \(rang.timeIntervalSince(fireTime)) s after its time, stopped after \(lasted) s")
        #expect(abs(rang.timeIntervalSince(fireTime)) < 5)
        return (rang, lasted)
    }
}
