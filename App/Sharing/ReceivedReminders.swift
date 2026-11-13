import Foundation
import NudgeEngine

/// Where the person's received reminders (GLOSSARY.md, Received reminder) are kept: among their
/// own reminders, in the app model (ticket 198).
@MainActor
protocol ReceivedReminders: AnyObject {
    /// The copy held of the sender's reminder with `sendersReminderID`, received through the
    /// connection with `connectionID`, or `nil` when none is. Throws if the reminders haven't been
    /// read, so it can't say.
    func copy(of sendersReminderID: Reminder.ID, through connectionID: UUID) throws -> Reminder?
    /// Keeps `copy` among the person's reminders and plans it as their own. Throws, keeping
    /// nothing, if the reminders haven't been read or the store won't keep it.
    func keep(_ copy: Reminder) throws
    /// Applies the sender's revision to the copy held (ticket 204), as the engine's
    /// `applySendersRevision(_:)` does, and returns what changed. Throws if the reminders haven't
    /// been read.
    func applySendersRevision(_ revised: Reminder) throws -> [ReceivedChange]
    /// Cancels the copy with `copyID` (ticket 205), as the engine's `cancel(_:)` does: it nudges no
    /// more and stays until the person removes it. Throws if the reminders haven't been read.
    func cancel(_ copyID: Reminder.ID) throws
    /// Every received reminder the person holds (ticket 212). Throws if the reminders haven't been
    /// read, so it can't say.
    func everyReceived() throws -> [Reminder]
    /// Removes every received reminder, with its nudges and alarms, as Disconnect's Remove does
    /// (ticket 212: a different Apple Account signed in). Personal reminders stay as they are.
    func removeEveryReceived()

    /// The status report of every copy the person holds that the sender may be told about (ticket
    /// 206), as the engine reads them now: every received reminder but a Canceled one, whose sender
    /// deleted it and so reads nothing.
    func statusReports() -> [(copy: Reminder, report: StatusReport)]
}

extension SentReminder {
    /// The recipient's copy of it, received through the connection with `connectionID`: an ID of its
    /// own, the sender's content and no tags, accepted or waiting as the recipient's `deliveryMode`
    /// for that connection says.
    func copy(through connectionID: UUID, deliveryMode: DeliveryMode) -> Reminder {
        Reminder(
            title: reminder.title,
            notes: reminder.notes,
            dueTime: reminder.dueTime,
            repeatRule: reminder.repeatRule,
            strength: reminder.strength,
            pace: reminder.pace,
            breakThroughFocus: reminder.breakThroughFocus,
            origin: .received(connectionID: connectionID, sendersReminderID: reminder.id, revision: revision, state: deliveryMode == .startRightAway ? .accepted : .waiting)
        )
    }
}
