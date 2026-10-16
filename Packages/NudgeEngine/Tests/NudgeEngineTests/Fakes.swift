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

/// Records every schedule plan the engine hands to it. With an `alarmLimit` it stands in for a
/// system that holds only that many pending alarms, as a real adapter scheduling soonest first
/// would find.
final class FakeScheduler: SchedulerAdapter {
    private(set) var appliedPlans: [SchedulePlan] = []
    private let alarmLimit: Int?

    init(alarmLimit: Int? = nil) {
        self.alarmLimit = alarmLimit
    }

    var lastPlan: SchedulePlan? { appliedPlans.last }

    /// The last plan's alarms past the limit, soonest first: the ones that would fail with
    /// `maximumLimitReached`. Only nudges not yet fired count, since an adapter skips the rest.
    func alarmsPastLimit(at now: Date) -> [SchedulePlan.Item] {
        guard let alarmLimit, let lastPlan else { return [] }
        let alarms = lastPlan.items
            .filter { $0.deliveryKind == .alarm && $0.fireTime > now }
            .sorted { $0.fireTime < $1.fireTime }
        return Array(alarms.dropFirst(alarmLimit))
    }

    func apply(_ plan: SchedulePlan) {
        appliedPlans.append(plan)
    }
}
