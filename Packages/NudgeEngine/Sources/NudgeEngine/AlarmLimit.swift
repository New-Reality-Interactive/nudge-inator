import Foundation

/// How many pending alarms the engine plans at once. Apple documents only the
/// `maximumLimitReached` error, not a number, so this is what ticket 02 measured on a device:
/// no limit up to 4,000 pending alarms in one app. It is a floor, not the system's limit, which
/// the scheduler adapter's report covers. A ladder rings at most 17 times, so only some 118
/// Relentless reminders open at once would reach it. Fixed; only tests use another.
struct AlarmLimit: Equatable, Sendable {
    var pendingAlarms: Int

    static let shipped = AlarmLimit(pendingAlarms: 4_000)
}
