import NudgeEngine
import SwiftUI

extension RemindersSort.Field {
    /// The header of the Sort menu's section for this field.
    var title: LocalizedStringResource {
        switch self {
        case .created: LocalizedStringResource("Created", comment: "Reminders tab's Sort menu: the header of the section that sorts by when each reminder was made.")
        case .dueDate: LocalizedStringResource("Due Date", comment: "Reminders tab's Sort menu: the header of the section that sorts by the due time each row shows.")
        }
    }

    /// The Sort menu's choice of this field in `order`, in this field's words.
    func title(of order: RemindersSort.Order) -> LocalizedStringResource {
        switch (self, order) {
        case (.created, .ascending): LocalizedStringResource("Oldest First", comment: "Reminders tab's Sort menu, sorted by Created: the reminder made first at the top.")
        case (.created, .descending): LocalizedStringResource("Newest First", comment: "Reminders tab's Sort menu, sorted by Created: the reminder made last at the top.")
        case (.dueDate, .ascending): LocalizedStringResource("Earliest First", comment: "Reminders tab's Sort menu, sorted by Due Date: the earliest due time at the top.")
        case (.dueDate, .descending): LocalizedStringResource("Latest First", comment: "Reminders tab's Sort menu, sorted by Due Date: the latest due time at the top.")
        }
    }
}

extension RemindersSort {
    /// The Sort button's VoiceOver value, "Created, Oldest First". A whole phrase for each choice,
    /// not the menu's two words joined, so a translation can word it as one.
    var accessibilityValue: LocalizedStringResource {
        switch (field, order) {
        case (.created, .ascending): LocalizedStringResource("Created, Oldest First", comment: "VoiceOver value of the Reminders tab's Sort button: sorted by Created, Oldest First.")
        case (.created, .descending): LocalizedStringResource("Created, Newest First", comment: "VoiceOver value of the Reminders tab's Sort button: sorted by Created, Newest First.")
        case (.dueDate, .ascending): LocalizedStringResource("Due Date, Earliest First", comment: "VoiceOver value of the Reminders tab's Sort button: sorted by Due Date, Earliest First.")
        case (.dueDate, .descending): LocalizedStringResource("Due Date, Latest First", comment: "VoiceOver value of the Reminders tab's Sort button: sorted by Due Date, Latest First.")
        }
    }
}

/// The Sort button, in the bar between Filter and New: it opens the Sort menu, a section for each
/// field with its two orders, the chosen one checked. Any change is one open and one tap: a choice
/// applies at once and closes the menu.
struct RemindersSortButton: View {
    @Binding var sort: RemindersSort

    var body: some View {
        Menu {
            // Toggles in the menu's sections, not pickers: the system drops the header of a section
            // that holds a picker, or that a picker holds. Apple's docs don't say so; seen on the
            // iOS 26.5 and 27.0 simulators (#115).
            ForEach(RemindersSort.Field.allCases, id: \.self) { field in
                Section {
                    ForEach(RemindersSort.Order.allCases, id: \.self) { order in
                        Toggle(isOn: isChosen(RemindersSort(field: field, order: order))) {
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
        .accessibilityLabel(Text("Sort", comment: "VoiceOver label of the Reminders tab's Sort button, which opens the Sort menu."))
        .accessibilityValue(Text(sort.accessibilityValue))
    }

    /// Checked while `choice` is the sort, so one item in the whole menu is. A tap on the checked
    /// one leaves it chosen, as a picker's does.
    private func isChosen(_ choice: RemindersSort) -> Binding<Bool> {
        Binding {
            sort == choice
        } set: { _ in
            sort = choice
        }
    }
}
