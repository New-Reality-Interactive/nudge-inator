import NudgeEngine
import SwiftUI

/// The filter sheet, the mockup's `dayFilterSheet`: check tags, choose Match All or Any (from two
/// tags), or No Tags. Changes apply as they are made, so My Day behind it follows, and Clear is the
/// bar's leading button.
struct MyDayFilterSheetView: View {
    let engine: Engine
    @Binding var filter: MyDayFilter

    @Environment(\.dismiss) private var dismiss
    @State private var listHeight = NeverShorter()

    var body: some View {
        let sheet = MyDayFilterSheet(engine: engine, filter: filter)
        NavigationStack {
            List {
                TagChoiceSections(choice: $filter.tags, sheet: sheet.choice) {
                    Text(sheet.result)
                        .padding(.bottom, listHeight.extra)
                }
            }
            .neverShorter($listHeight)
            .navigationTitle(Text("Filter My Day", comment: "Title of My Day's tag filter sheet."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        filter.clearTags()
                    } label: {
                        Text("Clear", comment: "My Day's filter sheet: removes every tag from the filter.")
                    }
                    .disabled(!filter.hasTags)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        dismiss()
                    } label: {
                        Text("Done", comment: "My Day's filter sheet: closes the sheet.")
                    }
                }
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
