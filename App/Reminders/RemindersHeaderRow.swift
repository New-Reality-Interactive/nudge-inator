import SwiftUI

/// The Reminders list's header row (DESIGN.md, Reminders tab): the count on its own line, in every
/// size and orientation.
struct RemindersHeaderRow: View {
    let count: LocalizedStringResource
    /// Lets the screen put VoiceOver on the count, which reads the new result when the control that
    /// changed it (Clear Filters) has left the screen. Previews have no screen to do that.
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
            RemindersHeaderRow(count: RemindersScreen.countText(shown: 12, of: 14))
                .textCase(nil)
        }
    }
}

#Preview("Header row, largest text") {
    List {
        Section {
            Text(verbatim: "Row")
        } header: {
            RemindersHeaderRow(count: RemindersScreen.countText(shown: 1, of: 14))
                .textCase(nil)
        }
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
