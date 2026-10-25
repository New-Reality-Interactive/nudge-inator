import NudgeEngine
import SwiftUI

/// The form's Repeat page, as the mockup's: Never and the six presets, then Custom in its own section,
/// as in Calendar, which opens the Custom page. With a custom rule Custom is checked, with the
/// engine's summary under it. It edits a copy of the repeat: its checkmark makes the choice the
/// repeat, and Back drops it (ticket 22). The sheet drops it, as the page can't: pushing Custom
/// over the page makes it disappear too.
struct RepeatPage: View {
    @Bindable var form: ReminderForm
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let isLocked = form.lockedFields.contains(.repeatRule)
        Form {
            if isLocked { RepeatLockSection() }
            Group {
                Section {
                    ForEach(RepeatPreset.allCases, id: \.self) { preset in
                        CheckmarkRow(title: Text(preset.title), isChecked: form.repeatPagePreset == preset) {
                            form.repeatPagePreset = preset
                        }
                    }
                }
                Section {
                    let isCustom = form.repeatPagePreset == nil
                    let label = CheckmarkLabel(title: Text("Custom", comment: "The Repeat page's row that opens the custom repeat page."),
                                               isChecked: isCustom)
                    Group {
                        if isLocked {
                            // Not a link while locked: a disabled link fades its title past the
                            // presets' (device check, ticket 16). Without its chevron, as the
                            // Edit form's locked rows are.
                            label.accessibilityElement(children: .combine)
                        } else {
                            NavigationLink(value: ReminderFormPage.custom) { label }
                        }
                    }
                    .accessibilityAddTraits(isCustom ? .isSelected : [])
                } footer: {
                    if form.repeatPagePreset == nil {
                        RepeatSummarySentence(summary: form.repeatPageSummary)
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
        .toolbar { toolbar(isLocked: isLocked) }
    }

    /// The checkmark, drawn as the form's Save and the Custom page's. Locked while nudging, as the
    /// page's rows are.
    @ToolbarContentBuilder
    private func toolbar(isLocked: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm) {
                form.chooseRepeatPageChoice()
                dismiss()
            } label: {
                Label {
                    Text("Done", comment: "The Repeat page's confirm button (a checkmark): its choice becomes the reminder's repeat.")
                } icon: {
                    Image(systemName: "checkmark")
                }
            }
            .lockedWhileNudging(isLocked)
        }
    }
}

/// At the top of the Repeat and Custom pages when the reminder started nudging while they were
/// open: the form's lock note, so the disabled rows say why.
struct RepeatLockSection: View {
    var body: some View {
        Section {
        } header: {
            Label {
                Text(LockNote.note)
            } icon: {
                LockGlyph()
            }
            .font(.footnote)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .textCase(nil)
        }
    }
}

#if DEBUG
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
#endif
