import Foundation
import NudgeEngine

/// A clock the test sets by hand, so no test depends on real time.
final class FakeClock: EngineClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }

    func advance(by interval: TimeInterval) {
        now += interval
    }
}

/// Records every schedule plan the engine hands to it.
final class FakeScheduler: SchedulerAdapter {
    private(set) var appliedPlans: [SchedulePlan] = []

    var lastPlan: SchedulePlan? { appliedPlans.last }

    func apply(_ plan: SchedulePlan) {
        appliedPlans.append(plan)
    }
}
