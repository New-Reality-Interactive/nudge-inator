import Foundation
import NudgeEngine

/// What the Reminders tab's Sent view shows (ticket 201), read from the sharing store and the
/// engine's calendar at one moment: the reminders this person sent, grouped by the connected person
/// they went to, as the engine's Sent read-out orders them. A reminder sent to several people shows
/// under each. A value, so the tests and previews read it with no view.
struct SentScreen {
    let people: [Person]
    /// What Sent shows instead of groups, or `nil` when it has some (ticket 202).
    let emptyState: EmptyState?
    /// Every reminder Sent lists with nothing narrowing it, each once: the count's "out of" number.
    let total: Int
    /// What the no-match state says: the search the rows were narrowed by, and whether the sheet's
    /// filters narrowed them too.
    let noMatch: NoMatch

    /// What Sent shows in place of its groups: its two empty states, the mockup's `viewSentTab`, and
    /// the no-match state, its `sentNoMatch` (ticket 328).
    enum EmptyState: Equatable {
        /// No one connected, so nothing can be sent yet: Invite Someone and Manage People.
        case noOneToSendTo
        /// Someone connected, but nothing sent to anyone connected: New Reminder.
        case nothingSent
        /// Something sent, and the search leaves none of it: Mine's no-match state, with its tools.
        case noMatch
    }

    struct Person: Identifiable {
        var connectionID: UUID
        /// The person's whole name, as Connections lists them.
        var name: String
        /// Whether the person shares status with the sender, which the group's header says.
        var sharesStatus: Bool
        var rows: [Row]

        var id: UUID { connectionID }

        /// Trailing the name in the group's header (DESIGN.md, Sent rows; ticket 328).
        var statusSharingText: LocalizedStringResource {
            sharesStatus ? Row.sharingStatusText : Row.notSharingStatusText
        }

    }

    /// One sent reminder as one person has it.
    struct Row: Identifiable {
        var reminderID: Reminder.ID
        var title: String
        /// Who it went to, for VoiceOver: the group's header says it on screen.
        var personName: String
        /// The time of day of its next due time, such as "9:00 AM".
        var time: String
        /// "Today", "Tomorrow", "Yesterday" or a short date, under the time.
        var day: String
        /// How the person's copy is going, as the sender may read it.
        var state: SentCopyState
        /// The strip under a repeating reminder's text: today and the 7 days before, or `nil` for a
        /// one-off and whenever `state` hides it (ticket 207).
        var history: SentHistory?

        var id: Reminder.ID { reminderID }

        /// Whether the copy has reached the person's iPhone, whatever their status sharing, and
        /// whether it waits there for them to accept it (ticket 203).
        var delivery: SentReadOut.Delivery { state.delivery }
        var isDelivered: Bool { state.isDelivered }
        /// The label trailing the row: the copy's status once the person's app reports one.
        var trailing: SentReadOut.Trailing { state.trailing }
        var detailLine: LocalizedStringResource? { state.detailLine }

        /// What VoiceOver reads for the row: the person, the title, how the copy is going or
        /// whether it was delivered or waits to be accepted, and the due time.
        var voiceOverLabel: LocalizedStringResource {
            let state = String(localized: state.spokenState)
            return LocalizedStringResource("\(personName), \(title), \(state), \(day), \(time)", comment: "VoiceOver label of a row on the Reminders tab's Sent view. 1: who it was sent to, such as \"Riley Park\". 2: the reminder's title. 3: how the copy is going, such as \"Done\", \"Delivered, Not sharing status\", \"Not delivered yet\" or \"Waiting for them to accept\". 4: its due day, such as \"Today\". 5: its due time, such as \"9:00 AM\".")
        }

