import Foundation

/// A person the sender is connected with, as the sender's app knows them.
public struct SentConnection: Equatable, Sendable {
    public var id: UUID
    /// The name the sender sees the person under.
    public var name: String
    /// Whether the person shares status with the sender (GLOSSARY.md, Status sharing), as the
    /// connection's settings last said.
    public var sharesStatus: Bool

    public init(id: UUID, name: String, sharesStatus: Bool) {
        self.id = id
        self.name = name
        self.sharesStatus = sharesStatus
    }
}

/// One recipient's copy of a sent reminder, as the sender's app knows it: what the recipient's app
/// sent back, and whether the sender's own changes have gone out.
public struct SentCopy: Equatable, Sendable {
    /// The connection the copy was sent through.
    public var connectionID: UUID
    /// The sender's sent reminder. Every recipient's copy of it shares this ID.
    public var reminderID: UUID
    /// When the sender made the sent reminder.
    public var createdAt: Date
    public var receipt: Receipt
    /// The status record the recipient's app wrote, or `nil` when none has arrived.
    public var statusRecord: StatusRecord?
    /// The sent reminder or a change to it has not gone through iCloud yet (GLOSSARY.md, Waiting
    /// to sync).
    public var waitingToSync: Bool

    /// How far the copy has got, as the recipient's app reported it. The recipient's app marks a
    /// copy that starts right away as `started` when it delivers it.
    public enum Receipt: Equatable, Sendable {
        /// Not on the recipient's iPhone yet.
        case notDelivered
        /// On the iPhone, waiting for the recipient to accept it (Ask me first).
        case waitingForAcceptance
        /// On the iPhone and nudging as planned: started right away, or accepted.
        case started
    }

    /// A status record: the report the recipient's engine made, and the recipient's choice to keep
    /// this one reminder's status from the sender.
    public struct StatusRecord: Equatable, Sendable {
        public var report: StatusReport
        public var notSharingThisOne: Bool

        public init(report: StatusReport, notSharingThisOne: Bool) {
            self.report = report
            self.notSharingThisOne = notSharingThisOne
        }
    }

    public init(
        connectionID: UUID,
        reminderID: UUID,
        createdAt: Date,
        receipt: Receipt,
        statusRecord: StatusRecord?,
        waitingToSync: Bool
    ) {
        self.connectionID = connectionID
        self.reminderID = reminderID
        self.createdAt = createdAt
        self.receipt = receipt
        self.statusRecord = statusRecord
        self.waitingToSync = waitingToSync
    }
}

/// What the sender's side shows for each reminder it sent, grouped by person: the read-out under
/// the Reminders tab's Sent view. Plain values, built from what the sender's app knows.
public struct SentReadOut: Equatable, Sendable {
    /// The people with something sent to them, in order.
    public var people: [Person]

    /// One person and what was sent to them.
    public struct Person: Equatable, Sendable {
        public var connectionID: UUID
        public var name: String
        public var rows: [Row]
    }

    /// One sent reminder as one recipient has it.
    public struct Row: Equatable, Sendable {
        public var reminderID: UUID
        public var delivery: Delivery
        public var status: Status
        public var waitingToSync: Bool
    }

    /// Whether the copy reached the recipient, whatever the status sharing.
    public enum Delivery: Equatable, Sendable {
        case notDelivered
        /// "Waiting for them to accept".
        case waitingForAcceptance
        case delivered
    }

    /// What the row says about how the copy is going.
    public enum Status: Equatable, Sendable {
        /// The copy's status label and each occurrence's for today and the 7 days before, oldest
        /// first, in the recipient's days.
        case reported(ReportedStatus, history: [StatusReport.OccurrenceStatus])
        /// The person's status sharing is off: "Not sharing status". Never a status, even one the
        /// sender already holds.
        case notSharingStatus
        /// The person keeps this one reminder's status from the sender: "Not sharing this one".
        case notSharingThisOne
        /// Nothing to show yet: no status has arrived, or the copy is still waiting to be accepted.
        case notReportedYet
    }

    /// Builds the read-out. A person with nothing sent has no group, and a copy of a connection the
    /// sender no longer holds is left out. People are ordered by name without regard to case, then
    /// by connection ID; a person's rows by the date the sent reminder was made, then by its ID.
    /// The same input in any order gives the same read-out. The name order is deliberately not
    /// localized, so it is the same on every iPhone and in every test; a screen that wants the
    /// person's own locale's order sorts the people again.
    public init(connections: [SentConnection], copies: [SentCopy]) {
        let copiesByConnection = Dictionary(grouping: copies, by: \.connectionID)
        people = connections
            .sorted { Self.isOrdered($0, before: $1) }
            .compactMap { connection in
                guard let sent = copiesByConnection[connection.id], !sent.isEmpty else { return nil }
                let rows = sent
                    .sorted(by: Self.isOrdered)
                    .map { Row($0, sharesStatus: connection.sharesStatus) }
                return Person(connectionID: connection.id, name: connection.name, rows: rows)
            }
    }

    private static func isOrdered(_ a: SentCopy, before b: SentCopy) -> Bool {
        if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
        return a.reminderID.uuidString < b.reminderID.uuidString
    }

    private static func isOrdered(_ a: SentConnection, before b: SentConnection) -> Bool {
        switch a.name.compare(b.name, options: .caseInsensitive) {
        case .orderedAscending: true
        case .orderedDescending: false
        case .orderedSame: a.id.uuidString < b.id.uuidString
        }
    }
}

extension SentReadOut.Row {
    init(_ copy: SentCopy, sharesStatus: Bool) {
        reminderID = copy.reminderID
        waitingToSync = copy.waitingToSync
        status = Self.status(of: copy, sharesStatus: sharesStatus)
        switch copy.receipt {
        case .notDelivered:
            delivery = .notDelivered
        case .waitingForAcceptance:
            // A waiting copy the recipient removed has left the wait, and the sender sees that
            // only while the recipient shares status.
            if case .reported(.removed, _) = status {
                delivery = .delivered
            } else {
                delivery = .waitingForAcceptance
            }
        case .started:
            delivery = .delivered
        }
    }

    private static func status(of copy: SentCopy, sharesStatus: Bool) -> SentReadOut.Status {
        guard sharesStatus else { return .notSharingStatus }
        guard let record = copy.statusRecord else { return .notReportedYet }
        if record.notSharingThisOne { return .notSharingThisOne }
        let report = record.report
        switch copy.receipt {
        case .notDelivered:
            return .notReportedYet
        case .waitingForAcceptance where report.label != .removed:
            // A waiting copy's report reads Coming up; the sender's side says Waiting instead (#188).
            return .notReportedYet
        case .waitingForAcceptance, .started:
            return .reported(report.label, history: report.occurrences.sorted { $0.dueTime < $1.dueTime })
        }
    }
}
