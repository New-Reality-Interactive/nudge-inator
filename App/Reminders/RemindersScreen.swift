import Foundation
import NudgeEngine

/// What the Reminders tab shows, read from the engine at one moment: every reminder once, in the
/// Sort menu's order, with its status, due time and tags, and the header row's count. A value, so
/// the tests and previews read it with no view.
struct RemindersScreen {
    let rows: [Row]
    /// Every reminder the engine holds: the count's "out of" number.
    let total: Int
    /// Which empty state the tab shows in place of the list, or `nil` when it has rows.
    let emptyState: EmptyState?

    enum EmptyState: Equatable {
        /// The engine holds no reminder at all.
        case noReminders
        /// The engine holds reminders, and what's narrowing the list leaves none of them.
        case noMatch
    }

    struct Row: Identifiable {
        var reminder: Reminder
        var status: ReminderStatus
        /// The time of day of the row's due time, such as "9:00 AM".
        var time: String
        /// "Today", "Tomorrow", "Yesterday" or a short date, under the time.
        var day: String
        /// The reminder's tags that the engine holds, as "#home".
        var tags: [String]

        var id: Reminder.ID { reminder.id }
        var title: String { reminder.title }
        /// Done is offered only while Nudging (DESIGN.md, Swipe actions). Every row offers Delete.
        var offersDone: Bool { status == .nudging }
    }

    /// The rows shown: the count's first number.
    var shownCount: Int { rows.count }

    /// The header row's count, "3 reminders out of 14", read as one VoiceOver element.
    var countText: LocalizedStringResource { Self.countText(shown: shownCount, of: total) }

    static func countText(shown: Int, of total: Int) -> LocalizedStringResource {
        LocalizedStringResource("\(shown) reminders out of \(total)", comment: "Reminders tab: the header row's count, in every case, even with nothing narrowing the list. 1: the reminders shown. 2: every reminder.")
    }

    /// `keptOrder` is the rows' order when the list's inputs (the sort, and the filter's search and
    /// chip) last changed. Sorted by Due Date, Done or going Missed changes a row's due time, so
    /// the rows keep that order rather than move under the person (spec #104, Decision 35). A
    /// reminder it doesn't hold, added since, goes where the sort puts it. `knownIDs`: see `list`.
    init(
        engine: Engine,
        sort: RemindersSort = .createdOldestFirst,
        filter: RemindersFilter = RemindersFilter(),
        keptOrder: [Reminder.ID]? = nil,
        knownIDs: Set<Reminder.ID>? = nil
    ) {
        let list = Self.list(engine: engine, sort: sort, filter: filter, knownIDs: knownIDs)
        let items = keptOrder.map { Self.items(list.items, keeping: $0) } ?? list.items
        total = list.total
        rows = items.map { item in
            Row(
                reminder: item.reminder,
                status: item.status,
                time: engine.timeOfDay(of: item.dueTime),
                day: engine.dayLabel(of: item.dueTime),
                tags: engine.tagLabels(for: item.reminder.tagIDs)
            )
        }
        emptyState = engine.reminders.isEmpty ? .noReminders : (rows.isEmpty ? .noMatch : nil)
    }

    /// The engine's list for the screen. `knownIDs` is what the engine held when the filter last
    /// changed: a reminder it doesn't hold is new, and shows even if the filter would hide it,
    /// until the filter next changes (spec #104, Decision 20).
    static func list(engine: Engine, sort: RemindersSort, filter: RemindersFilter, knownIDs: Set<Reminder.ID>?) -> RemindersList {
        let new = knownIDs.map { known in Set(engine.reminders.map(\.id).filter { !known.contains($0) }) } ?? []
        return engine.remindersList(sortedBy: sort, filteredBy: filter, alwaysShowing: new)
    }

    /// `sorted` in `keptOrder`, without the reminders it no longer holds, and with each one it
    /// didn't hold at its index in `sorted`.
    private static func items(_ sorted: [RemindersList.Item], keeping keptOrder: [Reminder.ID]) -> [RemindersList.Item] {
        let kept = Set(keptOrder)
        let byID = Dictionary(uniqueKeysWithValues: sorted.map { ($0.reminder.id, $0) })
        var items = keptOrder.compactMap { byID[$0] }
        for (index, item) in sorted.enumerated() where !kept.contains(item.reminder.id) {
            items.insert(item, at: min(index, items.count))
        }
        return items
    }
}

/// The no-match empty state's wording, which names what's narrowing the list. Each case is a whole
/// string, as the mockup's `noMatch()` draws them.
extension RemindersFilter {
    var noMatchTitle: LocalizedStringResource {
        if search.isEmpty {
            LocalizedStringResource("No Matches", comment: "Reminders tab: title when reminders exist but what's narrowing the list leaves none.")
        } else {
            LocalizedStringResource("No Results for “\(search)”", comment: "Reminders tab: title when a search finds nothing. 1: the text searched for, without leading or trailing spaces.")
        }
    }

    /// The line under the title, or `nil` when nothing names what's narrowing the list.
    var noMatchText: LocalizedStringResource? {
        switch (chip, search.isEmpty) {
        case (let chip?, true): chip.noMatchText
        case (let chip?, false): chip.noMatchSearchText
        case (nil, false): LocalizedStringResource("Check the spelling or try a new search.", comment: "Reminders tab: under the title when a search alone finds nothing.")
        case (nil, true): nil
        }
    }

    /// The label of the button that turns off whatever's narrowing the list.
    var noMatchClearTitle: LocalizedStringResource {
        switch (statuses.isEmpty, search.isEmpty) {
        case (true, false): LocalizedStringResource("Clear Search", comment: "Reminders tab: the no-match empty state's button when only a search is narrowing the list.")
        case (false, false): LocalizedStringResource("Clear Search and Filters", comment: "Reminders tab: the no-match empty state's button when a search and filters are narrowing the list.")
        default: LocalizedStringResource("Clear Filters", comment: "Reminders tab: the no-match empty state's button that turns off what's narrowing the list.")
        }
    }

    var noMatchSystemImage: String {
        search.isEmpty ? "line.3.horizontal.decrease" : "magnifyingglass"
    }
}
