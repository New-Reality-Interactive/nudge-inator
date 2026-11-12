import Foundation
import NudgeEngine
import os

/// What `StatusReporter` needs from the sharing model that owns it: the person's received copies,
/// what the sharing store holds, who they are connected with, and the one door changes go out through.
@MainActor
protocol StatusReportHost: AnyObject {
    var receivedReminders: (any ReceivedReminders)? { get }
    func currentData() throws -> SharingData
    func connection(_ connectionID: UUID) -> SharingConnection?
    func submit(_ change: SharingChange) throws
}

/// What the recipient's app tells the sender about each received copy (ticket 206): its status, or
/// only that this one is held back, or with status sharing off, nothing. It sends a copy's record only
/// when it differs from the last one sent this launch, so it can run after every event.
///
/// A store that won't keep an outbox entry stops a run, with the rest left for the next one: it logs,
/// since the event that ran it has happened and mustn't fail for it.
@MainActor
final class StatusReporter {
    /// Set by the model that owns it. Held weakly.
    weak var host: (any StatusReportHost)?

    /// The status record last sent for each received copy this launch, by the copy's ID. A copy
    /// with none has had no report sent this launch, so its current one goes once (a status record
    /// is replaced, never added to). Not kept: a relaunch sends each copy's status again.
    private var reported: [Reminder.ID: SentCopy.StatusRecord] = [:]

    /// For each copy this person holds, with status sharing on for its connection, its status report,
    /// or only that this one is held back (the status itself never leaves the iPhone); with status
    /// sharing off, nothing. A copy that has nothing to say and had nothing sent sends nothing. With
    /// `connectionID`, whose status sharing was just turned off, it deletes the status record of each
    /// copy from that connection whether or not one was sent this launch.
    func report(retractingThrough connectionID: UUID? = nil) {
        guard let host, let receivedReminders = host.receivedReminders else { return }
        let reports = receivedReminders.statusReports()
        guard !reports.isEmpty else { return }
        do {
            let kept = try host.currentData()
            for (copy, report) in reports {
                guard let through = copy.receivedThrough, let sendersReminderID = copy.sendersReminderID, let connection = host.connection(through) else { continue }
                let record = Self.record(of: copy, report: report, in: kept, sharesStatus: connection.mine.sharesStatus)
                try send(record, of: copy.id, sendersReminderID: sendersReminderID, through: through, deleting: through == connectionID)
            }
        } catch {
            Self.logger.error("A status report couldn't be sent: \(error, privacy: .public)")
        }
    }

    /// Remove (ticket 200), before the copy goes: with status sharing on the sender is sent Removed,
    /// or only that this one is held back, and with it off, nothing. A copy its sender canceled sends
    /// nothing, since the sender deleted theirs. Sent before the copy's sync state is forgotten,
    /// which holds "Don't share this one".
    func removing(_ copy: Reminder) {
        defer { reported[copy.id] = nil }
        guard let host, !copy.isCanceled, let through = copy.receivedThrough, let sendersReminderID = copy.sendersReminderID,
              let connection = host.connection(through), connection.mine.sharesStatus
        else { return }
        do {
            let removed = StatusReport(label: .removed, occurrences: [])
            let record = Self.record(of: copy, report: removed, in: try host.currentData(), sharesStatus: true)
            try host.submit(.status(record, for: sendersReminderID, from: through))
        } catch {
            Self.logger.error("A Removed report couldn't be sent: \(error, privacy: .public)")
        }
    }

    /// What the sender may be told of `copy`: its `report`, or only that this one is held back
    /// ("Don't share this one", kept in `data`'s sync state), or with status sharing off, nothing.
    private static func record(of copy: Reminder, report: StatusReport, in data: SharingData, sharesStatus: Bool) -> SentCopy.StatusRecord? {
        guard sharesStatus else { return nil }
        let notSharing = data.receivedSyncStates.first { $0.reminderID == copy.id }?.notSharingThisOne ?? false
        return notSharing ? .heldBack : SentCopy.StatusRecord(report: report, notSharingThisOne: false)
    }

    /// Sends `record` for the copy `copyID` of the sender's reminder `sendersReminderID`, unless it
    /// is what was last sent. A `nil` record deletes the sender's status record, and with nothing sent
    /// this launch it does that only if `deleting`.
    private func send(_ record: SentCopy.StatusRecord?, of copyID: Reminder.ID, sendersReminderID: Reminder.ID, through connectionID: UUID, deleting: Bool) throws {
        let last = reported[copyID]
        guard record != last || (record == nil && deleting) else { return }
        try host?.submit(.status(record, for: sendersReminderID, from: connectionID))
        reported[copyID] = record
    }

    private static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "StatusReporter")
}

extension SentCopy.StatusRecord {
    /// A copy whose status the person keeps from the sender ("Don't share this one"): only the
    /// flag, as the record mapping reads it back (the status itself never leaves the iPhone).
    static let heldBack = SentCopy.StatusRecord(report: StatusReport(label: .comingUp, occurrences: []), notSharingThisOne: true)
}
