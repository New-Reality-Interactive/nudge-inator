#if DEBUG
import Foundation
import NudgeEngine

extension SeedSet {
    /// The nudge card's urgency label check (#442): one Nudging reminder for every strength and
    /// urgency a card can show. Gentle never reaches Urgent, Firm reaches all three, and Relentless
    /// is Urgent from its first nudge, so Relentless at Normal or High can't exist. Each is due
    /// partway between two nudges of the Escalating ladders (`Waits`), so its card keeps its nudge
    /// number during the check. Relentless breaks through Focus; a seed schedules no alarm.
    static let urgencyCards = SeedSet(
        name: "urgency-cards",
        reminders: [
            card(31, "Gentle · Normal", .gentle, nudgeAt: 3_600),
            card(32, "Gentle · High", .gentle, nudgeAt: 9_844),
            card(33, "Firm · Normal", .firm, nudgeAt: 1_800),
            card(34, "Firm · High", .firm, nudgeAt: 2_700),
            card(35, "Firm · Urgent", .firm, nudgeAt: 3_150),
            card(36, "Relentless · Urgent", .relentless, nudgeAt: 0),
        ]
    )

    /// A reminder 30 s past the nudge that fires `nudgeAt` seconds after its due time. The load
    /// rounds the due time down to the minute, so the margin stays under the next wait (150 s at
    /// the shortest).
    private static func card(_ number: UInt8, _ title: String, _ strength: Strength, nudgeAt: TimeInterval) -> SeedReminder {
        SeedReminder(
            id: SeedReminder.fixedID(number),
            title: title,
            dueIn: -(nudgeAt + 30),
            createdAgo: nudgeAt + 60,
            strength: strength
        )
    }
}
#endif
