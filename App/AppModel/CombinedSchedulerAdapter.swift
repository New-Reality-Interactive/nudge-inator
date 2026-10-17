import NudgeEngine

/// Hands each plan to every adapter: the engine holds one `SchedulerAdapter`, and the plan's
/// notifications and alarms go through two (tickets 18, 19). `@MainActor`, like both of them.
@MainActor
struct CombinedSchedulerAdapter: @MainActor SchedulerAdapter {
    let adapters: [any SchedulerAdapter]

    func apply(_ plan: SchedulePlan) {
        for adapter in adapters {
            adapter.apply(plan)
        }
    }
}
