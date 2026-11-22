import NudgeEngine
import SwiftUI

/// Which schedule sheet is open on the Quiet Hours page: Add Schedule, or a schedule's.
enum QuietHoursSheetKind: Identifiable {
    case add
    case edit(QuietHoursSchedule)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let schedule): schedule.id.uuidString
        }
    }
}

/// Add Schedule and Edit Schedule (#371, the approved Quiet Hours page mockup): Starts and Ends as
/// compact time pills, as the reminder form's Starts row, with a line on when it ends; the days as
/// a checklist in the calendar's week order; and, for a schedule that exists, Delete Schedule,
/// which asks first. Add or Save stays off while the start equals the end or no day is checked,
/// and a red line says why. Cancel with changes asks before discarding, as the other sheets do.
struct QuietHoursScheduleSheet: View {
    let wording: QuietHoursWording
    /// Writes the saved schedule: the model's, or the previews'.
    let save: (QuietHoursSchedule) -> Void
    /// Deletes the edited schedule once the person confirms; nil for a new one.
    let delete: (() -> Void)?

    @State private var draft: QuietHoursScheduleDraft
    @State private var isConfirmingDelete = false
    @Environment(\.dismiss) private var dismiss

    init(kind: QuietHoursSheetKind, wording: QuietHoursWording, save: @escaping (QuietHoursSchedule) -> Void, delete: @escaping (QuietHoursSchedule.ID) -> Void) {
        self.wording = wording
        self.save = save
        switch kind {
        case .add:
            _draft = State(initialValue: QuietHoursScheduleDraft())
            self.delete = nil
        case .edit(let schedule):
            _draft = State(initialValue: QuietHoursScheduleDraft(editing: schedule))
            self.delete = { delete(schedule.id) }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                timesSection
                daysSection
                if delete != nil { deleteSection }
            }
            .centeredInReadableColumn()
            .navigationTitle(Text(draft.isNew ? Self.addTitle : Self.editTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    DiscardingCancelButton(hasChanges: draft.hasChanges)
                }
                ToolbarItem(placement: .confirmationAction) { confirmButton }
            }
            // A reason that appears is mentioned, as an error under a field is, since focus isn't on it.
            .onChange(of: draft.problems) { old, new in
                for problem in new where !old.contains(problem) {
                    VoiceOverAnnouncement.mention(problem.message)
                }
            }
        }
        // A swipe down mustn't lose a change; Cancel asks first instead.
        .interactiveDismissDisabled(draft.hasChanges)
    }

    private var timesSection: some View {
        Section {
            DatePicker(selection: time(\.start), displayedComponents: .hourAndMinute) {
                Text("Starts", comment: "Add Schedule and Edit Schedule (quiet hours): the time the schedule starts.")
            }
            DatePicker(selection: time(\.end), displayedComponents: .hourAndMinute) {
                Text("Ends", comment: "Add Schedule and Edit Schedule (quiet hours): the time the schedule ends, on the same day or the next.")
            }
        } footer: {
            if draft.problems.contains(.startEqualsEnd) {
                problemText(.startEqualsEnd)
            } else if let ends = wording.ends(draft) {
                Text(ends)
            }
        }
    }

    private var daysSection: some View {
        Section {
            ForEach(wording.weekOrder, id: \.self) { day in
                CheckmarkRow(title: Text(wording.date(of: day), format: wording.dayName), isChecked: draft.days.contains(day)) {
                    draft.toggle(day)
                }
                // Each day turns on and off on its own, as the Custom repeat page's days do.
                .accessibilityAddTraits(.isToggle)
            }
        } header: {
            Text("Days", comment: "Add Schedule and Edit Schedule (quiet hours): header of the days of the week the schedule starts on.")
        } footer: {
            VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                if draft.problems.contains(.noDays) { problemText(.noDays) }
                Text("Each day is a day the schedule starts on, so Sunday at 10 PM to 7 AM runs into Monday morning.",
                     comment: "Add Schedule and Edit Schedule (quiet hours): under the days, what a checked day means.")
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label {
                    Text("Delete Schedule", comment: "Edit Schedule (quiet hours): the button that asks before deleting the schedule.")
                } icon: {
                    Image(systemName: "trash")
                }
            }
            // The system's confirmation dialog with its title showing, as Settings' other deletions ask (#286).
            .confirmationDialog(
                Text("Delete This Schedule?", comment: "Edit Schedule (quiet hours): title of the question that asks before deleting the schedule."),
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    delete?()
                    dismiss()
                } label: {
                    Text("Delete Schedule", comment: "Edit Schedule (quiet hours): confirms deleting the schedule.")
                }
                Button(role: .cancel) {
                } label: {
                    Text("Cancel", comment: "Keeps the quiet hours schedule instead of deleting it.")
                }
            } message: {
                deleteMessage
            }
        }
    }

    /// The schedule as it was saved, not as the sheet has changed it, since that is what goes.
    @ViewBuilder private var deleteMessage: some View {
        if let saved = draft.saved {
            Text("\(Text(wording.range(saved))) · \(Text(wording.days(saved))). Nudges in it will arrive again.",
                 comment: "Edit Schedule (quiet hours): the message of the question that asks before deleting the schedule. 1: its times, such as \"10:00 PM–7:00 AM\". 2: its days, such as \"Every day\".")
        }
    }

    private var confirmButton: some View {
        let name = draft.isNew
            ? Text("Add", comment: "Add Schedule (quiet hours): the confirm button (a checkmark) that adds the schedule.")
            : Text("Save", comment: "Edit Schedule (quiet hours): the confirm button (a checkmark) that saves the changes.")
        return Button(role: .confirm) {
            guard let schedule = draft.schedule else { return }
            save(schedule)
            dismiss()
        } label: {
            Label {
                name
            } icon: {
                Image(systemName: "checkmark")
            }
        }
        .disabled(draft.schedule == nil)
        .dimmedBecause(draft.problems.first?.message, label: name)
    }

    private func problemText(_ problem: QuietHoursScheduleDraft.Problem) -> some View {
        Text(problem.message)
            .foregroundStyle(Color.negative)
    }

    /// A time pill's date for the draft's `field`, written back as its hour and minute.
    private func time(_ field: WritableKeyPath<QuietHoursScheduleDraft, TimeOfDay>) -> Binding<Date> {
        Binding {
            wording.date(of: draft[keyPath: field])
        } set: { date in
            if let time = wording.time(of: date) { draft[keyPath: field] = time }
        }
    }

    /// The sheet's title, and the Quiet Hours page's button that opens it.
    static let addTitle = LocalizedStringResource("Add Schedule", comment: "Title of the sheet that adds a quiet hours schedule, and the Quiet Hours page's button that opens it.")
    private static let editTitle = LocalizedStringResource("Edit Schedule", comment: "Title of the sheet that changes or deletes a quiet hours schedule.")
}

#if DEBUG
#Preview("Add") {
    QuietHoursScheduleSheet(kind: .add, wording: QuietHoursWording(calendar: .autoupdatingCurrent), save: { _ in }, delete: { _ in })
}

#Preview("Edit, largest text") {
    QuietHoursScheduleSheet(
        kind: .edit(try! QuietHoursSchedule(start: TimeOfDay(hour: 23), end: TimeOfDay(hour: 8), days: [.friday, .saturday])),
        wording: QuietHoursWording(calendar: .autoupdatingCurrent), save: { _ in }, delete: { _ in }
    )
    .dynamicTypeSize(.accessibility5)
}
#endif
