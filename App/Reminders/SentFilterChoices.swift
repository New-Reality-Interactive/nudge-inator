import Foundation
import NudgeEngine

/// What the Filter Sent sheet has chosen (ticket 329), applied or as a draft: the mockup's
/// `newSentFilter`. Search isn't part of it, so Apply, Reset and Clear All Filters leave the search
/// as it is. Sent has no tags.
///
/// It is matched against each person's copy, since status is per person: one person's Done
/// doesn't hide or show another person's row of the same reminder.
struct SentFilterChoices: FilterSheetChoices {
    /// The connections whose groups show.
    private(set) var people: Set<UUID> = []
    private(set) var statuses: Set<Status> = []
    private(set) var strengths: Set<Strength> = []
    private(set) var dueFrom: CalendarDay?
    private(set) var dueTo: CalendarDay?

    /// Whether nothing is chosen: what Reset leaves.
    var isEmpty: Bool { self == SentFilterChoices() }

    /// The Filter button's badge: how many of the sheet's sections are in use, not how many choices.
    var sectionsInUse: Int {
        [!people.isEmpty, !statuses.isEmpty, !strengths.isEmpty, dueFrom != nil || dueTo != nil].count { $0 }
    }

    /// What a person's copy may be matched by, the mockup's `SENT_STATUSES`: a status the person's
    /// app reports, or what a row shows in place of one.
    enum Status: CaseIterable, Hashable {
        case reported(ReportedStatus)
        case waitingToAccept
        case waitingToSync
        case notSharing

        /// In the sheet's order.
        static let allCases: [Status] = [
            .reported(.nudging), .reported(.comingUp), .reported(.paused), .reported(.done),
            .reported(.missed), .reported(.skipped), .reported(.removed),
            .waitingToAccept, .waitingToSync, .notSharing,
        ]
    }

    func isChosen(person: UUID) -> Bool { people.contains(person) }

    func isChosen(_ status: Status) -> Bool { statuses.contains(status) }

    func isChosen(_ strength: Strength) -> Bool { strengths.contains(strength) }

    mutating func toggle(person: UUID) {
        if people.remove(person) == nil { people.insert(person) }
    }

    mutating func toggle(_ status: Status) {
        if statuses.remove(status) == nil { statuses.insert(status) }
    }

    mutating func toggle(_ strength: Strength) {
        if strengths.remove(strength) == nil { strengths.insert(strength) }
    }

    /// The first day a reminder may be due. It can't pass the last, so it stops there.
    mutating func setDueFrom(_ day: CalendarDay?) {
        dueFrom = day.map { min($0, dueTo ?? $0) }
    }

    /// The last day a reminder may be due. It can't pass the first, so it stops there.
    mutating func setDueTo(_ day: CalendarDay?) {
        dueTo = day.map { max($0, dueFrom ?? $0) }
    }

    /// The filter without people no longer connected, as Mine's drops deleted tags.
    func keepingConnectedPeople(in sharing: SharingData) -> SentFilterChoices {
        var kept = self
        kept.people.formIntersection(sharing.sentConnections.map(\.id))
        return kept
    }

    /// Whether `person`'s group shows.
    func matches(person: UUID) -> Bool {
        people.isEmpty || people.contains(person)
    }

    /// Whether the row of one person's copy in `state` shows.
    func matches(_ state: SentCopyState) -> Bool {
        statuses.isEmpty || state.filterStatus.map(statuses.contains) == true
    }

    /// Whether `reminder`'s rows show by its strength and `dueDay`, the day of the due time the
    /// rows show. Both days of the range are included.
    func matches(_ reminder: Reminder, dueDay: CalendarDay) -> Bool {
        (strengths.isEmpty || strengths.contains(reminder.strength))
            && dueFrom.map { $0 <= dueDay } != false
            && dueTo.map { dueDay <= $0 } != false
    }
}

extension SentCopyState {
    /// The Status choice the copy matches, as the mockup's `sentKey` picks it: Waiting to sync first,
    /// then Waiting to accept, then Not sharing, else the status the person's app reported. A copy
    /// not delivered yet, or with no status reported yet, matches none.
    var filterStatus: SentFilterChoices.Status? {
        if waitingToSync { return .waitingToSync }
        switch delivery {
        case .notDelivered: return nil
        case .waitingForAcceptance: return .waitingToAccept
        case .delivered: break
        }
        return switch status {
        case .reported(let reported, _): .reported(reported)
        case .notSharingStatus, .notSharingThisOne: .notSharing
        case .notReportedYet: nil
        }
    }
}
