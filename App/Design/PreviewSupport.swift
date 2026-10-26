import Foundation
import NudgeEngine

/// A `SchedulerAdapter` whose `apply(_:)` does nothing, for an engine that has no app model to
/// schedule for. Not behind `#if DEBUG`: shipping code builds such an engine (the How It Nudges
/// page when it has no model, and the strength sections' preview helper), so the Release build
/// needs it.
struct NoOpScheduler: SchedulerAdapter {
    func apply(_ plan: SchedulePlan) {}
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
