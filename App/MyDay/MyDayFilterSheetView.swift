import NudgeEngine
import SwiftUI

/// The filter sheet, the mockup's `dayFilterSheet`: check tags, choose Match All or Any (from two
/// tags), or No Tags, then From others once someone has sent a reminder. Changes apply as they are
/// made, so My Day behind it follows, and Clear is the bar's leading button.
struct MyDayFilterSheetView: View {
    let engine: Engine
    @Binding var filter: MyDayFilter

    @Environment(\.dismiss) private var dismiss
    @State private var listHeight = NeverShorter()

    var body: some View {
        let sheet = MyDayFilterSheet(engine: engine, filter: filter)
        NavigationStack {
            List {
                // The count goes under the last section, as the mockup's.
                TagChoiceSections(choice: $filter.tags, sheet: sheet.choice) {
                    if !sheet.offersFromOthers { result(sheet) }
                }
                if sheet.offersFromOthers {
                    FromOthersSection(isChecked: filter.fromOthers) { filter.toggleFromOthers() } footer: { result(sheet) }
                }
            }
            .neverShorter($listHeight)
            .navigationTitle(Text("Filter My Day", comment: "Title of My Day's tag filter sheet."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        filter.clear()
                    } label: {
                        Text("Clear", comment: "My Day's filter sheet: removes every tag, and From others, from the filter.")
                    }
                    .disabled(!filter.isOn)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        dismiss()
                    } label: {
                        Label {
                            Text("Done", comment: "My Day's filter sheet's confirm button (a checkmark): closes the sheet.")
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    private func result(_ sheet: MyDayFilterSheet) -> some View {
        Text(sheet.result)
            .padding(.bottom, listHeight.extra)
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
