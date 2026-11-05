import Foundation
import NudgeEngine

/// What the Tags tab shows, read from the engine at one moment: each tag with its counts, in the
/// Sort menu's order and narrowed by the search and the filter, and the header row's count. A
/// value, so the tests and previews read it with no view.
struct TagsScreen {
    private let list: TagList

    var rows: [TagSummary] { list.rows }
    /// The rows shown: the count's first number.
    var shownCount: Int { list.visibleCount }
    /// Every tag the engine holds: the count's "out of" number.
    var total: Int { list.total }

    /// Which empty state the tab shows, or `nil` when it has rows.
    let emptyState: EmptyState?

    enum EmptyState: Equatable {
        /// The engine holds no tag at all.
        case noTags
        /// The engine holds tags, and what's narrowing the list leaves none of them.
        case noMatch
    }

    /// The header row's count, "3 tags out of 8", read as one VoiceOver element.
    var countText: LocalizedStringResource { Self.countText(shown: shownCount, of: total) }

    static func countText(shown: Int, of total: Int) -> LocalizedStringResource {
        LocalizedStringResource("\(shown) tags out of \(total)", comment: "Tags tab: the header row's count, in every case, even with nothing narrowing the list. 1: the tags shown. 2: every tag.")
    }

    init(engine: Engine, sort: TagSort = .nameAToZ, filter: TagListFilter = TagListFilter()) {
        list = engine.tagList(sortedBy: sort, filteredBy: filter)
        emptyState = list.total == 0 ? .noTags : (list.rows.isEmpty ? .noMatch : nil)
    }
}

/// The no-match empty state's wording, which names what's narrowing the list: the search, the
/// filter or both. Each case is a whole string, as the mockup's `tagNoMatch()` draws them.
extension TagListFilter {
    var noMatchTitle: LocalizedStringResource {
        if search.isEmpty {
            LocalizedStringResource("No Matches", comment: "Tags tab: title when tags exist but the filter leaves none.")
        } else {
            LocalizedStringResource("No Results for “\(search)”", comment: "Tags tab: title when a search finds nothing. 1: the text searched for, without leading or trailing spaces.")
        }
    }

    /// The line under the title.
    var noMatchText: LocalizedStringResource {
        switch (hasNoReminders, search.isEmpty) {
        case (true, false): LocalizedStringResource("No tags with this filter match this search.", comment: "Tags tab: under the title when a search finds nothing under the filter sheet's filter.")
        case (true, true): LocalizedStringResource("No tags with this filter.", comment: "Tags tab: under the title when the filter sheet's filter leaves nothing.")
        case (false, _): LocalizedStringResource("Check the spelling or try a new search.", comment: "Tags tab: under the title when a search finds nothing.")
        }
    }

    /// The label of the button that turns off the search and the filter.
    var noMatchClearTitle: LocalizedStringResource {
        switch (hasNoReminders, search.isEmpty) {
        case (true, false): LocalizedStringResource("Clear Search and Filter", comment: "Tags tab: the no-match empty state's button when a search and the filter are narrowing the list.")
        case (true, true): LocalizedStringResource("Clear Filter", comment: "Tags tab: the no-match empty state's button when the filter is narrowing the list.")
        case (false, _): LocalizedStringResource("Clear Search", comment: "Tags tab: the no-match empty state's button when a search is narrowing the list.")
        }
    }

    var noMatchSystemImage: String {
        search.isEmpty ? "line.3.horizontal.decrease" : "magnifyingglass"
    }
}

extension TagSummary {
    /// Under the tag's name, the mockup's "3 reminders · 2 today · 1 nudging". The nudging part is
    /// bold, which the row turns red.
    var counts: LocalizedStringResource {
        if nudgingCount > 0 {
            return LocalizedStringResource("\(reminderCount) reminders · \(dueTodayCount) today · **\(nudgingCount) nudging**", comment: "Tags: under a tag's name. 1: how many reminders have the tag. 2: how many of them are due today. 3: how many are nudging, in bold, shown in red.")
        }
        return LocalizedStringResource("\(reminderCount) reminders · \(dueTodayCount) today", comment: "Tags: under a tag's name when none is nudging. 1: how many reminders have the tag. 2: how many of them are due today.")
    }

    /// What the delete question says: how many reminders use the tag, and that they stay.
    var deleteMessage: LocalizedStringResource {
        guard reminderCount > 0 else {
            return LocalizedStringResource("No reminders use this tag.", comment: "Tags: the message of the question that asks before deleting a tag that no reminder has.")
        }
        return LocalizedStringResource("\(reminderCount) reminders use this tag. It's removed from them, and they aren't deleted.", comment: "Tags: the message of the question that asks before deleting a tag. The placeholder is how many reminders have the tag.")
    }
}
