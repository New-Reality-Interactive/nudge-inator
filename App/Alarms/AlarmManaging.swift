import AlarmKit
import AppIntents
import NudgeShared

/// The parts of an `Alarm` the adapter reads, in any state. Tests can't make an `Alarm`: it has no
/// public init.
struct AlarmSnapshot: Equatable, Sendable {
    var id: Alarm.ID
    var state: Alarm.State
}

/// The calls the alarm adapter makes on `AlarmManager`, so tests can swap in a fake. It takes the
/// schedule and attributes rather than an `AlarmConfiguration`, which has no readable properties,
/// so tests can read back what each alarm shows. `@MainActor` because the adapter and the app
/// model that owns it are.
@MainActor
protocol AlarmManaging: AnyObject {
    func schedule(
        id: Alarm.ID,
        schedule: Alarm.Schedule,
        attributes: AlarmAttributes<NudgeAlarmMetadata>,
        secondaryIntent: (any LiveActivityIntent)?
    ) async throws
    func cancel(id: Alarm.ID) throws
    func alarms() throws -> [AlarmSnapshot]
    var authorizationState: AlarmManager.AuthorizationState { get }
    func requestAuthorization() async throws -> AlarmManager.AuthorizationState
    func authorizationUpdates() -> AsyncStream<AlarmManager.AuthorizationState>
}

/// The real manager. It calls `AlarmManager.shared` each time rather than keeping it:
/// `AlarmManager` isn't `Sendable`, so a stored one can't be sent into its own async methods.
@MainActor
final class SystemAlarmManager: AlarmManaging {
    func schedule(
        id: Alarm.ID,
        schedule: Alarm.Schedule,
        attributes: AlarmAttributes<NudgeAlarmMetadata>,
        secondaryIntent: (any LiveActivityIntent)?
    ) async throws {
        // `.alarm` "behaves like a traditional alarm", unlike the countdown-style init. No stop
        // intent: Stop needs no app code (ADR 0001).
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: schedule,
            attributes: attributes,
            secondaryIntent: secondaryIntent
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }

    func cancel(id: Alarm.ID) throws {
        try AlarmManager.shared.cancel(id: id)
    }

    func alarms() throws -> [AlarmSnapshot] {
        try AlarmManager.shared.alarms.map { AlarmSnapshot(id: $0.id, state: $0.state) }
    }

    var authorizationState: AlarmManager.AuthorizationState {
        AlarmManager.shared.authorizationState
    }

    func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        try await AlarmManager.shared.requestAuthorization()
    }

    func authorizationUpdates() -> AsyncStream<AlarmManager.AuthorizationState> {
        let updates = AlarmManager.shared.authorizationUpdates
        return AsyncStream { continuation in
            let task = Task {
                for await state in updates {
                    continuation.yield(state)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
