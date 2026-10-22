import NudgeEngine
import SwiftUI

/// The New and Edit Reminder form, as the mockup's sheet: Title, Notes and Tags; Starts and
/// Repeat; Strength; Pace; Break Through Focus. While the reminder is Nudging the schedule fields
/// are disabled, each with a `lock`, under a note that says why (ticket 13). Save goes through the
/// app model; without one (previews) it is disabled.
struct ReminderFormSheet: View {
    @Bindable var form: ReminderForm
    @Environment(AppModel.self) private var model: AppModel?
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDiscard = false

    var body: some View {
        NavigationStack {
            Form {
                if form.isEditing { EditNoteSection(isLocked: !form.lockedFields.isEmpty) }
                WhatSection(form: form)
                ScheduleSection(form: form)
                StrengthSection(form: form)
                PaceSection(form: form)
                BreakThroughFocusSection(form: form)
                HowItNudgesSection(howItNudges: form.howItNudges)
            }
            .scrollDismissesKeyboard(.interactively)
            .centeredInReadableColumn()
            .navigationTitle(form.isEditing
                ? Text("Edit Reminder", comment: "Title of the form that edits a reminder.")
                : Text("New Reminder", comment: "Title of the form that makes a reminder."))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ReminderFormPage.self) { page in
                switch page {
                case .tags: TagsPage(form: form)
                case .repeat: RepeatPage(form: form)
                case .custom: CustomRepeatPage(form: form)
                }
            }
            .toolbar { toolbar }
        }
        // On the stack, not its root: the root is covered by the Repeat and Custom pages, which
        // lock too when the reminder falls due while they're open.
        .task { await form.keepTheLockCurrent() }
        // A swipe down mustn't lose changes; Cancel asks first instead.
        .interactiveDismissDisabled(form.hasChanges)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .cancel) {
                if form.hasChanges { isConfirmingDiscard = true } else { dismiss() }
            } label: {
                Label {
                    Text("Cancel", comment: "The form's cancel button (an xmark).")
                } icon: {
                    Image(systemName: "xmark")
                }
            }
            .confirmationDialog(Text("Discard your changes?", comment: "Asked when cancelling a reminder form with changes."),
                                isPresented: $isConfirmingDiscard, titleVisibility: .hidden) {
                Button(role: .destructive) {
                    dismiss()
                } label: {
                    Text("Discard Changes", comment: "Throws away the reminder form's changes and closes it.")
                }
                Button(role: .cancel) {
                } label: {
                    Text("Keep Editing", comment: "Goes back to the reminder form without discarding.")
                }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm) {
                if let model, form.save(to: model) { dismiss() }
            } label: {
                Label {
                    form.isEditing
                        ? Text("Save", comment: "The Edit Reminder form's confirm button (a checkmark).")
                        : Text("Add", comment: "The New Reminder form's confirm button (a checkmark).")
                } icon: {
                    Image(systemName: "checkmark")
                }
            }
            .disabled(model == nil || form.saveBlock != nil)
        }
    }
}

/// The pages the form pushes.
enum ReminderFormPage: Hashable {
    case tags
    case `repeat`
    case custom
}

/// The note at the top of the Edit form: why the schedule is locked, or when changes apply.
private struct EditNoteSection: View {
    let isLocked: Bool

    var body: some View {
        Section {
        } header: {
            Group {
                if isLocked {
                    Label {
                        Text("**Nudging now.** Start, repeat, strength, pace and Break Through Focus are locked while it's nudging. Mark it Done or pause it to change them. A new title shows from the next nudge.",
                             comment: "Top of the Edit Reminder form while the reminder is nudging: why five fields are locked.")
                    } icon: {
                        LockGlyph()
                    }
                } else {
                    Text("A new schedule applies from the next time it's due. A new strength, pace or Break Through Focus setting applies from the next nudge.",
                         comment: "Top of the Edit Reminder form when the reminder isn't nudging: when changes apply.")
                }
            }
            .font(.footnote)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .textCase(nil)
        }
    }
}

