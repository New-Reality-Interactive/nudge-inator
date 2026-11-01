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

extension RemindersChip {
    var title: LocalizedStringResource {
        switch self {
        case .nudging: LocalizedStringResource("Nudging", comment: "Reminders tab: the header row's chip that shows only Nudging reminders.")
        case .missed: LocalizedStringResource("Missed", comment: "Reminders tab: the header row's chip that shows only Missed reminders.")
        }
    }

    /// The no-match empty state's line while this chip is what's narrowing the list.
    var noMatchText: LocalizedStringResource {
        switch self {
        case .nudging: LocalizedStringResource("No Nudging reminders.", comment: "Reminders tab: under the title when the Nudging chip leaves nothing.")
        case .missed: LocalizedStringResource("No Missed reminders.", comment: "Reminders tab: under the title when the Missed chip leaves nothing.")
        }
    }
}

/// The Reminders list's header row (DESIGN.md, Reminders tab): the count on its own line, then the
/// chips at the leading edge, wrapping if they must so none is cut off, and the Sort button at the
/// trailing edge. At the accessibility sizes the Sort button goes on a line of its own: beside it, a
/// lit chip is too narrow for its word, which breaks mid-word.
struct RemindersHeaderRow: View {
    let count: LocalizedStringResource
    @Binding var sort: RemindersSort
    @Binding var filter: RemindersFilter

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s2) {
            countText
            if dynamicTypeSize.isAccessibilitySize {
                chips
                RemindersSortButton(sort: $sort)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                HStack(alignment: .top, spacing: Design.Spacing.s2) {
                    chips
                        .frame(maxWidth: .infinity, alignment: .leading)
                    RemindersSortButton(sort: $sort)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var countText: some View {
        Text(count)
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(Color(uiColor: .secondaryLabel))
    }

    private var chips: some View {
        FlowLayout(spacing: Design.Spacing.s2) {
            ForEach(RemindersChip.allCases, id: \.self) { chip in
                RemindersChipButton(chip: chip, isOn: filter.chip == chip) { filter.toggle(chip) }
            }
        }
    }
}

/// DESIGN.md's `filter-chip`: a 44 pt capsule, with a leading checkmark while on so on and off
/// don't differ by color alone. VoiceOver reads a button with the selected trait while on.
private struct RemindersChipButton: View {
    let chip: RemindersChip
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: Design.Spacing.s1) {
                if isOn {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }
                Text(chip.title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isOn ? Color.onAccent : Color.accentColor)
            .padding(.horizontal, Design.Spacing.s3)
            .padding(.vertical, Design.Spacing.s1)
            .frame(minHeight: Design.Spacing.rowMin)
            .background(Capsule().fill(isOn ? Color.accentColor : Color(uiColor: .tertiarySystemFill)))
            .modifier(IncreasedContrastEdge())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
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
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                // A capsule, not a circle: at the accessibility sizes the glyph is wider than 44 pt
                // and the button grows around it, as the mockup's does. At 44 pt it is round.
                .padding(Design.Spacing.s1)
                .frame(minWidth: Design.Spacing.rowMin, minHeight: Design.Spacing.rowMin)
                .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
                .modifier(IncreasedContrastEdge())
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

/// The mockup's edge on the header row's capsules with Increase Contrast on, where the tertiary
/// fill alone hardly shows.
private struct IncreasedContrastEdge: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.overlay {
            if contrast == .increased {
                Capsule().strokeBorder(Color(uiColor: .systemGray))
            }
        }
    }
}

#if DEBUG
#Preview("Header row") {
    @Previewable @State var sort = RemindersSort.createdOldestFirst
    @Previewable @State var filter = RemindersFilter()
    List {
        Section {
            Text(verbatim: "Row")
        } header: {
            RemindersHeaderRow(count: RemindersScreen.countText(shown: 12, of: 14), sort: $sort, filter: $filter)
                .textCase(nil)
        }
    }
}

#Preview("Header row, largest text") {
    @Previewable @State var sort = RemindersSort(field: .dueDate, order: .descending)
    @Previewable @State var filter = RemindersFilter(statuses: [.missed])
    List {
        Section {
            Text(verbatim: "Row")
        } header: {
            RemindersHeaderRow(count: RemindersScreen.countText(shown: 1, of: 14), sort: $sort, filter: $filter)
                .textCase(nil)
        }
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
