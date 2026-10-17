import SwiftUI

/// A choice in a list, with a checkmark when it's chosen: a repeat on the Repeat page, a tag on
/// the Tags page. VoiceOver reads it as selected, so the checkmark isn't the only signal.
struct CheckmarkRow: View {
    let title: Text
    let isChecked: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            HStack {
                title
                    .foregroundStyle(Color(uiColor: .label))
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

#Preview {
    List {
        CheckmarkRow(title: Text(verbatim: "#home"), isChecked: true) {}
        CheckmarkRow(title: Text(verbatim: "#money"), isChecked: false) {}
    }
}