/// Title, Notes and Tags, which stay editable while nudging.
private struct WhatSection: View {
    @Bindable var form: ReminderForm
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        Section {
            TextField(text: $form.title, axis: .vertical) {
                Text("Title", comment: "The reminder form's title field, which must be filled in.")
            }
            .focused($isTitleFocused)
            .submitLabel(.done)
            // A vertical field takes Return as a new line. Return at the end ends editing instead,
            // as the mockup's "done" key; the form saves any pasted line breaks as spaces.
            .onChange(of: form.title) { _, title in
                guard title.last?.isNewline == true else { return }
                form.title.removeLast()
                isTitleFocused = false
            }
            TextField(text: $form.notes, axis: .vertical) {
                Text("Notes", comment: "The reminder form's notes field.")
            }
            .lineLimit(3...)
            NavigationLink(value: ReminderFormPage.tags) {
                LabeledContent {
                    if let tags = form.chosenTagsText {
                        // The person's own tag names, never translated.
                        Text(verbatim: tags)
                    } else {
                        Text("None", comment: "The reminder form's Tags row when no tag is chosen.")
                    }
                } label: {
                    Text("Tags", comment: "The reminder form's row that opens the Tags page.")
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                if form.saveBlock == .noTitle {
                    Text("Add a title to save.", comment: "Under the reminder form's title when it is empty, so Save is disabled.")
                        .foregroundStyle(Color.negative)
                }
                Text("Notes and tags stay in the app. Notifications and alarms show the title, not these.",
                     comment: "Under the reminder form's Title, Notes and Tags.")
            }
        }
        .onAppear {
            // A new reminder starts at its title, as the mockup's sheet does.
            if form.title.isEmpty { isTitleFocused = true }
        }
    }
}

/// Starts and Repeat, locked while nudging.
private struct ScheduleSection: View {
    @Bindable var form: ReminderForm

    var body: some View {
        let locked = form.lockedFields
        Section {
            DatePicker(selection: $form.dueTime) {
                LockableLabel(isLocked: locked.contains(.dueTime)) {
                    Text("Starts", comment: "The reminder form's start date and time.")
                }
            }
            .lockedWhileNudging(locked.contains(.dueTime))
            RepeatRow(form: form, isLocked: locked.contains(.repeatRule))
        } footer: {
            VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                if form.saveBlock == .pastTime {
                    Text("This time has passed. Choose a later time.",
                         comment: "Under the reminder form's start when a one-off reminder's time has passed, so Save is disabled.")
                        .foregroundStyle(Color.negative)
                }
                switch form.repeatBlock {
                case .endsBeforeStart:
                    Text("The repeat ends before it starts. Change its end date.",
                         comment: "Under the reminder form's start when a custom repeat's end date is before the start, so Save is disabled.")
                        .foregroundStyle(Color.negative)
                case .noTimesLeft:
                    Text("The repeat has already ended. Change when it ends.",
                         comment: "Under the reminder form's start when a custom repeat has no times left, so Save is disabled.")
                        .foregroundStyle(Color.negative)
                case .noTitle, .pastTime, nil:
                    EmptyView()
                }
                RepeatSummarySentence(summary: form.repeatSummary)
            }
        }
    }
}

/// The Repeat row: the preset's name or Custom. It opens the Repeat page unless it's locked.
private struct RepeatRow: View {
    let form: ReminderForm
    let isLocked: Bool

    var body: some View {
        let value = form.repeatPreset.map { Text($0.title) }
            ?? Text("Custom", comment: "The reminder form's Repeat row when the repeat is a custom rule.")
        let label = Text("Repeat", comment: "The reminder form's row that opens the Repeat page.")
        if isLocked {
            LockedValueRow(label: label, value: value)
        } else {
            NavigationLink(value: ReminderFormPage.repeat) {
                LabeledContent { value } label: { label }
            }
        }
    }
}

/// Gentle, Firm or Relentless, locked while nudging.
private struct StrengthSection: View {
    @Bindable var form: ReminderForm

    var body: some View {
        SegmentedChoiceSection(
            label: Text("Strength", comment: "The reminder form's strength choice: Gentle, Firm or Relentless."),
            selection: $form.strength,
            isLocked: form.lockedFields.contains(.strength)
        ) {
            ForEach(Strength.formOrder, id: \.self) { strength in
                Text(strength.title).tag(strength)
            }
        } footer: {
            VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                form.strengthBlurb.text
                Text("Gives up after \(GiveUpLimit.shipped.nudgeCount) nudges or \(GiveUpLimit.shipped.spanText), whichever comes first.",
                     comment: "Under the reminder form's strength. 1: the give-up limit's nudge count. 2: its span, such as \"24 hours\".")
            }
        }
    }
}

