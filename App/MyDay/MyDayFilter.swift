import NudgeEngine

/// What My Day is filtered by: the tags the person checked, as the mockup's `dayFilter`.
struct MyDayFilter: Equatable {
    typealias Match = TagChoice.Match

    /// What the filter sheet chose.
    var tags = TagChoice()
    /// The count the list is narrowed to, if the person tapped one.
    private(set) var count: MyDayCount?

    var tagIDs: [Tag.ID] { tags.tagIDs }
    var noTags: Bool { tags.noTags }
    var tagFilter: TagFilter { tags.tagFilter }
    var hasTags: Bool { tags.isOn }

    /// What the Filter button's badge counts: the checked tags, or 1 for No Tags.
    var checkedCount: Int { tags.checkedCount }

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

    /// Narrows the list to the count, or shows everything again if it is already chosen.
    mutating func tap(_ count: MyDayCount) {
        self.count = self.count == count ? nil : count
    }

    /// Clears the tags and No Tags and goes back to Match All. The chosen count stays: it is
    /// chosen on the screen, not in the sheet.
    mutating func clearTags() {
        tags.clear()
    }

    /// Called when the Filter button shows or goes. With the button gone the tags clear, so a filter
    /// nobody can see doesn't narrow the list when reminders or tags come back. The chosen count is
    /// the counts' own control and stays.
    mutating func update(offersFilter: Bool) {
        if !offersFilter { clearTags() }
    }

    /// The filter without tags that no longer exist.
    func keeping(tagsIn existing: Set<Tag.ID>) -> MyDayFilter {
        var kept = self
        kept.tags = tags.keeping(tagsIn: existing)
        return kept
    }
}
