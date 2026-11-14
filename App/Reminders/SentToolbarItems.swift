import NudgeEngine
import SwiftUI

/// Sent's Filter and Sort in the Reminders tab's bar (tickets 328 and 329), where Mine's are:
/// Filter, then Sort, sharing a glass group, with New standing apart. The tab shows them only while
/// Sent has its tools (`SentScreen.hasTools(in:)`).
struct SentToolbarItems: ToolbarContent {
    @Binding var tools: SentTools
    /// Whom the filter may still name: people no longer connected don't count in the badge.
    let sharing: SharingData
    /// Whether the Filter button's badge shows (`FilterButton.showsBadge`).
    let showsBadge: Bool
    let openFilter: () -> Void
    /// After Clear All Filters: the tab puts VoiceOver on the count, as on Mine.
    let didClearFilters: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            FilterButton(
                sectionsInUse: tools.kept(in: sharing).filter.sectionsInUse,
                showsBadge: showsBadge,
                open: openFilter,
                clear: {
                    withTransaction(RemindersTab.noAnimation) { tools.filter = SentFilterChoices() }
                    didClearFilters()
                }
            )
        }
        ToolbarItem(placement: .topBarTrailing) {
            RemindersSortButton(sort: $tools.sort.transaction(RemindersTab.noAnimation))
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
    }
}