        static let waitingText = LocalizedStringResource("Waiting for them to accept", comment: "Under a sent reminder's title on the Sent view, and under a person's name on its details: their copy has reached their iPhone, which asks them first (Ask me first), and they haven't accepted it yet.")
        static let deliveredText = LocalizedStringResource("Delivered", comment: "A sent reminder's label on the Sent view and its details: the person's copy has reached their iPhone.")
        static let sharingStatusText = LocalizedStringResource("Sharing status", comment: "Reminders tab, Sent: trailing a person's name in the header of their group: they share how their reminders are going with the sender.")
        static let notSharingStatusText = LocalizedStringResource("Not sharing status", comment: "Under a sent reminder's title on the Sent view, under a person's name on its details, and trailing their name in the header of their group on the Sent view: the person keeps how their reminders are going from the sender, so the sender sees only that it was delivered.")
        static let notSharingThisOneText = LocalizedStringResource("Not sharing this one", comment: "Under a sent reminder's title on the Sent view, and under a person's name on its details: the person keeps how this one reminder is going from the sender, so the sender sees only that it was delivered.")
        static let notDeliveredText = LocalizedStringResource("Not delivered yet", comment: "Under a sent reminder's title on the Sent view, and under a person's name on its details: their copy hasn't reached their iPhone yet.")
    }

    /// Sent's no-match wording, the mockup's `sentNoMatch` (ticket 329): a search alone reads as on
    /// Mine, and the sheet's filters name sent reminders.
    struct NoMatch: NoMatchWording {
        /// Trimmed.
        let search: String
        let isFiltered: Bool

        /// Mine's wording for this search alone: the title and image name only the search, and with
        /// no filter on, the line and Clear Search read as on Mine.
        private var searchOnlyWording: RemindersFilter { RemindersFilter(search: search) }

        var noMatchTitle: LocalizedStringResource { searchOnlyWording.noMatchTitle }
        var noMatchSystemImage: String { searchOnlyWording.noMatchSystemImage }

        var noMatchText: LocalizedStringResource? {
            switch (isFiltered, search.isEmpty) {
            case (true, true): LocalizedStringResource("No sent reminders with these filters.", comment: "Reminders tab, Sent: under the title when the Filter Sent sheet's filters leave nothing.")
            case (true, false): LocalizedStringResource("No sent reminders with these filters match this search.", comment: "Reminders tab, Sent: under the title when a search finds nothing under the Filter Sent sheet's filters.")
            case (false, _): searchOnlyWording.noMatchText
            }
        }

        var noMatchClearTitle: LocalizedStringResource {
            switch (isFiltered, search.isEmpty) {
            case (true, true): LocalizedStringResource("Clear Filters", comment: "Reminders tab, Mine and Sent: the no-match empty state's button that turns off what's narrowing the list.")
            case (true, false): LocalizedStringResource("Clear Search and Filters", comment: "Reminders tab, Mine and Sent: the no-match empty state's button when a search and filters are narrowing the list.")
            case (false, _): searchOnlyWording.noMatchClearTitle
            }
        }
    }

    /// The people the reminder with `reminderID` went to, in the screen's order, each with their row.
    func recipients(of reminderID: Reminder.ID) -> [(person: Person, row: Row)] {
        people.compactMap { person in
            person.rows.first { $0.reminderID == reminderID }.map { (person, $0) }
        }
    }

    /// Only connected people are listed, as Send To offers them. A row's due time is the sent
    /// reminder's next at or after the engine's now, or its start when none is left.
    ///
    /// `search` keeps the rows whose title or notes hold it, as Mine's does (ticket 328), and a
    /// person left with none drops out.
    init(engine: Engine, sharing: SharingData, tools: SentTools = SentTools()) {
        let filter = tools.kept(in: sharing).filter
        let matcher = RemindersFilter(search: tools.search)
        noMatch = NoMatch(search: matcher.search, isFiltered: !filter.isEmpty)
        let connections = sharing.sentConnections
        let readOut = Self.readOut(of: sharing, connections: connections)
        let reminders = Self.sentReminders(in: sharing)
        total = Self.countingEachOnce(Self.listedReminderIDs(in: readOut, holding: reminders))
        let sharesStatus = Dictionary(connections.map { ($0.id, $0.sharesStatus) }, uniquingKeysWith: { first, _ in first })
        people = readOut.people.filter { filter.matches(person: $0.connectionID) }.map { person in
            let rows = person.rows.compactMap { row -> (row: Row, due: Date)? in
                guard let reminder = reminders[row.reminderID], matcher.matchesSearch(reminder) else { return nil }
                let due = engine.upcomingDueTimes(of: reminder, count: 1).first ?? reminder.dueTime
                guard filter.matches(reminder, dueDay: engine.calendarDay(of: due)) else { return nil }
                let state = SentCopyState(delivery: row.delivery, status: row.status, waitingToSync: row.waitingToSync)
                guard filter.matches(state) else { return nil }
                return (Row(
                    reminderID: reminder.id,
                    title: reminder.title,
                    personName: person.name,
                    time: engine.timeOfDay(of: due),
                    day: engine.dayLabel(of: due),
                    state: state,
                    history: reminder.repeatRule == nil ? nil : state.historyOccurrences.map { SentHistory(engine: engine, occurrences: $0) }
                ), due)
            }
            return Person(
                connectionID: person.connectionID,
                name: person.name,
                sharesStatus: sharesStatus[person.connectionID] ?? false,
                rows: Self.sorted(rows, by: tools.sort)
            )
        }
        .filter { !$0.rows.isEmpty }
        emptyState = if connections.isEmpty { .noOneToSendTo } else if total == 0 { .nothingSent } else if people.isEmpty { .noMatch } else { nil }
    }

