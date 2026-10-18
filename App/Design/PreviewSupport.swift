#if DEBUG
import NudgeEngine

/// An adapter that drops every plan, for previews' engines, which need no app model.
struct PreviewScheduler: SchedulerAdapter {
    func apply(_ plan: SchedulePlan) {}
}
#endif
