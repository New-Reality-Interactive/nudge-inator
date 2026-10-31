import NudgeEngine
import SwiftUI

extension View {
    /// What a stack shows for a pushed `OpenedReminder`. Add it to the stack's root, outside any
    /// `List`, so every stack that pushes a reminder pushes the same screen.
    func reminderDetailsDestination() -> some View {
        navigationDestination(for: OpenedReminder.self) { ReminderDetailsView(id: $0.id) }
    }
}

/// A reminder's details, as the mockup's `viewRem` less its History (out of scope): the hero, the
/// Nudging Now card with Done, Schedule, How It Nudges, Pause or Resume, and Delete. It reads the
/// engine again at every change and every minute, so it follows a Done from a notification while
/// it is open.
struct ReminderDetailsView: View {
    let id: Reminder.ID
    /// What previews show, since they have no app model.
    var preview: ReminderDetails?

    @Environment(AppModel.self) private var model: AppModel?
    @Environment(\.dismiss) private var dismiss
    @State private var form: ReminderForm?
    /// The reminder as it was when "Choose Time" opened Edit, so Save can resume it. `nil` for
    /// any other Edit.
    @State private var resumeBaseline: Reminder?
    @State private var isAskingForNewTime = false
    /// What was on screen when Delete was confirmed. The reminder is gone from the engine at
    /// once, but the screen is still sliding away, and shouldn't flash "not found" while it does.
    @State private var deleted: ReminderDetails?

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let details = deleted ?? current {
                loaded(details, now: context.date)
            } else {
                NotFoundView()
            }
        }
        .sheet(item: $form, onDismiss: resumeAfterEdit) { form in
            ReminderFormSheet(form: form)
        }
    }

    private func loaded(_ details: ReminderDetails, now: Date) -> some View {
        DetailsList(
            details: details,
            now: now,
            isEnabled: deleted == nil,
            markDone: { model?.markDone(id) },
            togglePause: { togglePause(details) },
            delete: {
                deleted = details
                model?.delete(id)
                dismiss()
            }
        )
        // The bar holds only its buttons: the hero carries the title.
        .navigationTitle(Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openEdit) {
                    Text("Edit", comment: "Reminder details: the toolbar button that opens the Edit Reminder form.")
                }
                .accessibilityLabel(Text("Edit \(details.title)", comment: "VoiceOver label of the reminder details' Edit button. The placeholder is the reminder's title."))
                .disabled(model == nil || deleted != nil)
            }
        }
        .newTimeAlert(isPresented: $isAskingForNewTime, title: details.title) {
            resumeBaseline = details.reminder
            openEdit()
        }
    }

    private var current: ReminderDetails? {
        model.flatMap { ReminderDetails(engine: $0.engine, id: id) } ?? preview
    }

    private func openEdit() {
        guard let model else { return }
        form = ReminderForm(engine: { model.engine }, editing: id, now: { .now })
    }

    /// Pause, or Resume, which asks for a new time when there is none left to resume at.
    private func togglePause(_ details: ReminderDetails) {
        guard let model else { return }
        switch details.pauseAction {
        case .pause: model.pause(id)
        case .resume:
            do {
                try model.resume(id)
            } catch {
                isAskingForNewTime = true
            }
        case nil: break
        }
    }

    /// After "Choose Time", Save resumes the reminder, or asks again if the Edit left no time.
    /// Cancel changed nothing, so nothing happens.
    private func resumeAfterEdit() {
        guard let before = resumeBaseline else { return }
        resumeBaseline = nil
        if model?.resumeAfterEdit(of: before) == .needsNewDueTime {
            isAskingForNewTime = true
        }
    }
}

extension View {
    /// The alert shown when Resume is turned down for want of a time: Cancel, or "Choose Time",
    /// which opens Edit.
    fileprivate func newTimeAlert(isPresented: Binding<Bool>, title: String, chooseTime: @escaping () -> Void) -> some View {
        alert(
            Text("Choose a New Time", comment: "Alert title: Resume was turned down because the reminder has no time left."),
            isPresented: isPresented
        ) {
            Button(role: .cancel) {
            } label: {
                Text("Cancel", comment: "Closes the alert without choosing a new time.")
            }
            Button(action: chooseTime) {
                Text("Choose Time", comment: "Opens the Edit Reminder form to choose a new time, so the reminder can resume.")
            }
        } message: {
            Text("“\(title)” was due while it was paused. Choose a new time to resume it.", comment: "Alert message: why Resume needs a new time. The placeholder is the reminder's title.")
        }
    }
}

/// The list: hero, Nudging Now, Schedule, How It Nudges, and the Pause and Delete actions.
private struct DetailsList: View {
    let details: ReminderDetails
    let now: Date
    let isEnabled: Bool
    let markDone: () -> Void
    let togglePause: () -> Void
    let delete: () -> Void

    /// The card Done was chosen on with VoiceOver, kept until VoiceOver moves on.
    @State private var heldCard: NudgeCard?

