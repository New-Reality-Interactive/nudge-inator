import Foundation
import NudgeEngine

/// What the Tags tab shows, read from the engine at one moment: each tag with its counts. A
/// value, so the tests and previews read it with no view.
struct TagsScreen {
    /// By name ignoring case, as the engine sorts them.
    let rows: [TagSummary]

    /// Reminders with no tags, which My Day's filter can show.
    let untaggedCount: Int

    var isEmpty: Bool { rows.isEmpty }

    init(engine: Engine) {
        rows = engine.tagSummaries()
        untaggedCount = engine.reminders.count { $0.tagIDs.isEmpty }
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

    /// Just the reminder count, under the name in Edit mode.
    var reminderCountText: LocalizedStringResource {
        LocalizedStringResource("\(reminderCount) reminders", comment: "Tags, Edit mode: under a tag's name. The placeholder is how many reminders have the tag.")
    }
}
