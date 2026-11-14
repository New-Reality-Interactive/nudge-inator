import NudgeEngine
import SwiftUI

/// The Filter Sent sheet (ticket 329), the mockup's `sentFilterSheet`: People, Status, Strength and
/// Due Date, with no Tags, choosing a draft of what's applied. The bar, Apply, Reset and the prompt
/// before discarding are `FilterSheetScaffold`'s, as on Mine's sheet.
struct SentFilterSheetView: View {
    let engine: Engine
    let sharing: SharingData
    let applied: SentFilterChoices
    /// What's in Sent's search field, for the count Apply would show. The sheet leaves it alone.
    let search: String
    let apply: (SentFilterChoices) -> Void

    var body: some View {
        FilterSheetScaffold(
            title: Text("Filter Sent", comment: "Title of the filter sheet on the Reminders tab's Sent view."),
            applied: applied,
            summary: { SentFilterSheet(engine: engine, sharing: sharing, draft: $0, applied: applied, search: search) },
            apply: apply
        ) { draft, sheet in
            peopleSection(draft, sheet: sheet)
            StatusFilterSection(
                statuses: SentFilterChoices.Status.allCases,
                title: \.title,
                isChosen: draft.wrappedValue.isChosen,
                toggle: { draft.wrappedValue.toggle($0) },
                footer: Text("Shows each person's copy with any checked status.", comment: "Sent's filter sheet: under the list of statuses. Each person has their own copy of a sent reminder, with its own status.")
            )
            StrengthFilterSection(isChosen: draft.wrappedValue.isChosen) { draft.wrappedValue.toggle($0) }
            DueDateFilterSection(
                engine: engine,
                from: Binding { draft.wrappedValue.dueFrom } set: { draft.wrappedValue.setDueFrom($0) },
                to: Binding { draft.wrappedValue.dueTo } set: { draft.wrappedValue.setDueTo($0) },
                footer: Text("Both days are included.", comment: "Sent's filter sheet: under the first and last day a sent reminder may be due, by the next due time its row shows.")
            )
        }
    }

    private func peopleSection(_ draft: Binding<SentFilterChoices>, sheet: SentFilterSheet) -> some View {
        Section {
            ForEach(sheet.people) { person in
                CheckmarkRow(title: Text(verbatim: person.name), isChecked: person.isChosen) { draft.wrappedValue.toggle(person: person.id) }
            }
        } header: {
            Text("People", comment: "Sent's filter sheet: header of the list of connected people.")
        } footer: {
            Text("Shows what you sent to any checked person.", comment: "Sent's filter sheet: under the list of connected people.")
        }
    }
}

extension SentFilterChoices.Status {
    /// The word a Sent row shows for it, or the mockup's name for what the row shows instead.
    var title: LocalizedStringResource {
        switch self {
        case .reported(let reported): reported.name
        case .waitingToAccept: LocalizedStringResource("Waiting to accept", comment: "Sent's filter sheet: the status choice for copies that wait on the person's iPhone for them to accept (Ask me first).")
        case .waitingToSync: LocalizedStringResource.waitingToSync
        case .notSharing: LocalizedStringResource("Not sharing", comment: "Sent's filter sheet: the status choice for copies whose status the person keeps from the sender: their status sharing is off, or they chose not to share this one.")
        }
    }
}

#if DEBUG
#Preview("Filter Sent") {
    SentFilterSheetView(engine: .myDayPreview(), sharing: SharingData(connections: [
        SharingConnection(id: UUID(), name: "Riley Park", state: .connected),
        SharingConnection(id: UUID(), name: "Sam Rivera", state: .connected),
    ]), applied: SentFilterChoices(), search: "") { _ in }
}
#endif
