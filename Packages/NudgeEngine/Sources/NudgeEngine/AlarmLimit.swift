import Foundation

/// How many alarms yet to ring the engine plans at once. Apple documents only the
/// `maximumLimitReached` error, not a number, so this is what ticket 02 measured on a device: no
/// limit up to 4,000 pending alarms in one app. It is a floor, not the system's limit, which the
/// scheduler adapter's report covers. A Relentless ladder rings 20 times, and a repeat plans two
/// ladders, so it takes 100 repeating Relentless reminders nudging at once to reach it.
/// Ticket 02 also saw the first ring after bulk-scheduling 4,000 ignore touches once, so the
/// adapter (ticket 19) should schedule only what changed, not the whole plan each time. Fixed;
/// only tests use another.
struct AlarmLimit: Equatable, Sendable {
    var pendingAlarms: Int

    static let shipped = AlarmLimit(pendingAlarms: 4_000)
}
