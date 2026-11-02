import NudgeEngine
import SwiftUI

/// The filter sheet, the mockup's `remFilterSheet`: Tags as on My Day, then Status and Strength,
/// choosing a draft of what's applied. Apply applies it and closes; Reset clears the draft, which
/// changes nothing until Apply. Cancel discards the draft, asking first once it differs from what's
/// applied; a swipe down closes the sheet until then, and after that only springs back.
struct RemindersFilterSheetView: View {
    let engine: Engine
    let applied: RemindersFilterChoices
    /// What's in the search field, for the count Apply would show. The sheet leaves it alone.
    let search: String
    let apply: (RemindersFilterChoices) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: RemindersFilterChoices
    @State private var listHeight = NeverShorter()

    init(engine: Engine, applied: RemindersFilterChoices, search: String, apply: @escaping (RemindersFilterChoices) -> Void) {
        self.engine = engine
        self.applied = applied
        self.search = search
        self.apply = apply
        _draft = State(initialValue: applied)
    }

    var body: some View {
        let sheet = RemindersFilterSheet(engine: engine, draft: draft, applied: applied, search: search)
        NavigationStack {
            List {
                TagChoiceSections(choice: $draft.tags, sheet: sheet.tags) {
                    EmptyView()
                }
                statusSection
                strengthSection
                resetSection(sheet)
            }
            .neverShorter($listHeight)
            .navigationTitle(Text("Filter Reminders", comment: "Title of the Reminders tab's filter sheet."))
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
                            Text("Apply", comment: "Reminders' filter sheet's confirm button (a checkmark): applies the choices and closes the sheet.")
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

    private var statusSection: some View {
        Section {
            ForEach(RemindersFilter.Status.allCases, id: \.self) { status in
                CheckmarkRow(title: Text(status.title), isChecked: draft.isChosen(status)) { draft.toggle(status) }
            }
        } header: {
            Text("Status", comment: "Reminders' filter sheet: header of the list of statuses.")
        } footer: {
            Text("Shows reminders with any checked status.", comment: "Reminders' filter sheet: under the list of statuses.")
        }
    }

    private var strengthSection: some View {
        Section {
            ForEach(Strength.formOrder, id: \.self) { strength in
                CheckmarkRow(title: Text(strength.title), isChecked: draft.isChosen(strength)) { draft.toggle(strength) }
            }
        } header: {
            Text("Strength", comment: "Reminders' filter sheet: header of the list of strengths.")
        } footer: {
            Text("Shows reminders with any checked strength.", comment: "Reminders' filter sheet: under the list of strengths.")
        }
    }

    private func resetSection(_ sheet: RemindersFilterSheet) -> some View {
        Section {
            Button {
                draft = RemindersFilterChoices()
            } label: {
                Text("Reset", comment: "Reminders' filter sheet: clears the choices. Nothing changes until Apply.")
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

#if DEBUG
#Preview("Filter sheet") {
    RemindersFilterSheetView(engine: .myDayPreview(), applied: RemindersFilterChoices(), search: "") { _ in }
}
#endif
