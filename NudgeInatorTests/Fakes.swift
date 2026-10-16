import Foundation
import NudgeEngine

/// A clock the test sets by hand, so no test depends on real time.
final class FakeClock: EngineClock {
    var now: Date

    init(now: Date) {
        self.now = now
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

/// Test dates as local wall-clock times in New York, so no test depends on the simulator's time
/// zone.
enum NewYork {
    static let timeZone = TimeZone(identifier: "America/New_York")!

    static func local(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }
}
