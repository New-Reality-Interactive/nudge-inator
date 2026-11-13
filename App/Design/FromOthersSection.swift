import SwiftUI

/// A filter sheet's From section, the mockup's: From others, which shows only received reminders,
/// on the Reminders tab's sheet and My Day's (ticket 209). The footer is the sheet's own.
struct FromOthersSection<Footer: View>: View {
    let isChecked: Bool
    let toggle: () -> Void
    @ViewBuilder var footer: Footer

    var body: some View {
        Section {
            SubtitledCheckmarkRow(
                title: Text("From others", comment: "A filter sheet: the row that shows only reminders someone sent this person."),
                subtitle: Text("Only reminders someone sent you", comment: "A filter sheet: under From others."),
                isChecked: isChecked,
                choose: toggle
            )
        } header: {
            Text("From", comment: "A filter sheet: header of the section with From others.")
        } footer: {
            footer
        }
    }
}

extension FromOthersSection where Footer == EmptyView {
    init(isChecked: Bool, toggle: @escaping () -> Void) {
        self.init(isChecked: isChecked, toggle: toggle) { EmptyView() }
    }
}

/// A `CheckmarkRow` with a line under its title that says what checking it does, as No Tags and
/// From others draw it.
struct SubtitledCheckmarkRow: View {
    let title: Text
    let subtitle: Text
    let isChecked: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            HStack {
                VStack(alignment: .leading, spacing: Design.Spacing.line) {
                    title
                        .foregroundStyle(Color(uiColor: .label))
                    subtitle
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

#Preview("From section") {
    @Previewable @State var on = true
    List {
        FromOthersSection(isChecked: on) { on.toggle() }
    }
}