/// Escalating or Consistent, and for Consistent the Every row's wait from the engine's list.
/// Both are locked while nudging.
private struct PaceSection: View {
    @Bindable var form: ReminderForm

    var body: some View {
        let isLocked = form.lockedFields.contains(.pace)
        SegmentedChoiceSection(
            label: Text("Pace", comment: "The reminder form's pace choice: Escalating or Consistent."),
            selection: $form.paceChoice,
            isLocked: isLocked
        ) {
            ForEach(PaceChoice.allCases, id: \.self) { choice in
                Text(choice.title).tag(choice)
            }
        } rows: {
            if form.paceChoice == .consistent {
                EveryRow(form: form, isLocked: isLocked)
            }
        } footer: {
            form.paceBlurb.text
        }
    }
}

/// A Consistent pace's wait. Locked, it is plain text without the menu's arrows.
private struct EveryRow: View {
    @Bindable var form: ReminderForm
    let isLocked: Bool

    var body: some View {
        let label = Text("Every", comment: "The reminder form's row for a Consistent pace's wait between nudges, such as \"10 min\".")
        if isLocked {
            LockedValueRow(label: label, value: Text(verbatim: HowItNudgesDuration.text(form.consistentWait)))
        } else {
            Picker(selection: $form.consistentWait) {
                ForEach(Pace.consistentWaits, id: \.self) { wait in
                    Text(verbatim: HowItNudgesDuration.text(wait)).tag(wait)
                }
            } label: {
                label
            }
            .pickerStyle(.menu)
        }
    }
}

/// A section that is one segmented choice, as Strength and Pace are: its label as the heading,
/// the segments, any rows that follow them, and a footer. Locked while nudging, the heading and
/// the label carry the `lock` and the segments are dimmed.
private struct SegmentedChoiceSection<Selection: Hashable, Options: View, Rows: View, Footer: View>: View {
    let label: Text
    @Binding var selection: Selection
    let isLocked: Bool
    @ViewBuilder let options: () -> Options
    @ViewBuilder let rows: () -> Rows
    @ViewBuilder let footer: () -> Footer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Section {
            Picker(selection: $selection) {
                options()
            } label: {
                LockableLabel(isLocked: isLocked) { label }
            }
            .segmentedPickerStyle(isMenu: dynamicTypeSize.isAccessibilitySize)
            .lockedWhileNudging(isLocked)
            rows()
        } header: {
            if !dynamicTypeSize.isAccessibilitySize {
                // VoiceOver reads the segments without the picker's label (device check, ticket
                // 25), so the heading names them. At accessibility sizes the menu carries it.
                LockableLabel(isLocked: isLocked) { label }
            }
        } footer: {
            footer()
        }
    }
}

/// The Break Through Focus switch, locked while nudging. Relentless shows it on and dimmed, with
/// a footnote saying why (spec stories 30 and 45).
private struct BreakThroughFocusSection: View {
    @Bindable var form: ReminderForm

    var body: some View {
        let isLocked = form.lockedFields.contains(.breakThroughFocus)
        Section {
            Toggle(isOn: $form.breaksThroughFocus) {
                LockableLabel(isLocked: isLocked) {
                    Text("Break Through Focus", comment: "The reminder form's switch: whether its nudges get through a Focus.")
                }
            }
            .disabled(form.isBreakThroughFocusFixed)
            .lockedWhileNudging(isLocked)
        } footer: {
            switch (form.breaksThroughFocus, form.strength) {
            case _ where form.isBreakThroughFocusFixed:
                Text("Relentless always rings, so it always breaks through a Focus.",
                     comment: "Under Break Through Focus when the strength is Relentless, which shows the switch on and dimmed.")
            case (true, .gentle):
                Text("High nudges are Time Sensitive, so a Focus can't hold them. Gentle never reaches Urgent, so it never rings.",
                     comment: "Under Break Through Focus when it's on and the strength is Gentle.")
            case (true, _):
                Text("High nudges are Time Sensitive and Urgent nudges ring as alarms, so a Focus can't hold them.",
                     comment: "Under Break Through Focus when it's on and the strength is Firm.")
            case (false, _):
                Text("Every nudge is an ordinary notification, which a Focus can hold. Nothing rings.",
                     comment: "Under Break Through Focus when it's off.")
            }
        }
    }
}

