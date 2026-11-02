import NudgeEngine
import SwiftUI

/// The filter sheet, the mockup's `remFilterSheet`: Tags as on My Day, then Status and Strength,
/// choosing a draft of what's applied. Apply applies it and closes; Reset clears the draft, which
/// changes nothing until Apply. Cancel, or swiping the sheet down, discards the draft, asking first
/// once it differs from what's applied.
struct RemindersFilterSheetView: View {
    let engine: Engine
    let applied: RemindersSheetFilter
    /// What's in the search field, for the count Apply would show. The sheet leaves it alone.
    let search: String
    let apply: (RemindersSheetFilter) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: RemindersSheetFilter
    @State private var isConfirmingDiscard = false
    @State private var listHeight = NeverShorter()

    init(engine: Engine, applied: RemindersSheetFilter, search: String, apply: @escaping (RemindersSheetFilter) -> Void) {
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
                TagChoiceSections(choice: $draft.tags, rows: sheet.tags) {
                    EmptyView()
                }
                Section {
                    ForEach(RemindersFilter.Status.allCases, id: \.self) { status in
                        CheckmarkRow(title: Text(status.title), isChecked: draft.isChosen(status)) { draft.toggle(status) }
                    }
                } header: {
                    Text("Status", comment: "Reminders' filter sheet: header of the list of statuses.")
                } footer: {
                    Text("Shows reminders with any checked status.", comment: "Reminders' filter sheet: under the list of statuses.")
                }
                Section {
                    ForEach(Strength.formOrder, id: \.self) { strength in
                        CheckmarkRow(title: Text(strength.title), isChecked: draft.isChosen(strength)) { draft.toggle(strength) }
                    }
                } header: {
                    Text("Strength", comment: "Reminders' filter sheet: header of the list of strengths.")
                } footer: {
                    Text("Shows reminders with any checked strength.", comment: "Reminders' filter sheet: under the list of strengths.")
                }
                Section {
                    Button {
                        draft = RemindersSheetFilter()
                    } label: {
                        Text("Reset", comment: "Reminders' filter sheet: clears the choices. Nothing changes until Apply.")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(!sheet.canReset)
                    .listRowBackground(Color.clear)
                    .padding(.bottom, listHeight.extra)
                } header: {
                    Text(sheet.result)
                        .textCase(nil)
                }
            }
            .neverShorter($listHeight)
            .navigationTitle(Text("Filter Reminders", comment: "Title of the Reminders tab's filter sheet."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DiscardingCancelButton(hasChanges: sheet.hasChanges, isConfirming: $isConfirmingDiscard)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        apply(draft)
                        dismiss()
                    } label: {
                        Text("Apply", comment: "Reminders' filter sheet: applies the choices and closes the sheet.")
                    }
                }
            }
        }
        .interactiveDismissDisabled(sheet.hasChanges)
        .onDismissAttempt { isConfirmingDiscard = true }
    }
}

#if DEBUG
#Preview("Filter sheet") {
    RemindersFilterSheetView(engine: .myDayPreview(), applied: RemindersSheetFilter(), search: "") { _ in }
}
#endif
