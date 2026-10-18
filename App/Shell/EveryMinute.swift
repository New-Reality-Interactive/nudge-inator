import Foundation

/// Time-driven read-outs (a badge, a lock) change as the clock passes a due time with no change
/// the views can see, so they are read again at the start of every minute, as `TimelineView`'s
/// `.everyMinute` does for a list.
enum EveryMinute {
    /// Waits until a moment after the start of the next minute, so the clock has certainly passed
    /// a due time that is on it. Throws if the task is cancelled.
    static func sleepUntilNext() async throws {
        // A calendar that can't find the next minute still waits one, so callers that loop never spin.
        let next = Calendar.current.nextDate(after: .now, matching: DateComponents(second: 0), matchingPolicy: .nextTime)
        try await Task.sleep(for: .seconds((next?.timeIntervalSinceNow ?? 60) + 0.5))
    }
}
