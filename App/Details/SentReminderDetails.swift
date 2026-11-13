import Foundation
import NudgeEngine

/// What a sent reminder's details show (ticket 201, the mockup's `viewSent`), read from the sharing
/// store and the engine's calendar at one moment: the reminder as the sender keeps it, each
/// recipient with whether their copy has arrived, and the Schedule. The sender doesn't hold it among
/// their own reminders, so nothing here is planned or locked. A value, so the tests and previews
/// read it with no view.
struct SentReminderDetails {
    var reminder: Reminder
    /// Sent To: each person it went to that is still connected, in the Sent view's order.
    var recipients: [Recipient]
    /// The Schedule's Repeats row: the engine's summary.
    var repeats: String
    /// The Schedule's Next row.
    var next: ReminderDetails.Next

    var title: String { reminder.title }
    var notes: String { reminder.notes }
    var strength: Strength { reminder.strength }
    var pace: Pace { reminder.pace }
    /// On for Relentless, which always breaks through Focus (ADR 0004).
    var breaksThroughFocus: Bool { reminder.breaksThroughFocus }

    struct Recipient: Identifiable, Equatable {
        var connectionID: UUID
        var name: String
        /// How their copy is going, as the sender may read it.
        var state: SentCopyState
        /// Their last 7 days of a repeating reminder, as their Sent row has it, or `nil` where the row
        /// has none.
        var history: SentHistory?

        var id: UUID { connectionID }

        /// The header over their history: "Riley, Last 7 Days", with the person's short name.
        var historyHeader: LocalizedStringResource {
            let name = (try? PersonNameComponents(name))?.formatted(.name(style: .short)) ?? name
            return LocalizedStringResource("\(name), Last 7 Days", comment: "A sent reminder's details: section header over one person's last 7 days of the reminder. The placeholder is the person's short name, such as \"Riley\".")
        }
        var isDelivered: Bool { state.isDelivered }
        var trailing: SentReadOut.Trailing { state.trailing }
        var detailLine: LocalizedStringResource? { state.detailLine }
    }

    /// `nil` when the sharing store doesn't keep a sent reminder with this ID: one of the person's
    /// own, or one deleted while its details were open, so the screen says it wasn't found.
    init?(engine: Engine, sharing: SharingData, id: Reminder.ID) {
        guard let sent = sharing.sentReminders.first(where: { $0.reminder.id == id }) else { return nil }
        reminder = sent.reminder
        recipients = SentScreen(engine: engine, sharing: sharing).recipients(of: id).map {
            Recipient(connectionID: $0.person.connectionID, name: $0.person.name, state: $0.row.state, history: $0.row.history)
        }
        repeats = engine.repeatSummary(of: sent.reminder)
        next = engine.upcomingDueTimes(of: sent.reminder, count: 1).first
            .map { .at(day: engine.dayLabel(of: $0), time: engine.timeOfDay(of: $0)) } ?? .none
    }
}
