import Foundation
import NudgeEngine

/// Sent's search, Sort and Filter, apart from Mine's, as the mockup's `newSentTools` keeps them
/// (tickets 328 and 329). Screen state: a launch starts Sent on Created, Oldest First, with no
/// search and no filter.
struct SentTools: Equatable {
    /// What's in the search field, spaces included. `SentScreen` trims it.
    var search = ""
    var sort = RemindersSort.createdOldestFirst
    /// What's applied from the Filter Sent sheet. Read it through `kept(in:)`, which drops people
    /// no longer connected.
    var filter = SentFilterChoices()

    /// These tools without people no longer connected in the filter, as Mine's drops deleted tags.
    func kept(in sharing: SharingData) -> SentTools {
        var kept = self
        kept.filter = filter.keepingConnectedPeople(in: sharing)
        return kept
    }

    /// The no-match state's button, and what goes with Sent's last reminder: the sort stays.
    mutating func clearSearchAndFilter() {
        search = ""
        filter = SentFilterChoices()
    }
}
