#if DEBUG
import Foundation
import NudgeEngine

/// An adapter that drops every plan, for previews' engines, which need no app model.
struct PreviewScheduler: SchedulerAdapter {
    func apply(_ plan: SchedulePlan) {}
}

/// A clock the preview moves by hand, so its Done and pause can happen in the past. It starts
/// at the current time.
final class PreviewClock: EngineClock {
    var now: Date

    init(now: Date = .now) {
        self.now = now
    }
}
#endif
