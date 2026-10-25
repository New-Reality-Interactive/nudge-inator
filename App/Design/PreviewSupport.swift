import Foundation
import NudgeEngine

/// An adapter that drops every plan, for previews' engines, which need no app model. Not behind
/// `#if DEBUG`: the How It Nudges page builds such an engine when it has no model.
struct PreviewScheduler: SchedulerAdapter {
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
