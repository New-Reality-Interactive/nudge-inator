import NudgeEngine
import SwiftUI

/// The Custom repeat page (ticket 25), as the mockup's: the summary on top, then Frequency and
/// its Every stepper, On (weekdays, or the monthly choices the start offers), and the Next Times it
/// falls due, ending where the form's End Repeat says (#287). A sheet over the form, as in Apple's
/// Reminders on iOS 27 (#284): each change is the form's repeat as it's made, held until the
/// form's own Save. Apply is its only button and only closes it, as a swipe down does, and nothing
/// on it asks a question. The person never sees the rule (ADR 0003).
struct CustomRepeatPage: View {
    @Bindable var form: ReminderForm
    @Environment(\.dismiss) private var dismiss
    /// The start of the current minute, ticked while the page is open: Next Times' due times pass
    /// with no change the views can see (ticket 16), as the Now tab's badge counts do.
    @State private var minute = Date.now

    var body: some View {
        let isLocked = form.lockedFields.contains(.repeatRule)
        Form {
            if isLocked { CustomRepeatLockSection() }
            let choices = $form.customPageChoices
            Section {
            } header: {
                Text("\(form.customPageSummary).", comment: "Top of the Custom repeat page: the repeat as a sentence. The placeholder is the engine's summary, such as \"Every 2 weeks on Monday at 9:00 AM\".")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color(uiColor: .label))
                    .textCase(nil)
            }
            // The reminder may start nudging while the page is open (ticket 13). Each control
            // takes the lock itself, so the headings stay headings (ticket 16).
            FrequencySection(choices: choices, start: form.dueTime, isLocked: isLocked)
            switch choices.wrappedValue.frequency {
            case .weekly: WeekdaysSection(form: form, isLocked: isLocked)
            case .monthly: MonthlySection(form: form, isLocked: isLocked)
            case .daily, .yearly: EmptyView()
            }
            NextTimesSection(form: form, minute: minute)
        }
        // On the Form, not the section, so exactly one loop ticks however many rows it has.
        .task {
            while (try? await EveryMinute.sleepUntilNext()) != nil {
                minute = .now
            }
        }
        .centeredInReadableColumn()
        .navigationTitle(Text("Custom", comment: "Title of the Custom repeat sheet."))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
    }

    /// Apply, drawn as the form's own Save. Never disabled, not even while nudging, so the sheet
    /// can always close: the choices are the form's already, and the form's Save is what checks
    /// them.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button(role: .confirm) {
                dismiss()
            } label: {
                Label {
                    Text("Apply", comment: "The Custom repeat sheet's only button (a checkmark): it closes the sheet. Its choices are already the reminder form's repeat.")
                } icon: {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

/// Daily, Weekly, Monthly or Yearly, and every how many.
private struct FrequencySection: View {
    @Binding var choices: CustomRepeat
    let start: Date
    let isLocked: Bool

    var body: some View {
        SegmentedChoiceSection(
            label: Text("Frequency", comment: "The Custom repeat page's choice of Daily, Weekly, Monthly or Yearly."),
            selection: $choices.frequency,
            selectedTitle: Text(choices.frequency.title),
            isLocked: isLocked
        ) {
            ForEach(RepeatRule.Frequency.allCases, id: \.self) { frequency in
                Text(frequency.title).tag(frequency)
            }
        } rows: {
            LockableStepper(value: $choices.interval, range: CustomRepeat.intervals(for: choices.frequency), isLocked: isLocked,
                            label: Text(choices.frequency.every(choices.interval)))
        } footer: {
            if choices.frequency == .yearly {
                let day = start.formatted(.dateTime.day().month(.wide))
                Text("On \(day), from the start date. Change it to pick another day.",
                     comment: "Under the Custom repeat page's frequency when it's yearly. The placeholder is the start's day and month, such as \"28 October\".")
            }
        }
    }
}

/// A weekly repeat's days, Monday first. The last chosen day can't be taken off.
private struct WeekdaysSection: View {
    @Bindable var form: ReminderForm
    let isLocked: Bool

    /// Monday first, as the mockup's `WEEK_ORDER`, whatever the locale's first weekday.
    private static let order: [RepeatRule.Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var body: some View {
        Section {
            ForEach(Self.order, id: \.self) { weekday in
                CheckmarkRow(title: Text(verbatim: form.name(of: weekday)),
                             isChecked: form.customPageChoices.weekdays.contains(weekday)) {
                    form.customPageChoices.toggle(weekday)
                }
                // Each day turns on and off on its own, as a checkbox does. Apple's docs give
                // SwiftUI on iOS no checkbox trait (the checkbox toggle style is macOS only), so
                // it's a toggle that is selected while chosen. What VoiceOver says is a device check.
                .accessibilityAddTraits(.isToggle)
                .lockedWhileNudging(isLocked)
            }
        } header: {
            OnHeader(isLocked: isLocked)
        } footer: {
            Text("Choose one or more days.", comment: "Under the Custom repeat page's weekdays.")
        }
    }
}

/// A monthly repeat's day: the ones the start offers, so there's nothing else to pick.
private struct MonthlySection: View {
    @Bindable var form: ReminderForm
    let isLocked: Bool

    var body: some View {
        let chosen = form.chosenMonthlyDay
        Section {
            ForEach(form.monthlyDays, id: \.day) { monthlyDay in
                // The person's choice of one, read as "selected" as the Repeat menu's items are.
                CheckmarkRow(title: Text(verbatim: monthlyDay.title), isChecked: monthlyDay.day == chosen) {
                    form.customPageChoices.monthlyDay = monthlyDay.day
                }
                .lockedWhileNudging(isLocked)
            }
        } header: {
            OnHeader(isLocked: isLocked)
        } footer: {
            VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                if let note = form.skippedMonthsNote {
                    Text(verbatim: note)
                }
                Text("These follow the start date. Change it to pick another day.",
                     comment: "Under the Custom repeat page's monthly days.")
            }
        }
    }
}

/// The heading of the weekdays or the monthly days, with the `lock` while they're locked.
private struct OnHeader: View {
    let isLocked: Bool

    var body: some View {
        LockableLabel(isLocked: isLocked) {
            Text("On", comment: "Header of the Custom repeat page's days: the weekdays, or the day of the month.")
        }
    }
}

/// The next three times it falls due, and whether it ends before then.
private struct NextTimesSection: View {
    let form: ReminderForm
    /// The page's minute. A new one draws the section again, so its due times are worked out
    /// from the clock again.
    let minute: Date

    var body: some View {
        let dueTimes = form.customPageUpcomingDueTimes
        Section {
            ForEach(dueTimes, id: \.self) { dueTime in
                LabeledContent {
                    Text(dueTime, format: .dateTime.hour().minute())
                } label: {
                    day(of: dueTime)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Next Times", comment: "Header of the Custom repeat page's next three due times.")
        } footer: {
            if dueTimes.isEmpty {
                Text("This repeat has no times left. Change when it ends.", comment: "Under the Custom repeat page's Next Times when the repeat has ended.")
                    .foregroundStyle(Color.negative)
            } else if dueTimes.count < ReminderForm.nextTimesCount {
                Text("Then it ends.", comment: "Under the Custom repeat page's Next Times when fewer than three are left.")
            }
        }
    }

    /// "Today", "Tomorrow", or the short date, with the year when it isn't this year, as the
    /// mockup's `nextDay`.
    private func day(of date: Date) -> Text {
        let calendar = Calendar.autoupdatingCurrent
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: form.currentTime), to: calendar.startOfDay(for: date)).day
        if days == 0 { return Text("Today", comment: "The Custom repeat page's Next Times: a due time today.") }
        if days == 1 { return Text("Tomorrow", comment: "The Custom repeat page's Next Times: a due time tomorrow.") }
        let style = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
        // Formatted for the locale already.
        return Text(verbatim: date.formatted(form.showsYear(of: date) ? style.year() : style))
    }
}

extension RepeatRule.Frequency {
    var title: LocalizedStringResource {
        switch self {
        case .daily: LocalizedStringResource("Daily", comment: "The Custom repeat page's frequency.")
        case .weekly: LocalizedStringResource("Weekly", comment: "The Custom repeat page's frequency.")
        case .monthly: LocalizedStringResource("Monthly", comment: "The Custom repeat page's frequency.")
        case .yearly: LocalizedStringResource("Yearly", comment: "The Custom repeat page's frequency.")
        }
    }

    /// The Every stepper's label: "Every day", "Every 2 weeks".
    func every(_ interval: Int) -> LocalizedStringResource {
        switch self {
        case .daily: LocalizedStringResource("Every \(interval) days", comment: "The Custom repeat page's stepper for a daily repeat. Singular: \"Every day\".")
        case .weekly: LocalizedStringResource("Every \(interval) weeks", comment: "The Custom repeat page's stepper for a weekly repeat. Singular: \"Every week\".")
        case .monthly: LocalizedStringResource("Every \(interval) months", comment: "The Custom repeat page's stepper for a monthly repeat. Singular: \"Every month\".")
        case .yearly: LocalizedStringResource("Every \(interval) years", comment: "The Custom repeat page's stepper for a yearly repeat. Singular: \"Every year\".")
        }
    }
}

#if DEBUG
#Preview("Weekly") {
    NavigationStack {
        CustomRepeatPage(form: .previewCustom(from: .everyTwoWeeks))
    }
}

#Preview("Monthly, dark") {
    NavigationStack {
        CustomRepeatPage(form: .previewCustom(from: .everyMonth))
    }
    .preferredColorScheme(.dark)
}

#Preview("Weekly, largest text") {
    NavigationStack {
        CustomRepeatPage(form: .previewCustom(from: .everyTwoWeeks))
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Locked while nudging") {
    NavigationStack {
        CustomRepeatPage(form: .previewNudging())
    }
}
#endif

/// At the top of the Custom page when the reminder started nudging while it was open: the form's
/// lock note, so the disabled rows say why.
struct CustomRepeatLockSection: View {
    var body: some View {
        Section {
        } header: {
            Label {
                Text(LockNote.note)
            } icon: {
                LockGlyph()
            }
            .font(.footnote)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .textCase(nil)
        }
    }
}