    /// Whether Sent has anything to search and sort: neither of its empty states has its tools
    /// (DESIGN.md, Sent's tools). It builds no rows or due times, so the tab can ask in `body`.
    static func hasTools(in sharing: SharingData) -> Bool {
        let readOut = readOut(of: sharing, connections: sharing.sentConnections)
        return !listedReminderIDs(in: readOut, holding: sentReminders(in: sharing)).isEmpty
    }

    /// The reminders shown, each once however many people it went to: the count's first number.
    var shownCount: Int {
        Self.countingEachOnce(people.flatMap(\.rows).map(\.reminderID))
    }

    /// The header row's count, worded as Mine's: "3 reminders out of 14" (DESIGN.md, Sent's tools).
    var countText: LocalizedStringResource { RemindersScreen.countText(shown: shownCount, of: total) }

    /// Waiting to sync is read from the outbox: the send or a revision not yet through iCloud.
    private static func readOut(of sharing: SharingData, connections: [SentConnection]) -> SentReadOut {
        SentReadOut(connections: connections, copies: sharing.sentCopies, isWaitingToSync: sharing.waitsToSync)
    }

    private static func sentReminders(in sharing: SharingData) -> [Reminder.ID: Reminder] {
        Dictionary(sharing.sentReminders.map { ($0.reminder.id, $0.reminder) }, uniquingKeysWith: { first, _ in first })
    }

    /// Every row's reminder that the store holds, once per person it went to.
    private static func listedReminderIDs(in readOut: SentReadOut, holding reminders: [Reminder.ID: Reminder]) -> [Reminder.ID] {
        readOut.people.flatMap(\.rows).map(\.reminderID).filter { reminders[$0] != nil }
    }

    /// A reminder sent to two people is one reminder (DESIGN.md, Sent's tools).
    private static func countingEachOnce(_ ids: [Reminder.ID]) -> Int {
        Set(ids).count
    }

    /// One person's rows in `sort`'s order. The read-out's order is the order sent, so it is Created,
    /// Oldest First. Rows due at one time keep it under Earliest First, and Newest First and Latest
    /// First are those orders exactly reversed, ties included, as Mine's are (spec #104, Decision 54).
    private static func sorted(_ rows: [(row: Row, due: Date)], by sort: RemindersSort) -> [Row] {
        let ordered = switch sort.field {
        case .created: rows
        case .dueDate: rows.enumerated().sorted { a, b in
            a.element.due != b.element.due ? a.element.due < b.element.due : a.offset < b.offset
        }.map(\.element)
        }
        let inOrder = ordered.map(\.row)
        return sort.order == .ascending ? inOrder : inOrder.reversed()
    }
}

extension SharingData {
    /// Everyone connected, in the order Sent's groups list them: whom Sent shows and whom the Filter
    /// Sent sheet's People lists (ticket 329).
    var sentConnections: [SentConnection] {
        SentReadOut.inOrder(
            connections
                .filter { $0.state == .connected }
                .map { SentConnection(id: $0.id, name: $0.name, sharesStatus: $0.theirs.sharesStatus) }
        )
    }
}

