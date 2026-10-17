import NudgeEngine
import SwiftUI

/// The form's Repeat page, as the mockup's: the seven presets, then Custom in its own section,
/// as in Calendar. Custom opens ticket 25's page; until then its row is disabled, but a reminder
/// that already has a custom rule shows it checked with the engine's summary.
struct RepeatPage: View {
    @Bindable var form: ReminderForm

    var body: some View {
        Form {
            Section {
                ForEach(RepeatPreset.allCases, id: \.self) { preset in
                    CheckmarkRow(title: Text(preset.title), isChecked: form.repeatPreset == preset) {
                        form.repeatPreset = preset
                    }
                }
            }
            Section {
                // Ticket 25 makes this push the Custom page.
                CheckmarkRow(title: Text("Custom", comment: "The Repeat page's row that opens the custom repeat page."),
                             isChecked: form.repeatPreset == nil) {}
                    .disabled(true)
            } footer: {
                if form.repeatPreset == nil {
                    Text("\(form.repeatSummary).", comment: "Under the Repeat page's Custom row when the repeat is custom. The placeholder is the repeat summary.")
                } else {
                    Text("Every few days, chosen weekdays, the last day of the month, or a repeat that ends.",
                         comment: "Under the Repeat page's Custom row: what a custom repeat can do.")
                }
            }
        }
        .centeredInReadableColumn()
        .navigationTitle(Text("Repeat", comment: "Title of the reminder form's Repeat page."))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One choice of several, with a checkmark on the chosen one. VoiceOver reads it as selected.
private struct CheckmarkRow: View {
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

#Preview("Preset") {
    NavigationStack {
        RepeatPage(form: .preview())
    }
}

#Preview("Custom, dark") {
    NavigationStack {
        RepeatPage(form: .previewCustom())
    }
    .preferredColorScheme(.dark)
}
