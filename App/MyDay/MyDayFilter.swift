import NudgeEngine

/// What My Day is filtered by: the filter sheet's choices, applied, and the count the person
/// tapped on the screen.
struct MyDayFilter: Equatable {
    typealias Match = TagChoice.Match

    /// What the filter sheet's Apply chose, or the tokens and the Filter button's menu left.
    var choices = MyDayFilterChoices()
    /// The count the list is narrowed to, if the person tapped one.
    private(set) var count: MyDayCount?

    var tags: TagChoice {
        get { choices.tags }
        set { choices.tags = newValue }
    }
    var fromOthers: Bool { choices.fromOthers }
    var tagIDs: [Tag.ID] { choices.tagIDs }
    var noTags: Bool { choices.noTags }
    var tagFilter: TagFilter { choices.tagFilter }
    var hasTags: Bool { tags.isOn }
    /// Whether the sheet's choices narrow the list: a tag, No Tags or From others.
    var isOn: Bool { choices.isOn }
    /// What the Filter button's badge counts.
    var checkedCount: Int { choices.checkedCount }

    var match: Match {
        get { choices.match }
        set { choices.match = newValue }
    }

    mutating func toggle(_ tagID: Tag.ID) {
        choices.toggle(tagID)
    }

    mutating func toggleNoTags() {
        choices.toggleNoTags()
    }

    mutating func toggleFromOthers() {
        choices.toggleFromOthers()
    }

    /// Narrows the list to the count, or shows everything again if it is already chosen.
    mutating func tap(_ count: MyDayCount) {
        self.count = self.count == count ? nil : count
    }

    /// Clears the tags, No Tags and From others and goes back to Match All. The chosen count stays:
    /// it is chosen on the screen, not in the sheet.
    mutating func clear() {
        choices = MyDayFilterChoices()
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
        kept.choices = choices.keeping(tagsIn: existing)
        return kept
    }
}
