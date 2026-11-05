import Foundation
import NudgeEngine

/// What the Tags tab shows, read from the engine at one moment: each tag with its counts, in the
/// Sort menu's order, and the header row's count. A value, so the tests and previews read it with
/// no view.
struct TagsScreen {
    private let list: TagList

    var rows: [TagSummary] { list.rows }
    /// The rows shown: the count's first number.
    var shownCount: Int { list.visibleCount }
    /// Every tag the engine holds: the count's "out of" number.
    var total: Int { list.total }

    var isEmpty: Bool { rows.isEmpty }

    /// The header row's count, "3 tags out of 8", read as one VoiceOver element.
    var countText: LocalizedStringResource { Self.countText(shown: shownCount, of: total) }

    static func countText(shown: Int, of total: Int) -> LocalizedStringResource {
        LocalizedStringResource("\(shown) tags out of \(total)", comment: "Tags tab: the header row's count, in every case, even with nothing narrowing the list. 1: the tags shown. 2: every tag.")
    }

    init(engine: Engine, sort: TagSort = .nameAToZ) {
        list = engine.tagList(sortedBy: sort)
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
