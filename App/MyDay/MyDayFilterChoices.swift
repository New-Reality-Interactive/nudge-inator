import NudgeEngine

/// What My Day's filter sheet chooses, applied or as a draft: the tags the person checked, or No
/// Tags, and From others, as the mockup's `dayFilter`. A new one chooses nothing: what Reset leaves.
struct MyDayFilterChoices: FilterSheetChoices {
    typealias Match = TagChoice.Match

    var tags = TagChoice()
    /// Only received reminders: the sheet's From others (ticket 209).
    private(set) var fromOthers = false

    var tagIDs: [Tag.ID] { tags.tagIDs }
    var noTags: Bool { tags.noTags }
    var tagFilter: TagFilter { tags.tagFilter }
    /// Whether it narrows the list: a tag, No Tags or From others.
    var isOn: Bool { tags.isOn || fromOthers }

    /// What the Filter button's badge counts: the checked tags, or 1 for No Tags, and 1 more for
    /// From others, as the mockup's.
    var checkedCount: Int { tags.checkedCount + (fromOthers ? 1 : 0) }

    var match: Match {
        get { tags.match }
        set { tags.match = newValue }
    }

    mutating func toggle(_ tagID: Tag.ID) {
        tags.toggle(tagID)
    }

    mutating func toggleNoTags() {
        tags.toggleNoTags()
    }

    mutating func toggleFromOthers() {
        fromOthers.toggle()
    }

    /// The choices without tags that no longer exist.
    func keeping(tagsIn existing: Set<Tag.ID>) -> MyDayFilterChoices {
        var kept = self
        kept.tags = tags.keeping(tagsIn: existing)
        return kept
    }
}
