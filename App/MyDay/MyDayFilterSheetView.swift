import NudgeEngine
import SwiftUI

/// The filter sheet, the mockup's `dayFilterSheet`: check tags, choose Match All or Any, or No
/// Tags. Changes apply as they are made, so My Day behind it follows, and Clear is the bar's
/// leading button.
struct MyDayFilterSheetView: View {
    let engine: Engine
    @Binding var filter: MyDayFilter

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let sheet = MyDayFilterSheet(engine: engine, filter: filter)
        NavigationStack {
            List {
                if sheet.showsMatch {
                    Section {
                        matchPicker
                    }
                }
                Section {
                    if sheet.tags.isEmpty {
                        EmptyRow(text: Text("No tags yet. Add them when you edit a reminder.", comment: "My Day's filter sheet: the Tags list when no tag exists."))
                    }
                    ForEach(sheet.tags) { row in
                        CheckmarkRow(title: Text(verbatim: row.text), isChecked: row.isChecked) { filter.toggle(row.id) }
                    }
                } header: {
                    Text("Tags", comment: "My Day's filter sheet: header of the list of tags.")
                } footer: {
                    if sheet.showsMatch {
                        Text("All Tags shows reminders with every checked tag. Any Tag shows those with at least one.", comment: "My Day's filter sheet: under the tags when two or more are checked.")
                    } else {
                        Text("Check one or more tags.", comment: "My Day's filter sheet: under the tags.")
                    }
                }
                Section {
                    noTagsRow(isChecked: sheet.isNoTagsChecked)
                } footer: {
                    Text(sheet.result)
                }
            }
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

    /// A segmented control, or a menu at accessibility sizes, where a segmented one would cut its
    /// labels off (DESIGN.md › Tags).
    @ViewBuilder private var matchPicker: some View {
        let picker = Picker(selection: $filter.match) {
            Text("All Tags", comment: "My Day's filter sheet: the Match choice that needs every checked tag.").tag(MyDayFilter.Match.all)
            Text("Any Tag", comment: "My Day's filter sheet: the Match choice that needs at least one checked tag.").tag(MyDayFilter.Match.any)
        } label: {
            Text("Match", comment: "My Day's filter sheet: label of the choice between All Tags and Any Tag.")
        }
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented)
        }
    }

    private func noTagsRow(isChecked: Bool) -> some View {
        Button {
            filter.toggleNoTags()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Design.Spacing.line) {
                    Text("No Tags", comment: "My Day's filter sheet: the row that shows only reminders without tags.")
                        .foregroundStyle(Color(uiColor: .label))
                    Text("Only reminders without tags", comment: "My Day's filter sheet: under No Tags.")
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                Spacer()
                if isChecked {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}
