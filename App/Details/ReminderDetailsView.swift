import NudgeEngine
import os
import SwiftUI

extension View {
    /// What a stack shows for a pushed `OpenedReminder`. Add it to the stack's root, outside any
    /// `List`, so every stack that pushes a reminder pushes the same screen.
    func reminderDetailsDestination() -> some View {
        navigationDestination(for: OpenedReminder.self) { ReminderDetailsView(id: $0.id) }
    }
}

/// A reminder's details, as the mockup's `viewRem` less its History (out of scope): the hero, the
/// Nudging Now card with Done, Schedule, How It Nudges, Pause or Resume, and Delete. A received
/// reminder's (the mockup's `viewReceived`, ticket 200) adds who sent it and its strength in words,
/// says its sender owns the schedule, offers "Don't share this one", and has Remove for Delete; one
/// waiting to be accepted (ticket 203) has the waiting note, Accept and Remove instead of Pause. It
/// reads the engine again at every change and every minute, so it follows a Done from a
/// notification while it is open.
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
            accept: { model?.accept(id) },
            setNotSharing: { notSharing in
                // A store that won't keep it leaves the switch as it was: it shows what's kept.
                do {
                    try model?.setNotSharing(notSharing, for: id)
                } catch {
                    AppModel.logger.error("Don't share this one couldn't be kept: \(error, privacy: .public)")
                }
            },
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
            // A canceled copy has nothing to edit, not even tags (the mockup's `viewReceived`).
            if !details.isCanceled {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: openEdit) {
                        Text("Edit", comment: "Reminder details: the toolbar button that opens the Edit Reminder form.")
                    }
                    .accessibilityLabel(details.received == nil
                        ? Text("Edit \(details.title)", comment: "VoiceOver label of the reminder details' Edit button. The placeholder is the reminder's title.")
                        : Text("Edit tags of \(details.title)", comment: "VoiceOver label of a received reminder's Edit button on its details, whose form changes only its tags. The placeholder is the reminder's title."))
                    .disabled(model == nil || deleted != nil)
                }
            }
        }
        .newTimeAlert(isPresented: $isAskingForNewTime, title: details.title) {
            resumeBaseline = details.reminder
            openEdit()
        }
    }

    private var current: ReminderDetails? {
        model.flatMap { ReminderDetails(engine: $0.engine, id: id, sharing: $0.sharing?.data ?? SharingData()) } ?? preview
    }

    private func openEdit() {
        guard let model else { return }
        form = ReminderForm(engine: { model.engine }, editing: id, now: { .now }, senders: model.senders)
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
    /// Accept on a received reminder waiting to be accepted (ticket 203).
    let accept: () -> Void
    let setNotSharing: (Bool) -> Void
    let delete: () -> Void

    /// The card Done was chosen on with VoiceOver, kept until VoiceOver moves on.
    @State private var heldCard: NudgeCard?

    var body: some View {
        List {
            Section {
                DetailsHero(details: details)
            }
            if details.isCanceled, let received = details.received {
                CanceledSection(senderName: received.senderName)
            }
            if let note = details.received?.changeNote {
                ChangeNoteSection(note: note)
            }
            if details.isWaiting {
                WaitingSection(title: details.title, accept: accept, remove: delete)
            }
            if let card = details.card ?? heldCard {
                Section {
                    NudgeCardView(card: card, now: now, markDone: markDone, isDoneHeld: heldBinding(for: card))
                        .listRowInsets(EdgeInsets()) // the card draws its own margins and background
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
                if let received = details.received {
                    Label {
                        Text("\(received.senderName) owns this schedule.", comment: "Reminder details: under Schedule of a received reminder, which only its sender can change. The placeholder is the sender's name.")
                    } icon: {
                        LockGlyph()
                    }
                } else if details.showsLockNote {
                    Label {
                        Text("Start, repeat, strength, pace and Break Through Focus are locked while it's nudging. Mark it Done or pause it to change them.",
                             comment: "Reminder details: under Schedule while the reminder is nudging, why five fields can't be edited.")
                    } icon: {
                        LockGlyph()
                    }
                }
            }
            HowItNudgesSection(howItNudges: details.howItNudges)
            if let received = details.received, let notSharing = received.notSharingThisOne, !details.isCanceled {
                DontShareSection(senderName: received.senderName, isOn: notSharing, set: setNotSharing)
            }
            // A waiting copy's Remove is in its Waiting section, with Accept (the mockup's `viewReceived`).
            if !details.isWaiting {
                actionsSection
            }
        }
        .disabled(!isEnabled)
        .centeredInReadableColumn()
    }

    /// Pause or Resume, and Delete or Remove Reminder.
    private var actionsSection: some View {
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
                DeleteButton(title: details.title, isReceived: details.received != nil, confirm: delete)
            } footer: {
                VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                    if details.isCanceled {
                        Text("Removing it clears it from your list.", comment: "Reminder details: under Remove Reminder on a received reminder its sender deleted.")
                    } else if let received = details.received {
                        Text("You can mark it Done, pause it, remove it and add your own tags. \(received.senderName) owns its title, notes, schedule, strength and pace.",
                             comment: "Reminder details: under Remove Reminder on a received reminder, what the person can and can't change. The placeholder is the sender's name.")
                    }
                    if details.pauseAction == .pause {
                        Text("Pausing stops the nudging. Anything due while it's paused is skipped, not missed.",
                             comment: "Reminder details: under Pause Reminder.")
                    }
                }
            }
    }

    private func heldBinding(for card: NudgeCard) -> Binding<Bool> {
        Binding {
            heldCard != nil
        } set: { isHeld in
            heldCard = isHeld ? card : nil
        }
    }
}

