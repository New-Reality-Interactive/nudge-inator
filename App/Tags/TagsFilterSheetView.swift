import NudgeEngine
import SwiftUI

/// The Tags filter sheet, the mockup's `tagFilterSheet`: one section with one condition about the
/// tag itself, Has no reminders (spec #104, Decision 53). The bar, Apply, Reset and the prompt
/// before discarding are `FilterSheetScaffold`'s, shared with Reminders.
struct TagsFilterSheetView: View {
    let engine: Engine
    let applied: TagsFilterChoices
    /// What's in the search field, for the count Apply would show. The sheet leaves it alone.
    let search: String
    let apply: (TagsFilterChoices) -> Void

    var body: some View {
        FilterSheetScaffold(
            title: Text("Filter Tags", comment: "Title of the Tags tab's filter sheet."),
            applied: applied,
            summary: { TagsFilterSheet(engine: engine, draft: $0, applied: applied, search: search) },
            apply: apply
        ) { draft, _ in
            Section {
                CheckmarkRow(
                    title: Text("Has no reminders", comment: "Tags' filter sheet: the condition that shows only the tags no reminder uses."),
                    isChecked: draft.wrappedValue.hasNoReminders
                ) {
                    draft.wrappedValue.hasNoReminders.toggle()
                }
            } footer: {
                Text("Shows only tags that no reminder uses.", comment: "Tags' filter sheet: under the Has no reminders condition.")
            }
        }
    }
}

#if DEBUG
#Preview("Filter sheet") {
    TagsFilterSheetView(engine: .myDayPreview(), applied: TagsFilterChoices(), search: "") { _ in }
}
#endif
