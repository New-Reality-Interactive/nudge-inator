import NudgeEngine
import SwiftUI

/// The form's Repeat page, as the mockup's: Never and the six presets, then Custom in its own section,
/// as in Calendar, which opens the Custom page. With a custom rule Custom is checked, with the
/// engine's summary under it.
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
                let isCustom = form.repeatPreset == nil
                NavigationLink(value: ReminderFormPage.custom) {
                    HStack {
                        Text("Custom", comment: "The Repeat page's row that opens the custom repeat page.")
                        Spacer()
                        if isCustom {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityAddTraits(isCustom ? .isSelected : [])
            } footer: {
                if form.repeatPreset == nil {
                    RepeatSummarySentence(summary: form.repeatSummary)
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