    var body: some View {
        List {
            Section {
                DetailsHero(details: details)
            }
            if let card = details.card ?? heldCard {
                Section {
                    NudgeCardView(card: card, now: now, markDone: markDone, isDoneHeld: heldBinding(for: card))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Nudging Now", comment: "Reminder details: section header above the card of a reminder that is nudging.")
                }
            }
            Section {
                ScheduleRows(details: details)
            } header: {
                Text("Schedule", comment: "Reminder details: section header for when and how the reminder nudges.")
            } footer: {
                if details.showsLockNote {
                    Label {
                        Text("Start, repeat, strength, pace and Break Through Focus are locked while it's nudging. Mark it Done or pause it to change them.",
                             comment: "Reminder details: under Schedule while the reminder is nudging, why five fields can't be edited.")
                    } icon: {
                        LockGlyph()
                    }
                }
            }
            HowItNudgesSection(howItNudges: details.howItNudges)
            Section {
                if let action = details.pauseAction {
                    Button(action: togglePause) {
                        switch action {
                        case .pause:
                            Label {
                                Text("Pause Reminder", comment: "Reminder details: stops the reminder's nudging until it is resumed.")
                            } icon: {
                                Image(systemName: "pause")
                            }
                        case .resume:
                            Label {
                                Text("Resume Reminder", comment: "Reminder details: brings a paused reminder back at its next time.")
                            } icon: {
                                Image(systemName: "play")
                            }
                        }
                    }
                }
                DeleteButton(title: details.title, confirm: delete)
            } footer: {
                if details.pauseAction == .pause {
                    Text("Pausing stops the nudging. Anything due while it's paused is skipped, not missed.",
                         comment: "Reminder details: under Pause Reminder.")
                }
            }
        }
        .disabled(!isEnabled)
        .centeredInReadableColumn()
    }

    private func heldBinding(for card: NudgeCard) -> Binding<Bool> {
        Binding {
            heldCard != nil
        } set: { isHeld in
            heldCard = isHeld ? card : nil
        }
    }
}

/// Delete Reminder, which asks first. The dialog hangs on the button, since iOS 26 draws it as a
/// popover pointing at the view it is attached to.
private struct DeleteButton: View {
    let title: String
    let confirm: () -> Void
    @State private var isConfirming = false

    var body: some View {
        Button(role: .destructive) {
            isConfirming = true
        } label: {
            Label {
                Text("Delete Reminder", comment: "Reminder details: opens the question that asks before deleting the reminder.")
            } icon: {
                Image(systemName: "trash")
            }
        }
        .deleteReminderConfirmation(title: title, isPresented: $isConfirming, confirm: confirm)
    }
}

/// The title, notes, strength badge, status and tags.
private struct DetailsHero: View {
    let details: ReminderDetails
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Design.Spacing.s2))
                : AnyLayout(HStackLayout(spacing: Design.Spacing.s3))
            layout {
                StrengthBadge(strength: details.strength)
                ReminderStatusLabel(status: details.status)
            }
            if let tagsLabel = details.tagsVoiceOverLabel {
                // Tokens, joined by spaces: they are not a sentence. Ticket 29 makes them buttons.
                Text(verbatim: details.tags.joined(separator: " "))
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .accessibilityLabel(Text(tagsLabel))
            }
        }
        .padding(.vertical, Design.Spacing.s1)
    }
}

/// Repeats, Next, Pace, Break Through Focus, and how the latest occurrence closed.
private struct ScheduleRows: View {
    let details: ReminderDetails

    var body: some View {
        LabeledContent {
            Text(verbatim: details.repeats)
        } label: {
            Text("Repeats", comment: "Reminder details, Schedule: how often the reminder comes due.")
        }
        LabeledContent {
            next
        } label: {
            Text("Next", comment: "Reminder details, Schedule: when the reminder is next due.")
        }
        LabeledContent {
            Text(details.pace.title)
        } label: {
            Text("Pace", comment: "Reminder details, Schedule: how the waits between the reminder's nudges are spaced.")
        }
        LabeledContent {
            // On for Relentless, which always breaks through Focus (ADR 0004).
            details.reminder.breaksThroughFocus
                ? Text("On", comment: "Reminder details: Break Through Focus is on.")
                : Text("Off", comment: "Reminder details: Break Through Focus is off.")
        } label: {
            Text("Break Through Focus", comment: "Reminder details, Schedule: the per-reminder switch that sends nudges as alarms.")
        }
        if let last = details.lastOccurrence {
            LastOccurrenceRow(last: last)
        }
    }

    @ViewBuilder private var next: some View {
        switch details.next {
        case .at(let day, let time):
            Text("\(day) at \(time)", comment: "Reminder details, Schedule: the next due time. 1: \"Today\", \"Tomorrow\" or a short date. 2: the time, such as \"8:00 AM\".")
        case .paused:
            Text("Paused", comment: "Reminder details, Schedule: the reminder is paused, so nothing is next.")
        case .none:
            Text("None", comment: "Reminder details, Schedule: nothing is left to come.")
        }
    }
}

/// How the latest occurrence closed, with when. Its own row rather than a `LabeledContent`, whose
/// two-line trailing content left a blank band under the section.
private struct LastOccurrenceRow: View {
    let last: ReminderDetails.LastOccurrence
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Design.Spacing.s1))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        layout {
            Text("Last occurrence", comment: "Reminder details, Schedule: how the latest occurrence closed.")
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: Design.Spacing.s3) }
            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: Design.Spacing.line) {
                StatusLabel(state: last.state)
                Text("\(last.day), \(last.time)", comment: "Reminder details, Schedule: when the latest occurrence closed. 1: \"Today\", \"Yesterday\" or a short date. 2: the time, such as \"9:40 AM\".")
                    .font(.footnote)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// What a pushed reminder shows when the engine no longer holds it.
private struct NotFoundView: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                Text("Reminder Not Found", comment: "Reminder details: title when the reminder isn't there.")
            } icon: {
                Image(systemName: "questionmark.circle")
            }
        } description: {
            Text("It may have been deleted.", comment: "Reminder details: under \"Reminder Not Found\".")
        }
    }
}
