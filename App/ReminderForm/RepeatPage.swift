import NudgeEngine
import SwiftUI

/// The form's Repeat page, as the mockup's: Never and the six presets, then Custom in its own section,
/// as in Calendar, which opens the Custom page. With a custom rule Custom is checked, with the
/// engine's summary under it.
struct RepeatPage: View {
    @Bindable var form: ReminderForm

    var body: some View {
        let isLocked = form.lockedFields.contains(.repeatRule)
        Form {
            if isLocked { RepeatLockSection() }
            Group {
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
                        CheckmarkLabel(title: Text("Custom", comment: "The Repeat page's row that opens the custom repeat page."),
                                       isChecked: isCustom)
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
            // The reminder may start nudging while the page is open (ticket 13).
            .lockedWhileNudging(isLocked)
        }
        .centeredInReadableColumn()
        .navigationTitle(Text("Repeat", comment: "Title of the reminder form's Repeat page."))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// At the top of the Repeat and Custom pages when the reminder started nudging while they were
/// open: the form's lock note, so the disabled rows say why.
struct RepeatLockSection: View {
    var body: some View {
        Section {
        } header: {
            Label {
                Text(LockNote.hint)
            } icon: {
                LockGlyph()
            }
            .font(.footnote)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .textCase(nil)
        }
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
