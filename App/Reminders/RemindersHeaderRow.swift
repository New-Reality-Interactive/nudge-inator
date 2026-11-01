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

/// The Reminders list's header row (DESIGN.md, Reminders tab): the count leading, the controls
/// trailing. When they don't fit side by side, and always at the accessibility sizes, the
/// controls go under the count, where they wrap, so neither is cut off and the chips (#111, #116)
/// join the controls without a new layout.
struct RemindersHeaderRow: View {
    let count: LocalizedStringResource
    @Binding var sort: RemindersSort

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stacked
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Design.Spacing.controlGap) {
                    countText
                    Spacer(minLength: 0)
                    controls
                }
                stacked
            }
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s2) {
            countText
            controls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var countText: some View {
        Text(count)
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(Color(uiColor: .secondaryLabel))
    }

    private var controls: some View {
        FlowLayout(spacing: Design.Spacing.s2) {
            RemindersSortButton(sort: $sort)
        }
    }
}

/// DESIGN.md's `sort-button`: a 44 pt round button that opens the Sort menu, a section for each
/// field with its two orders, the chosen one checked. Any change is one open and one tap: a choice
/// applies at once and closes the menu.
private struct RemindersSortButton: View {
    @Binding var sort: RemindersSort

    var body: some View {
        Menu {
            // Toggles in the menu's sections, not pickers: the system drops the header of a section
            // that holds a picker, or that a picker holds.
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
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                // A capsule, not a circle: at the accessibility sizes the glyph is wider than 44 pt
                // and the button grows around it, as the mockup's does. At 44 pt it is round.
                .padding(Design.Spacing.s1)
                .frame(minWidth: Design.Spacing.rowMin, minHeight: Design.Spacing.rowMin)
                .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
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

#if DEBUG
#Preview("Header row") {
    @Previewable @State var sort = RemindersSort.createdOldestFirst
    List {
        Section {
            Text(verbatim: "Row")
        } header: {
            RemindersHeaderRow(count: RemindersScreen.countText(shown: 12, of: 14), sort: $sort)
                .textCase(nil)
        }
    }
}

#Preview("Header row, largest text") {
    @Previewable @State var sort = RemindersSort(field: .dueDate, order: .descending)
    List {
        Section {
            Text(verbatim: "Row")
        } header: {
            RemindersHeaderRow(count: RemindersScreen.countText(shown: 1, of: 14), sort: $sort)
                .textCase(nil)
        }
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
