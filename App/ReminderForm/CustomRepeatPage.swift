import NudgeEngine
import SwiftUI

/// The Custom repeat page (ticket 25), as the mockup's: the summary on top, then Frequency and
/// its Every stepper, On (weekdays, or the monthly choices the start offers), Ends, and the Next
/// Times it falls due. It edits the form's custom repeat as the person goes, so Back keeps it.
/// The person never sees the rule (ADR 0003).
struct CustomRepeatPage: View {
    @Bindable var form: ReminderForm

    var body: some View {
        let isLocked = form.lockedFields.contains(.repeatRule)
        Form {
            if isLocked { RepeatLockSection() }
            if let choices = Binding($form.customRepeat) {
                Section {
                } header: {
                    Text("\(form.repeatSummary).", comment: "Top of the Custom repeat page: the repeat as a sentence. The placeholder is the engine's summary, such as \"Every 2 weeks on Monday at 9:00 AM\".")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(uiColor: .label))
                        .textCase(nil)
                }
                Group {
                    FrequencySection(choices: choices, start: form.dueTime)
                    switch choices.wrappedValue.frequency {
                    case .weekly: WeekdaysSection(form: form)
                    case .monthly: MonthlySection(form: form)
                    case .daily, .yearly: EmptyView()
                    }
                    EndsSection(choices: choices, start: form.dueTime, endsBeforeStart: form.repeatBlock == .endsBeforeStart)
                }
                // The reminder may start nudging while the page is open (ticket 13).
                .lockedWhileNudging(isLocked)
                NextTimesSection(form: form)
            }
        }
        .centeredInReadableColumn()
        .navigationTitle(Text("Custom", comment: "Title of the Custom repeat page."))
        .navigationBarTitleDisplayMode(.inline)
        // Choosing Custom on the Repeat page starts from the preset that was chosen.
        .onAppear { form.chooseCustom() }
        // Left with the choices as they were seeded, it changes nothing.
        .onDisappear { form.leaveCustom() }
    }
}

/// Daily, Weekly, Monthly or Yearly, and every how many.
private struct FrequencySection: View {
    @Binding var choices: CustomRepeat
    let start: Date
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Section {
            Picker(selection: $choices.frequency) {
                ForEach(RepeatRule.Frequency.allCases, id: \.self) { frequency in
                    Text(frequency.title).tag(frequency)
                }
            } label: {
                Text("Frequency", comment: "The Custom repeat page's choice of Daily, Weekly, Monthly or Yearly.")
            }
            .segmentedPickerStyle(isMenu: dynamicTypeSize.isAccessibilitySize)
            Stepper(value: $choices.interval, in: CustomRepeat.intervals(for: choices.frequency)) {
                Text(choices.frequency.every(choices.interval))
            }
        } header: {
            if !dynamicTypeSize.isAccessibilitySize {
                // VoiceOver reads the segments without the picker's label (device check, ticket
                // 25), so the heading names them. At accessibility sizes the menu carries it.
                Text("Frequency", comment: "The Custom repeat page's choice of Daily, Weekly, Monthly or Yearly.")
            }
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

    /// Monday first, as the mockup's `WEEK_ORDER`, whatever the locale's first weekday.
    private static let order: [RepeatRule.Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var body: some View {
        Section {
            ForEach(Self.order, id: \.self) { weekday in
                CheckmarkRow(title: Text(verbatim: form.name(of: weekday)),
                             isChecked: form.customRepeat?.weekdays.contains(weekday) == true) {
                    form.customRepeat?.toggle(weekday)
                }
                // Each day turns on and off on its own, as a checkbox does. Apple's docs give
                // SwiftUI on iOS no checkbox trait (the checkbox toggle style is macOS only), so
                // it's a toggle that is selected while chosen. What VoiceOver says is a device check.
                .accessibilityAddTraits(.isToggle)
            }
        } header: {
            Text("On", comment: "Header of the Custom repeat page's days: the weekdays, or the day of the month.")
        } footer: {
            Text("Choose one or more days.", comment: "Under the Custom repeat page's weekdays.")
        }
    }
}

/// A monthly repeat's day: the ones the start offers, so there's nothing else to pick.
private struct MonthlySection: View {
    @Bindable var form: ReminderForm

    var body: some View {
        let chosen = form.chosenMonthlyDay
        Section {
            ForEach(form.monthlyDays, id: \.day) { monthlyDay in
                // The person's choice of one, read as "selected" as the Repeat page's presets are.
                CheckmarkRow(title: Text(verbatim: monthlyDay.title), isChecked: monthlyDay.day == chosen) {
                    form.customRepeat?.monthlyDay = monthlyDay.day
                }
            }
        } header: {
            Text("On", comment: "Header of the Custom repeat page's days: the weekdays, or the day of the month.")
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

/// Never, after a number of times, or on a date no earlier than the start.
private struct EndsSection: View {
    @Binding var choices: CustomRepeat
    let start: Date
    let endsBeforeStart: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Section {
            Picker(selection: $choices.ending) {
                Text("Never", comment: "The Custom repeat page's Ends choice: it repeats for ever.").tag(CustomRepeat.Ending.never)
                Text("After", comment: "The Custom repeat page's Ends choice: it ends after a number of times.").tag(CustomRepeat.Ending.afterCount)
                Text("On Date", comment: "The Custom repeat page's Ends choice: it ends on a date.").tag(CustomRepeat.Ending.onDate)
            } label: {
                Text("Ends", comment: "The Custom repeat page's choice of when the repeat ends.")
            }
            .segmentedPickerStyle(isMenu: dynamicTypeSize.isAccessibilitySize)
            switch choices.ending {
            case .never:
                EmptyView()
            case .afterCount:
                Stepper(value: $choices.count, in: CustomRepeat.counts) {
                    Text("After \(choices.count) times", comment: "The Custom repeat page's stepper: how many times it falls due before it ends.")
                }
            case .onDate:
                // No earlier than the start. An end date already before it (the start moved
                // later) stays in range, or the picker would show the start in its place while
                // the rule kept the old date (device check, ticket 25); the reason below says why.
                let startDay = Calendar.autoupdatingCurrent.startOfDay(for: start)
                DatePicker(selection: $choices.endDate, in: min(startDay, choices.endDate)..., displayedComponents: .date) {
                    Text("End Date", comment: "The Custom repeat page's last day the repeat can fall due.")
                }
            }
        } header: {
            if !dynamicTypeSize.isAccessibilitySize {
                // Read by VoiceOver, as Frequency's heading is.
                Text("Ends", comment: "The Custom repeat page's choice of when the repeat ends.")
            }
        } footer: {
            if endsBeforeStart {
                Text("Choose an end date after the start.", comment: "Under the Custom repeat page's end date when it is before the start, so Save is disabled.")
                    .foregroundStyle(Color.negative)
            }
        }
    }
}

/// The next three times it falls due, and whether it ends before then.
private struct NextTimesSection: View {
    let form: ReminderForm

    var body: some View {
        let dueTimes = form.upcomingDueTimes
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