/// A note on a received reminder (ticket 204, the mockup's `noteCard`): a cell-colored card under the
/// hero with a symbol, a semibold heading and detail lines, in no status color. The symbol is at the top
/// beside the heading, and above the text at accessibility sizes so the wrapped lines don't drop under
/// it. VoiceOver reads it as one element, without the symbol.
private struct NoteCard<Heading: View, Detail: View>: View {
    let symbol: String
    @ViewBuilder let heading: Heading
    @ViewBuilder let detail: Detail
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Section {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Design.Spacing.s1))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Design.Spacing.s2))
            layout {
                Image(systemName: symbol)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Design.Spacing.line) {
                    heading
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(uiColor: .label))
                    detail
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// What the sender changed on a received reminder (ticket 204): who changed it and when, then a line
/// each field.
private struct ChangeNoteSection: View {
    let note: ReminderDetails.ChangeNote

    var body: some View {
        NoteCard(symbol: "info.circle") {
            Text(note.heading)
        } detail: {
            ForEach(Array(note.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
            }
        }
    }
}

/// A received reminder its sender deleted (ticket 205, the mockup's `viewReceived`): the note that it
/// won't nudge and stays until removed, above the change note.
private struct CanceledSection: View {
    let senderName: String

    var body: some View {
        NoteCard(symbol: "info.circle") {
            Text("Canceled", comment: "Reminder details: the heading of the note on a received reminder its sender deleted.")
        } detail: {
            Text("\(senderName) canceled this reminder, so it won't nudge you. It stays here until you remove it.", comment: "Reminder details: under \"Canceled\" on a received reminder its sender deleted. The placeholder is the sender's name.")
        }
    }
}

/// A received reminder waiting to be accepted (ticket 203, the mockup's `viewReceived`): the note that
/// it won't nudge until accepted, then Accept, tinted, and Remove, which asks first as Remove
/// Reminder does.
private struct WaitingSection: View {
    let title: String
    let accept: () -> Void
    let remove: () -> Void
    @State private var isConfirmingRemove = false

    var body: some View {
        NoteCard(symbol: "clock") {
            Text("Waiting for you to accept", comment: "Reminder details: the note on a reminder someone sent that waits for the person to accept it (Ask me first).")
        } detail: {
            Text("It won't nudge you until you accept it. Anything due before then is skipped.", comment: "Reminder details: under \"Waiting for you to accept\" on a reminder someone sent.")
        }
        Section {
            Button(action: accept) {
                Label {
                    Text("Accept", comment: "Reminder details: starts a reminder someone sent, which waited for the person to accept it.")
                } icon: {
                    Image(systemName: "checkmark")
                }
            }
            Button(role: .destructive) {
                isConfirmingRemove = true
            } label: {
                Label {
                    Text("Remove", comment: "Reminder details: on a reminder someone sent that waits to be accepted, opens the question that asks before removing it.")
                } icon: {
                    Image(systemName: "trash")
                }
            }
            .deleteReminderConfirmation(title: title, kind: .received, isPresented: $isConfirmingRemove, confirm: remove)
        }
    }
}

/// Delete Reminder, or Remove Reminder on a received one (ticket 200), which asks first.
private struct DeleteButton: View {
    let title: String
    let isReceived: Bool
    let confirm: () -> Void
    @State private var isConfirming = false

