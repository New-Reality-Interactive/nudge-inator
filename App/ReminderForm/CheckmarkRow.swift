import SwiftUI

/// A choice in a list, with a checkmark when it's chosen: a repeat on the Repeat page, a tag on
/// the Tags page. VoiceOver reads it as selected, so the checkmark isn't the only signal.
struct CheckmarkRow: View {
    let title: Text
    let isChecked: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            CheckmarkLabel(title: title, isChecked: isChecked)
        }
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

/// A choice's title with a checkmark when it's chosen: a `CheckmarkRow`'s, or the Repeat page's
/// Custom link's. Whatever holds it marks it selected for VoiceOver.
struct CheckmarkLabel: View {
    let title: Text
    let isChecked: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack {
            // Not the button's tint. A set style isn't dimmed when disabled, so a locked row takes
            // DESIGN.md's secondary label (ticket 16).
            title
                .foregroundStyle(Color(uiColor: isEnabled ? .label : .secondaryLabel))
            Spacer()
            if isChecked {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview {
    List {
        CheckmarkRow(title: Text(verbatim: "#home"), isChecked: true) {}
        CheckmarkRow(title: Text(verbatim: "#money"), isChecked: false) {}
    }
}
