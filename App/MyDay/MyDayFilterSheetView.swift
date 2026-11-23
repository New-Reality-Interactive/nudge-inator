import NudgeEngine
import SwiftUI

/// The filter sheet, the mockup's `dayFilterSheet`: check tags, choose Match All or Any (from two
/// tags), or No Tags, then From others once someone has sent a reminder, choosing a draft of
/// what's applied. The bar, Apply, Reset and the prompt before discarding are
/// `FilterSheetScaffold`'s, shared with Reminders and Tags (ticket 209).
struct MyDayFilterSheetView: View {
    let engine: Engine
    @Binding var filter: MyDayFilter
    /// The day My Day shows, whose words and count the sheet uses (#375). Today if none.
    var day: CalendarDay?

    var body: some View {
        let applied = filter.keeping(tagsIn: Set(engine.tags.map(\.id))).choices
        FilterSheetScaffold(
            title: Text("Filter My Day", comment: "Title of My Day's filter sheet."),
            applied: applied,
            summary: { MyDayFilterSheet(engine: engine, draft: $0, applied: applied, day: day) },
            apply: { filter.choices = $0 }
        ) { draft, sheet in
            TagChoiceSections(choice: draft.tags, sheet: sheet.choice) {
                EmptyView()
            }
            if sheet.offersFromOthers {
                FromOthersSection(isChecked: draft.wrappedValue.fromOthers) { draft.wrappedValue.toggleFromOthers() }
            }
        }
    }
}

#if DEBUG
#Preview("Filter sheet") {
    var filter = MyDayFilter()
    let engine = Engine.myDayPreview()
    if let first = engine.tags.first { filter.toggle(first.id) }
    return MyDayFilterSheetView(engine: engine, filter: .constant(filter))
}
#endif