    var body: some View {
        Button(role: .destructive) {
            isConfirming = true
        } label: {
            Label {
                isReceived
                    ? Text("Remove Reminder", comment: "Reminder details: on a received reminder, opens the question that asks before removing the person's copy.")
                    : Text("Delete Reminder", comment: "Reminder details: opens the question that asks before deleting the reminder.")
            } icon: {
                Image(systemName: "trash")
            }
        }
        .deleteReminderConfirmation(title: title, kind: DeletedReminderKind(isReceived: isReceived), isPresented: $isConfirming, confirm: confirm)
    }
}

/// A received reminder's "Don't share this one" (ticket 200), while the person's Status sharing for
/// its sender is on: it holds this one's status back from them. Its effect is the status tickets'.
private struct DontShareSection: View {
    let senderName: String
    let isOn: Bool
    let set: (Bool) -> Void

    var body: some View {
        Section {
            Toggle(isOn: Binding { isOn } set: { set($0) }) {
                Text("Don't share this one", comment: "Reminder details: on a received reminder, the switch that keeps its status from its sender.")
            }
        } header: {
            Text("Status Sharing", comment: "Reminder details: section header above a received reminder's Don't share this one.")
        } footer: {
            isOn
                ? Text("\(senderName) sees “Not sharing this one” in place of how it's going.", comment: "Reminder details: under Don't share this one while it's on. The placeholder is the sender's name.")
                : Text("\(senderName) sees how this one is going.", comment: "Reminder details: under Don't share this one while it's off. The placeholder is the sender's name.")
        }
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
            if let received = details.received {
                // The badge is in the row below, so the label goes alone.
                FromLabel(from: received.from)
            }
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Design.Spacing.s2))
                : AnyLayout(HStackLayout(spacing: Design.Spacing.s3))
            layout {
                StrengthBadge(strength: details.strength)
                ReminderStatusLabel(status: details.status)
            }
            if let received = details.received {
                Text(received.strengthLine.text)
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
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
        ScheduleSummaryRows(repeats: details.repeats, next: details.next, pace: details.pace, breaksThroughFocus: details.reminder.breaksThroughFocus)
        if let last = details.lastOccurrence {
            LastOccurrenceRow(last: last)
        }
    }
}

/// Repeats, Next, Pace and Break Through Focus: a reminder's details, and a sent reminder's
/// (ticket 201).
struct ScheduleSummaryRows: View {
    let repeats: String
    let next: ReminderDetails.Next
    let pace: Pace
    /// On for Relentless, which always breaks through Focus (ADR 0004).
    let breaksThroughFocus: Bool

    var body: some View {
        LabeledContent {
            Text(verbatim: repeats)
        } label: {
            Text("Repeats", comment: "Reminder details, Schedule: how often the reminder comes due.")
        }
        LabeledContent {
            nextText
        } label: {
            Text("Next", comment: "Reminder details, Schedule: when the reminder is next due.")
        }
        LabeledContent {
            Text(pace.title)
        } label: {
            Text("Pace", comment: "Reminder details, Schedule: how the waits between the reminder's nudges are spaced.")
        }
        LabeledContent {
            breaksThroughFocus
                ? Text("On", comment: "Reminder details: Break Through Focus is on.")
                : Text("Off", comment: "Reminder details: Break Through Focus is off.")
        } label: {
            Text("Break Through Focus", comment: "Reminder details, Schedule: the per-reminder switch that sends nudges as alarms.")
        }
    }

    @ViewBuilder private var nextText: some View {
        switch next {
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

/// What a pushed reminder shows when it is no longer held: deleted, or never there.
struct NotFoundView: View {
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
