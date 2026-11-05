import NudgeEngine
import SwiftUI

/// The filter sheet, the mockup's `remFilterSheet`: Tags as on My Day, then Status, Strength and Due
/// Date, choosing a draft of what's applied. The bar, Apply, Reset and the prompt before discarding
/// are `FilterSheetScaffold`'s, shared with Tags.
struct RemindersFilterSheetView: View {
    let engine: Engine
    let applied: RemindersFilterChoices
    /// What's in the search field, for the count Apply would show. The sheet leaves it alone.
    let search: String
    let apply: (RemindersFilterChoices) -> Void

    var body: some View {
        FilterSheetScaffold(
            title: Text("Filter Reminders", comment: "Title of the Reminders tab's filter sheet."),
            applied: applied,
            summary: { RemindersFilterSheet(engine: engine, draft: $0, applied: applied, search: search) },
            apply: apply
        ) { draft, sheet in
            TagChoiceSections(choice: draft.tags, sheet: sheet.tags) {
                EmptyView()
            }
            statusSection(draft)
            strengthSection(draft)
            dueDateSection(draft)
        }
    }

    private func statusSection(_ draft: Binding<RemindersFilterChoices>) -> some View {
        Section {
            ForEach(RemindersFilter.Status.allCases, id: \.self) { status in
                CheckmarkRow(title: Text(status.title), isChecked: draft.wrappedValue.isChosen(status)) { draft.wrappedValue.toggle(status) }
            }
        } header: {
            Text("Status", comment: "Reminders' filter sheet: header of the list of statuses.")
        } footer: {
            Text("Shows reminders with any checked status.", comment: "Reminders' filter sheet: under the list of statuses.")
        }
    }

    private func strengthSection(_ draft: Binding<RemindersFilterChoices>) -> some View {
        Section {
            ForEach(Strength.formOrder, id: \.self) { strength in
                CheckmarkRow(title: Text(strength.title), isChecked: draft.wrappedValue.isChosen(strength)) { draft.wrappedValue.toggle(strength) }
            }
        } header: {
            Text("Strength", comment: "Reminders' filter sheet: header of the list of strengths.")
        } footer: {
            Text("Shows reminders with any checked strength.", comment: "Reminders' filter sheet: under the list of strengths.")
        }
    }

    private func dueDateSection(_ draft: Binding<RemindersFilterChoices>) -> some View {
        Section {
            DueDateRow(
                title: Text("From", comment: "Reminders' filter sheet: the switch and date picker for the first day a reminder may be due."),
                engine: engine,
                day: Binding { draft.wrappedValue.dueFrom } set: { draft.wrappedValue.setDueFrom($0) },
                range: .distantPast...(draft.wrappedValue.dueTo.map(engine.startOfDay) ?? .distantFuture)
            )
            DueDateRow(
                title: Text("To", comment: "Reminders' filter sheet: the switch and date picker for the last day a reminder may be due."),
                engine: engine,
                day: Binding { draft.wrappedValue.dueTo } set: { draft.wrappedValue.setDueTo($0) },
                range: (draft.wrappedValue.dueFrom.map(engine.startOfDay) ?? .distantPast)...(.distantFuture)
            )
        } header: {
            Text("Due Date", comment: "Reminders' filter sheet: header of the first and last day a reminder may be due.")
        } footer: {
            Text("Both days are included. A reminder with nothing more coming is found by its last due date.", comment: "Reminders' filter sheet: under the first and last day a reminder may be due.")
        }
    }
}

/// One end of the Due Date range: a switch, and while it's on a date picker beside it, as the mockup's
/// `dateRow` draws them. At the accessibility text sizes the picker goes under the switch, since the
/// row is too narrow for both. A switch turned on starts at today.
private struct DueDateRow: View {
    let title: Text
    let engine: Engine
    @Binding var day: CalendarDay?
    let range: ClosedRange<Date>

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading) {
                toggle
                picker
            }
        } else {
            HStack {
                // The switch reads the title to VoiceOver.
                title.accessibilityHidden(true)
                Spacer()
                picker
                // VoiceOver reads the switch first, whatever the row's order: focus stays on it when
                // it turns on, so the picker it brings is the next swipe rather than the one behind.
                toggle.labelsHidden().accessibilitySortPriority(1)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var toggle: some View {
        Toggle(isOn: Binding { day != nil } set: { day = $0 ? engine.today : nil }) { title }
    }

    @ViewBuilder private var picker: some View {
        if let day {
            DatePicker(
                selection: Binding { engine.startOfDay(day) } set: { self.day = engine.calendarDay(of: $0) },
                in: range,
                displayedComponents: .date
            ) {
                title
            }
            .labelsHidden()
        }
    }
}

#if DEBUG
#Preview("Filter sheet") {
    RemindersFilterSheetView(engine: .myDayPreview(), applied: RemindersFilterChoices(), search: "") { _ in }
}

#Preview("Due Date row") {
    @Previewable @State var on: CalendarDay? = CalendarDay(year: 2026, month: 10, day: 20)
    @Previewable @State var off: CalendarDay?
    List {
        DueDateRow(title: Text(verbatim: "On"), engine: .myDayPreview(), day: $on, range: .distantPast ... .distantFuture)
        DueDateRow(title: Text(verbatim: "Off"), engine: .myDayPreview(), day: $off, range: .distantPast ... .distantFuture)
    }
}
#endif