/// How one person's copy of a sent reminder reads to the sender (ticket 206): whether it reached
/// them, and what their app reported. What a Sent row and a recipient on the details both say.
struct SentCopyState: Equatable {
    var delivery: SentReadOut.Delivery
    var status: SentReadOut.Status
    /// The sent reminder or a change to it hasn't gone through iCloud yet (GLOSSARY.md).
    var waitingToSync = false

    /// The occurrences a repeating reminder's 7-day history shows, or `nil` where DESIGN.md hides
    /// it: status sharing off, "Not sharing this one", Waiting to sync, Waiting for them to accept,
    /// and before a status has come (ticket 207).
    var historyOccurrences: [StatusReport.OccurrenceStatus]? {
        guard delivery == .delivered, !waitingToSync, case .reported(_, let history) = status else { return nil }
        return history
    }

    /// Delivered trails a Sent row and a recipient on the details once the copy is on their
    /// iPhone, waiting or started, as the mockup's `sentStatus` labels a waiting copy (ticket 203).
    var isDelivered: Bool { delivery != .notDelivered }

    /// The label trailing a Sent row, and a recipient on the details (the mockup's `sentStatus`):
    /// Waiting to sync while the send or a revision hasn't gone through iCloud (ticket 211), else the
    /// copy's status when the person's app reported one the sender may read, otherwise Delivered once
    /// it is on their iPhone, and nothing before.
    var trailing: SentReadOut.Trailing {
        if waitingToSync { return .waitingToSync }
        return switch delivery {
        case .notDelivered: .nothing
        case .waitingForAcceptance: .delivered
        case .delivered:
            if case .reported(let reported, _) = status { .status(reported) } else { .delivered }
        }
    }

    /// Under the title of a Sent row, and under a person's name on the details: "Not delivered
    /// yet", "Waiting for them to accept", then, once it started, "Delivered" beside a status,
    /// "Not sharing status" or "Not sharing this one", and nothing while no status has come.
    var detailLine: LocalizedStringResource? {
        switch delivery {
        case .notDelivered: SentScreen.Row.notDeliveredText
        case .waitingForAcceptance: SentScreen.Row.waitingText
        case .delivered:
            switch status {
            case .reported: SentScreen.Row.deliveredText
            case .notSharingStatus: SentScreen.Row.notSharingStatusText
            case .notSharingThisOne: SentScreen.Row.notSharingThisOneText
            case .notReportedYet: nil
            }
        }
    }

    /// What VoiceOver reads for the copy: its status when there is one, else "Delivered" with why
    /// no status is shown, else what the detail line says. Whole sentences, so a translation can
    /// order the words as it needs.
    var spokenState: LocalizedStringResource {
        if waitingToSync {
            guard let line = detailLine else { return LocalizedStringResource.waitingToSync }
            let detail = String(localized: line)
            return LocalizedStringResource("Waiting to sync, \(detail)", comment: "VoiceOver, on a Sent row and a recipient on a sent reminder's details: the send or a change to it hasn't gone through iCloud yet. The placeholder is the line under the title, such as \"Not delivered yet\" or \"Delivered\".")
        }
        if case .status(let reported) = trailing { return reported.name }
        switch (delivery, status) {
        case (.delivered, .notSharingStatus):
            return LocalizedStringResource("Delivered, not sharing status", comment: "VoiceOver, on a Sent row: the copy reached the person's iPhone, and they keep how their reminders are going from the sender.")
        case (.delivered, .notSharingThisOne):
            return LocalizedStringResource("Delivered, not sharing this one", comment: "VoiceOver, on a Sent row: the copy reached the person's iPhone, and they keep how this one reminder is going from the sender.")
        default:
            return detailLine ?? SentScreen.Row.deliveredText
        }
    }
}

extension SentReadOut {
    /// The label trailing a Sent row.
    enum Trailing: Equatable {
        /// Not delivered yet.
        case nothing
        /// The send or a revision hasn't gone through iCloud yet (ticket 211).
        case waitingToSync
        /// Delivered, with no status to show.
        case delivered
        case status(ReportedStatus)
    }
}
