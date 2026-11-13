import NudgeEngine

/// What My Day is filtered by: the tags the person checked and From others, as the mockup's
/// `dayFilter`.
struct MyDayFilter: Equatable {
    typealias Match = TagChoice.Match

    /// What the filter sheet chose.
    var tags = TagChoice()
    /// Only received reminders: the sheet's From others (ticket 209).
    private(set) var fromOthers = false
    /// The count the list is narrowed to, if the person tapped one.
    private(set) var count: MyDayCount?

    var tagIDs: [Tag.ID] { tags.tagIDs }
    var noTags: Bool { tags.noTags }
    var tagFilter: TagFilter { tags.tagFilter }
    var hasTags: Bool { tags.isOn }
    /// Whether the sheet narrows the list: a tag, No Tags or From others.
    var isOn: Bool { hasTags || fromOthers }

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

    /// Narrows the list to the count, or shows everything again if it is already chosen.
    mutating func tap(_ count: MyDayCount) {
        self.count = self.count == count ? nil : count
    }

    /// Clears the tags, No Tags and From others and goes back to Match All. The chosen count stays:
    /// it is chosen on the screen, not in the sheet.
    mutating func clear() {
        tags.clear()
        fromOthers = false
    }

    /// Called when the Filter button shows or goes. With the button gone the sheet's choices clear,
    /// so a filter nobody can see doesn't narrow the list when reminders or tags come back. The
    /// chosen count is the counts' own control and stays.
    mutating func update(offersFilter: Bool) {
        if !offersFilter { clear() }
    }

    /// The filter without tags that no longer exist.
    func keeping(tagsIn existing: Set<Tag.ID>) -> MyDayFilter {
        var kept = self
        kept.tags = tags.keeping(tagsIn: existing)
        return kept
    }
}
