import NudgeEngine
import os
import SwiftUI

/// A sent reminder's details (ticket 201, the mockup's `viewSent`), pushed from a Sent row: the hero
/// with its strength, Sent To with each person and how their copy is going, the Schedule, and
/// Delete. Edit opens the sender's form, whose Save goes to every copy. Under Sent To, each person
/// whose copy shares a repeating reminder's status has their last 7 days in words (ticket 207).
/// It reads the sharing store again at every change and every minute.
struct SentReminderDetailsView: View {
    let id: Reminder.ID

    @Environment(AppModel.self) private var model: AppModel?
    @Environment(\.dismiss) private var dismiss
    @State private var form: ReminderForm?
    /// What was on screen when Delete was confirmed, so the screen doesn't flash "not found" while
    /// it slides away.
    @State private var deleted: SentReminderDetails?
    /// Set when the store wouldn't keep a Delete: the reminder stays, and the screen says so.
    @State private var isShowingCouldntDelete = false

    var body: some View {
        TimelineView(.everyMinute) { _ in
            if let details = deleted ?? current {
                loaded(details)
            } else {
                NotFoundView()
            }
        }
        .sheet(item: $form) { form in
            ReminderFormSheet(form: form)
        }
        .alert(
            Text("Couldn't Delete the Reminder", comment: "A sent reminder's details: title of the message shown when Delete couldn't be kept, so nothing was canceled."),
            isPresented: $isShowingCouldntDelete
        ) {
            Button {
            } label: {
                Text("OK", comment: "A sent reminder's details: dismisses the message that the reminder couldn't be deleted.")
            }
        } message: {
            Text("Nothing was canceled. Try again.", comment: "A sent reminder's details: under Couldn't Delete the Reminder.")
        }
    }

    private var current: SentReminderDetails? {
        model.flatMap { model in
            model.sharing.flatMap { SentReminderDetails(engine: model.engine, sharing: $0.data, id: id) }
        }
    }

    private func loaded(_ details: SentReminderDetails) -> some View {
        SentDetailsList(details: details, isEnabled: deleted == nil) {
            delete(details)
        }
        // The bar holds only its button: the hero carries the title.
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openEdit(details)
                } label: {
                    Text("Edit", comment: "Reminder details: the toolbar button that opens the Edit Reminder form.")
                }
                .accessibilityLabel(Text("Edit \(details.title)", comment: "VoiceOver label of the reminder details' Edit button. The placeholder is the reminder's title."))
                .disabled(model == nil || deleted != nil)
            }
        }
    }

    private func openEdit(_ details: SentReminderDetails) {
        guard let model else { return }
        form = ReminderForm(engine: { model.engine }, editingSent: details.reminder, now: { .now })
    }

    /// A store that won't keep the delete leaves the reminder as it was, on screen and on every
    /// copy, so the screen stays and says so.
    private func delete(_ details: SentReminderDetails) {
        do {
            try model?.deleteSent(id)
        } catch {
            AppModel.logger.error("A sent reminder couldn't be deleted: \(error, privacy: .public)")
            isShowingCouldntDelete = true
            return
        }
        deleted = details
        dismiss()
    }
}

/// The list: hero, Sent To, each person's last 7 days, Schedule, and Delete.
private struct SentDetailsList: View {
    let details: SentReminderDetails
    let isEnabled: Bool
    let delete: () -> Void

    @State private var isConfirmingDelete = false

    var body: some View {
        List {
            Section {
                SentDetailsHero(details: details)
            }
            Section {
                ForEach(details.recipients) { recipient in
                    // As the mockup's `viewSent`: the detail line under the name, the label trailing.
                    LabeledContent {
                        SentTrailingLabel(trailing: recipient.trailing)
                    } label: {
                        Text(verbatim: recipient.name)
                        if let line = recipient.detailLine {
                            Text(line)
                        }
                    }
                }
            } header: {
                Text("Sent To", comment: "A sent reminder's details: section header above the people it was sent to.")
            }
            ForEach(details.recipients) { recipient in
                if let history = recipient.history {
                    Section {
                        // As the #207 change mockup's `viewSent`: newest first, the day leading, its glyph and
                        // status trailing.
                        ForEach(history.newestFirst) { day in
                            LabeledContent {
                                SentHistoryDayLabel(day: day)
                            } label: {
                                Text(verbatim: day.label)
                            }
                        }
                    } header: {
                        Text(recipient.historyHeader)
                    }
                }
            }
            Section {
                ScheduleSummaryRows(repeats: details.repeats, next: details.next, pace: details.pace, breaksThroughFocus: details.breaksThroughFocus)
            } header: {
                Text("Schedule", comment: "Reminder details: section header for when and how the reminder nudges.")
            }
            Section {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label {
                        Text("Delete Reminder", comment: "Reminder details: opens the question that asks before deleting the reminder.")
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
                .deleteReminderConfirmation(title: details.title, kind: .sent, isPresented: $isConfirmingDelete, confirm: delete)
            } footer: {
                Text("This doesn't nudge you. Deleting cancels it on everyone's iPhone, with a note.", comment: "A sent reminder's details: under Delete Reminder.")
            }
        }
        .disabled(!isEnabled)
        .centeredInReadableColumn()
    }
}

/// The title, notes and strength badge. A sent reminder has no status of its own: each person's copy
/// has one.
private struct SentDetailsHero: View {
    let details: SentReminderDetails

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s2) {
            Text(verbatim: details.title)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            if !details.notes.isEmpty {
                Text(verbatim: details.notes)
                    .font(.body)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
            StrengthBadge(strength: details.strength)
        }
        .padding(.vertical, Design.Spacing.s1)
    }
}

#if DEBUG
private extension SentReminderDetails {
    /// The pills sent to Riley, delivered, and Sam, not yet.
    static var preview: SentReminderDetails {
        let pills = Reminder(title: "Take the pills", notes: "Two with water", dueTime: .now.addingTimeInterval(3600), repeatRule: .everyDay, strength: .firm)
        let riley = SharingConnection(id: UUID(), name: "Riley Park", state: .connected)
        let sam = SharingConnection(id: UUID(), name: "Sam Rivera", state: .connected)
        var sharing = SharingData(connections: [riley, sam])
        sharing.sentReminders = [SentReminder(reminder: pills, revision: 0)]
        sharing.sentCopies = [
            SentCopy(connectionID: riley.id, reminderID: pills.id, createdAt: .now, receipt: .started, statusRecord: nil, waitingToSync: false),
            SentCopy(connectionID: sam.id, reminderID: pills.id, createdAt: .now, receipt: .notDelivered, statusRecord: nil, waitingToSync: false),
        ]
        return SentReminderDetails(engine: .myDayPreview(), sharing: sharing, id: pills.id)!
    }
}

#Preview("Light") {
    NavigationStack { SentDetailsList(details: .preview, isEnabled: true) {} }
}

#Preview("Dark") {
    NavigationStack { SentDetailsList(details: .preview, isEnabled: true) {} }
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    NavigationStack { SentDetailsList(details: .preview, isEnabled: true) {} }
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
