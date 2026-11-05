import NudgeEngine
import SwiftUI

extension TagSort.Field {
    /// The header of the Sort menu's section for this field.
    var title: LocalizedStringResource {
        switch self {
        case .name: LocalizedStringResource("Name", comment: "Tags tab's Sort menu: the header of the section that sorts by the tag's name.")
        case .reminderCount: LocalizedStringResource("Reminders", comment: "Tags tab's Sort menu: the header of the section that sorts by how many reminders have each tag.")
        }
    }

    /// This field's two orders, as the menu offers them: the likelier one first.
    var menuOrders: [TagSort.Order] {
        switch self {
        case .name: [.ascending, .descending]
        case .reminderCount: [.descending, .ascending]
        }
    }

    /// The Sort menu's choice of this field in `order`, in this field's words.
    func title(of order: TagSort.Order) -> LocalizedStringResource {
        switch (self, order) {
        case (.name, .ascending): LocalizedStringResource("A to Z", comment: "Tags tab's Sort menu, sorted by Name: alphabetical order.")
        case (.name, .descending): LocalizedStringResource("Z to A", comment: "Tags tab's Sort menu, sorted by Name: reverse alphabetical order.")
        case (.reminderCount, .descending): LocalizedStringResource("Most First", comment: "Tags tab's Sort menu, sorted by Reminders: the tag most reminders have at the top.")
        case (.reminderCount, .ascending): LocalizedStringResource("Fewest First", comment: "Tags tab's Sort menu, sorted by Reminders: the tag fewest reminders have at the top.")
        }
    }
}

extension TagSort {
    /// The Sort button's VoiceOver value, "Name, A to Z". A whole phrase for each choice, not the
    /// menu's two parts joined, so a translation can word it as one.
    var accessibilityValue: LocalizedStringResource {
        switch (field, order) {
        case (.name, .ascending): LocalizedStringResource("Name, A to Z", comment: "VoiceOver value of the Tags tab's Sort button: sorted by Name, A to Z.")
        case (.name, .descending): LocalizedStringResource("Name, Z to A", comment: "VoiceOver value of the Tags tab's Sort button: sorted by Name, Z to A.")
        case (.reminderCount, .descending): LocalizedStringResource("Reminders, Most First", comment: "VoiceOver value of the Tags tab's Sort button: sorted by Reminders, Most First.")
        case (.reminderCount, .ascending): LocalizedStringResource("Reminders, Fewest First", comment: "VoiceOver value of the Tags tab's Sort button: sorted by Reminders, Fewest First.")
        }
    }
}

/// The Sort button, in the bar before New Tag: it opens the Sort menu, a section for each field with
/// its two orders, the chosen one checked. A choice applies at once and closes the menu. As the
/// Reminders tab's `RemindersSortButton`, including its toggles in place of pickers, whose section
/// headers the system drops.
struct TagsSortButton: View {
    @Binding var sort: TagSort

    var body: some View {
        Menu {
            ForEach(TagSort.Field.allCases, id: \.self) { field in
                Section {
                    ForEach(field.menuOrders, id: \.self) { order in
                        Toggle(isOn: isChosen(TagSort(field: field, order: order))) {
                            Text(field.title(of: order))
                        }
                    }
                } header: {
                    Text(field.title)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel(Text("Sort", comment: "VoiceOver label of the Tags tab's Sort button, which opens the Sort menu."))
        .accessibilityValue(Text(sort.accessibilityValue))
    }

    /// Checked while `choice` is the sort, so one item in the whole menu is. A tap on the checked
    /// one leaves it chosen, as a picker's does.
    private func isChosen(_ choice: TagSort) -> Binding<Bool> {
        Binding {
            sort == choice
        } set: { _ in
            sort = choice
        }
    }
}

#if DEBUG
#Preview("Sort button") {
    @Previewable @State var sort = TagSort.nameAToZ
    NavigationStack {
        Text(verbatim: "List")
            .toolbar { TagsSortButton(sort: $sort) }
    }
}
#endif
