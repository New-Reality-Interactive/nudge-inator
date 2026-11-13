import Foundation

/// What a status record the sender has just received is news of (ticket 208, spec #127, Status): a
/// copy marked Done, removed, or gone Missed. Pause, Resume and Skipped show only in the app, so
/// they are no notice.
public struct SentStatusNotice: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case done
        case missed
        case removed
    }

    public var kind: Kind
    /// The due time of the occurrence that closed, or `nil` for a copy removed, or a one-off whose
    /// occurrence is older than the report's days and so is read from its label.
    public var occurrence: Date?

    public init(kind: Kind, occurrence: Date?) {
        self.kind = kind
        self.occurrence = occurrence
    }

    /// The notice `arriving` makes against `held`, the record the sender held before it, or `nil`
    /// when it is no news.
    ///
    /// A repeating reminder's label reads Coming up again once today's occurrence is Done, so Done
    /// and Missed are read from the occurrences: the ones that closed and that the sender didn't hold
    /// as closed that way. Several at once (the recipient was away for days) make one notice, for the
    /// latest. A one-off older than the report's days has no occurrence, so its label tells.
    ///
    /// With nothing held, or only that this one is held back, the report is the baseline: showing the
    /// current status isn't news. Removed is the exception, since nothing follows it.
    public init?(held: SentCopy.StatusRecord?, arriving: SentCopy.StatusRecord?) {
        guard let arriving, !arriving.notSharingThisOne else { return nil }
        let heldStatus = held.flatMap { $0.notSharingThisOne ? nil : $0.report }
        if arriving.report.label == .removed {
            guard heldStatus?.label != .removed else { return nil }
            self.init(kind: .removed, occurrence: nil)
            return
        }
        guard let heldStatus else { return nil }
        let closedBefore = heldStatus.occurrences.filter { $0.label.closes }.map { Closed(dueTime: $0.dueTime, label: $0.label) }
        let newlyClosed = arriving.report.occurrences.filter { $0.label.closes && !closedBefore.contains(Closed(dueTime: $0.dueTime, label: $0.label)) }
        if let latest = newlyClosed.max(by: { $0.dueTime < $1.dueTime }), let kind = latest.label.noticeKind {
            self.init(kind: kind, occurrence: latest.dueTime)
        } else if heldStatus.label != arriving.report.label, let kind = arriving.report.label.noticeKind {
            self.init(kind: kind, occurrence: nil)
        } else {
            return nil
        }
    }

    private struct Closed: Equatable {
        var dueTime: Date
        var label: ReportedStatus
    }
}

private extension ReportedStatus {
    /// Done and Missed: the two ways an occurrence closes that tell the sender something.
    var closes: Bool { self == .done || self == .missed }

    var noticeKind: SentStatusNotice.Kind? {
        switch self {
        case .done: .done
        case .missed: .missed
        case .removed: .removed
        case .nudging, .comingUp, .paused, .skipped: nil
        }
    }
}
