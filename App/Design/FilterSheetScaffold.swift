import SwiftUI

/// What a filter sheet chooses, applied or as a draft. A new one chooses nothing: what Reset leaves.
protocol FilterSheetChoices: Equatable {
    init()
}

/// What a filter sheet shows for a draft, read from the engine at one moment.
protocol FilterSheetSummary {
    /// How many rows Apply would show, with the search as it is: above Reset.
    var result: LocalizedStringResource { get }
    /// Whether Cancel asks, and a swipe down springs back, before discarding the draft.
    var hasChanges: Bool { get }
    /// Whether Reset has anything to clear.
    var canReset: Bool { get }
}

/// The filter sheet of My Day, Reminders and Tags, around each tab's own sections: a draft of what's
/// applied. Apply applies it and closes; Reset, at the bottom, clears the draft, which changes
/// nothing until Apply. Cancel discards the draft, asking first once it differs from what's
/// applied; a swipe down closes the sheet until then, and after that only springs back. A tap
/// above the sheet does nothing: iOS draws the dimming view as noninteractive (spec #104,
/// Decisions 31, 38 and 57).
struct FilterSheetScaffold<Choices: FilterSheetChoices, Summary: FilterSheetSummary, Sections: View>: View {
    let title: Text
    /// What `summary` says for each draft.
    let summary: (Choices) -> Summary
    let apply: (Choices) -> Void
    @ViewBuilder let sections: (Binding<Choices>, Summary) -> Sections

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Choices
    @State private var listHeight = NeverShorter()

    init(
        title: Text,
        applied: Choices,
        summary: @escaping (Choices) -> Summary,
        apply: @escaping (Choices) -> Void,
        @ViewBuilder sections: @escaping (Binding<Choices>, Summary) -> Sections
    ) {
        self.title = title
        self.summary = summary
        self.apply = apply
        self.sections = sections
        _draft = State(initialValue: applied)
    }

    var body: some View {
        let sheet = summary(draft)
        NavigationStack {
            List {
                sections($draft, sheet)
                resetSection(sheet)
            }
            .neverShorter($listHeight)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DiscardingCancelButton(hasChanges: sheet.hasChanges)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        apply(draft)
                        dismiss()
                    } label: {
                        Label {
                            Text("Apply", comment: "A filter sheet's confirm button (a checkmark), on My Day, Reminders and Tags: applies the choices and closes the sheet.")
                        } icon: {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        // A swipe down mustn't lose the draft; Cancel asks first instead, as the reminder form's does.
        .interactiveDismissDisabled(sheet.hasChanges)
    }

    private func resetSection(_ sheet: Summary) -> some View {
        Section {
            Button {
                draft = Choices()
            } label: {
                Text("Reset", comment: "A filter sheet, on My Day, Reminders and Tags: clears the choices. Nothing changes until Apply.")
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            .disabled(!sheet.canReset)
            .listRowBackground(Color.clear)
            .padding(.bottom, listHeight.extra)
        } header: {
            // A footnote like the sections' footers, not a header's style: it says what Apply does.
            Text(sheet.result)
                .font(.footnote)
                .fontWeight(.regular)
                .textCase(nil)
        }
    }
}
