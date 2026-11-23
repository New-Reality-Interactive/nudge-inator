#if DEBUG
import Foundation
import NudgeEngine

/// #379's device checks of what quiet hours do to real nudges. Each set loads one Firm reminder
/// with Break Through Focus on, so its Urgent nudges are real alarms and its Normal and High ones
/// notifications, due a few minutes before the load and nudging on a Consistent pace short enough
/// to watch. Firm's nudge 3 is High (a Time Sensitive notification) and nudge 4 on is Urgent (an
/// alarm).
///
/// Every time below is counted from `m`, the whole minute the load falls in: a due time is rounded
/// down to the minute, so nudges land on whole minutes after `m` whichever second the load is
/// at, and a test checks that for several seconds. These are the only sets that ring, by the
/// developer's go of 2026-11-22 (`DeviceSeedTests.setsThatRing`); `clean` deletes the reminder,
/// which cancels its alarms and notifications, and puts back the person's schedules.
extension SeedSet {
    /// A window holds an alarm and a notification. The reminder was due at `m` − 2 min, nudging
    /// every 2 min: nudge 3 (a notification) is at `m` + 2, nudge 4 (an alarm) at `m` + 4. The window
    /// is on from `m` to `m` + 5, so it holds both, and nudge 5, an alarm at `m` + 6, is the next
    /// nudge after it.
    static let quietHoursWindow = SeedSet(
        name: "quiet-hours-window",
        quietWindow: SeedQuietWindow(startIn: 0, length: 5 * minute),
        reminders: [
            SeedReminder(
                id: SeedReminder.fixedID(69), title: "Pay the water bill", dueIn: -2 * minute,
                strength: .firm, pace: .consistent(wait: 2 * minute), breakThroughFocus: true
            ),
        ]
    )

    /// An alarm already ringing when a window starts keeps ringing. Nudge 4, an alarm, rings at
    /// `m` + 2 (due at `m` − 4 min, every 2 min), and the window starts at `m` + 3, so the ring is
    /// a minute old when it does. The window ends at `m` + 9, holding nudges 5 to 7; nudge 8, an
    /// alarm at `m` + 10, is the next.
    static let quietHoursRinging = SeedSet(
        name: "quiet-hours-ringing",
        quietWindow: SeedQuietWindow(startIn: 3 * minute, length: 6 * minute),
        reminders: [
            SeedReminder(
                id: SeedReminder.fixedID(70), title: "Take the bins out", dueIn: -4 * minute,
                strength: .firm, pace: .consistent(wait: 2 * minute), breakThroughFocus: true
            ),
        ]
    )

    /// Editing a schedule while a reminder is Nudging. The reminder was due at `m` − 5 min, nudging
    /// every 5 min: nudge 3 (a notification) at `m` + 5, nudge 4 (an alarm) at `m` + 10, nudge 5 (an
    /// alarm) at `m` + 15. The schedule is on from `m` − 1 min to `m` + 3 min and holds none of
    /// them; the check moves its end to `m` + 13, which holds nudges 3 and 4 and leaves 5.
    static let quietHoursEdit = SeedSet(
        name: "quiet-hours-edit",
        quietWindow: SeedQuietWindow(startIn: -minute, length: 4 * minute),
        reminders: [
            SeedReminder(
                id: SeedReminder.fixedID(71), title: "Renew the passport", dueIn: -5 * minute,
                strength: .firm, pace: .consistent(wait: 5 * minute), breakThroughFocus: true
            ),
        ]
    )

    /// Quiet Now holds a real alarm and a notification. The same reminder and times as
    /// `quiet-hours-edit`, with no schedule: Quiet Now turned on before `m` + 5 holds nudges 3 and
    /// 4, and turned off between `m` + 10 and `m` + 15 it makes none up; nudge 5 rings at `m` + 15.
    static let quietHoursQuietNow = SeedSet(
        name: "quiet-hours-quiet-now",
        settings: [.quietHours: ""],
        reminders: [
            SeedReminder(
                id: SeedReminder.fixedID(72), title: "Water the ferns", dueIn: -5 * minute,
                strength: .firm, pace: .consistent(wait: 5 * minute), breakThroughFocus: true
            ),
        ]
    )
}

private let minute: TimeInterval = 60
#endif
