import SwiftUI

/// The header row of the Reminders and Tags lists (DESIGN.md): the count on its own line, in every
/// size and orientation.
struct CountHeaderRow: View {
    let count: LocalizedStringResource
    /// Lets a tab put VoiceOver on the count, which reads the new result when the control that changed
    /// it (Clear Filters) has left the screen. After a delete, Tags leaves focus to iOS (#139's Comments).
    var countFocus: AccessibilityFocusState<Bool>.Binding?

    var body: some View {
        countText
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var countText: some View {
        let text = Text(count)
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(Color(uiColor: .secondaryLabel))
        if let countFocus {
            text.accessibilityFocused(countFocus)
        } else {
            text
        }
    }
}

#if DEBUG
#Preview("Header row") {
    List {
        Section {
            Text(verbatim: "Row")
        } header: {
            CountHeaderRow(count: RemindersScreen.countText(shown: 12, of: 14))
                .textCase(nil)
        }
    }
}

#Preview("Header row, largest text") {
    List {
        Section {
            Text(verbatim: "Row")
        } header: {
            CountHeaderRow(count: RemindersScreen.countText(shown: 1, of: 14))
                .textCase(nil)
        }
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
