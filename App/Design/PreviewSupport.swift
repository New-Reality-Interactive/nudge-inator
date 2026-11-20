import Foundation
import NudgeEngine

/// A `SchedulerAdapter` whose `apply(_:)` does nothing, for an engine that has no app model to
/// schedule for. Not behind `#if DEBUG`: shipping code builds such an engine (Settings' How It
/// Nudges sheet when it has no model), so the Release build needs it.
struct NoOpScheduler: SchedulerAdapter {
    func apply(_ plan: SchedulePlan) {}
}

extension Engine {
    /// An engine with no app model, scheduling nothing, for previews and a screen with no model.
    static func unscheduled(permissions: PermissionStates = PermissionStates(alarms: .allowed)) -> Engine {
        Engine(clock: SystemClock(), scheduler: NoOpScheduler(), permissions: permissions)
    }
}

#if DEBUG
/// A clock the preview moves by hand, so its Done and pause can happen in the past. It starts
/// at the current time.
final class PreviewClock: EngineClock {
    var now: Date

    init(now: Date = .now) {
        self.now = now
    }
}
#endif