extension SegmentedChoiceSection where Rows == EmptyView {
    /// A choice with no rows after its segments, as Strength is.
    init(
        label: Text,
        selection: Binding<Selection>,
        isLocked: Bool,
        @ViewBuilder options: @escaping () -> Options,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.init(label: label, selection: selection, isLocked: isLocked, options: options, rows: { EmptyView() }, footer: footer)
    }
}

/// A row whose value is locked while nudging: plain text, without the arrows or chevron of the
/// control it replaces, read by VoiceOver as one element with the lock's reason as its hint.
private struct LockedValueRow: View {
    let label: Text
    let value: Text

    var body: some View {
        LabeledContent {
            value
        } label: {
            LockableLabel(isLocked: true) { label }
        }
        .accessibilityElement(children: .combine)
        .lockedWhileNudging(true)
    }
}

/// A control's label, with the `lock` glyph after it while the field is locked.
private struct LockableLabel<Content: View>: View {
    let isLocked: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: Design.Spacing.s1) {
            content()
            if isLocked { LockGlyph() }
        }
    }
}

/// DESIGN.md's `lock`, always beside its reason as text, so VoiceOver skips it.
struct LockGlyph: View {
    var body: some View {
        Image(systemName: "lock")
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .accessibilityHidden(true)
    }
}

extension View {
    /// The mockup's segmented control, which becomes a menu at accessibility sizes so the names
    /// aren't cut short: Strength, Pace, and the Custom page's Frequency and Ends.
    @ViewBuilder
    func segmentedPickerStyle(isMenu: Bool) -> some View {
        if isMenu {
            pickerStyle(.menu)
        } else {
            pickerStyle(.segmented)
        }
    }

    /// Disables a field that is locked while nudging, and gives it the reason as its VoiceOver
    /// hint, so the reason isn't only the dimmed look and the glyph.
    func lockedWhileNudging(_ isLocked: Bool) -> some View {
        disabled(isLocked)
            .accessibilityHint(Text(LockNote.hint), isEnabled: isLocked)
    }
}

/// Why a Nudging reminder's schedule is locked (ticket 13), as the form's top note says it. A
/// separate catalog string from the note because a hint can't carry its bold.
enum LockNote {
    static let hint = LocalizedStringResource(
        "Nudging now. Start, repeat, strength, pace and Break Through Focus are locked while it's nudging. Mark it Done or pause it to change them. A new title shows from the next nudge.",
        comment: "VoiceOver hint on each field of the Edit Reminder form that is locked while the reminder is nudging: the note at the top of the form, without its bold."
    )
}

extension Strength {
    /// In the form's order, gentlest first.
    static let formOrder: [Strength] = [.gentle, .firm, .relentless]

    var title: LocalizedStringResource {
        switch self {
        case .gentle: LocalizedStringResource("Gentle", comment: "Strength name: the reminder nudges gently.")
        case .firm: LocalizedStringResource("Firm", comment: "Strength name.")
        case .relentless: LocalizedStringResource("Relentless", comment: "Strength name: the reminder nudges hardest.")
        }
    }
}

extension GiveUpLimit {
    /// The span in words, such as "24 hours", in the app's language.
    var spanText: String {
        Duration.seconds(span).formatted(.units(allowed: [.hours], width: .wide))
    }
}

/// A repeat summary as a sentence: the Starts footer, and the Custom row's footer when the repeat
/// is custom.
struct RepeatSummarySentence: View {
    let summary: String

    var body: some View {
        Text("\(summary).", comment: "A repeat summary as a sentence, under the reminder form's Starts and under the Repeat page's Custom row. The placeholder is the engine's summary, such as \"Every 3 days at 9:00 AM\".")
    }
}

#Preview("New") {
    ReminderFormSheet(form: .preview())
}

#Preview("New, dark") {
    ReminderFormSheet(form: .preview())
        .preferredColorScheme(.dark)
}

#Preview("Locked, largest text") {
    ReminderFormSheet(form: .previewNudging())
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Locked") {
    ReminderFormSheet(form: .previewNudging())
}
