import NudgeEngine
import SwiftUI

/// Settings' Quiet Hours page (#370, the approved Quiet Hours page mockup): the schedules in the
/// order they were added, each its times, its days under them, and a switch. Off keeps a schedule,
/// its times dimmed; on again brings it back. Tapping a schedule's words opens its sheet (#371).
/// Add Schedule is the bar's plus. With none, an empty state points at it. The first time it opens,
/// How Quiet Hours Work opens over it (#468).
struct QuietHoursPage: View {
    /// What previews show and change, since they have no app model.
    var previewQuietHours = QuietHours()

    @Environment(AppModel.self) private var model: AppModel?
    /// The previews' schedules once a switch or a sheet has changed them.
    @State private var previewEdits: QuietHours?
    @State private var openSheet: QuietHoursSheetKind?

    private let wording = QuietHoursWording(calendar: .autoupdatingCurrent)

    var body: some View {
        List {
            quietNowSection
            if quietHours.schedules.isEmpty { emptyState } else { scheduleSections }
        }
        .navigationTitle(Text(Self.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Add Schedule is the bar's plus, as the Tags tab's New Tag; the empty state points at it.
            ToolbarItem(placement: .primaryAction) {
                Button { openSheet = .add } label: {
                    Label { Text(QuietHoursScheduleSheet.addTitle) } icon: { Image(systemName: "plus") }
                }
            }
        }
        .sheet(item: $openSheet) { kind in
            QuietHoursScheduleSheet(kind: kind, schedules: quietHours.schedules, wording: wording, save: save, delete: delete)
        }
        .quietHoursTutorialFirstTime(model: model)
    }

    /// Quiet Now (#498): one switch above the schedules, with or without any. It writes the record
    /// through the app model, so the re-plan follows. The footer says what it does, then since when.
    private var quietNowSection: some View {
        Section {
            Toggle(isOn: quietNowBinding) {
                SettingsRow(
                    tile: .tileGray,
                    symbol: "bell.slash",
                    title: Text(Self.quietNowTitle)
                )
            }
        } footer: {
            Text(wording.quietNowFooter(since: quietHours.quietNowSince))
        }
    }

    /// Built by hand, as `ContentUnavailableView` would draw it, since a list row gives that view
    /// unlimited height (it stretched this page's old Add Schedule button into a tall pill).
    private var emptyState: some View {
        Section {
            VStack(spacing: Design.Spacing.s2) {
                EmptyStateLabel(systemImage: "bell.slash") {
                    Text("No Schedules", comment: "Quiet Hours page: title of the empty state, with no quiet hours schedule.")
                }
                .labelStyle(EmptyStateTitleStyle())
                Text("Tap + to add a schedule, and no nudge arrives while it runs.", comment: "Quiet Hours page: under \"No Schedules\", pointing at the plus in the navigation bar.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.Spacing.s4)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    /// The empty state's icon above its title, as `ContentUnavailableView` stacks them.
    private struct EmptyStateTitleStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            VStack(spacing: Design.Spacing.s2) {
                configuration.icon.font(.largeTitle).foregroundStyle(.secondary)
                // Centered line by line, so a title that wraps at the largest text size stays under its icon.
                configuration.title.font(.title2.bold()).multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder private var scheduleSections: some View {
        Section {
            // In the order they were added; each row is its schedule's, by identity (#371).
            ForEach(quietHours.schedules) { schedule in
                Toggle(isOn: isOn(schedule.id)) {
                    SettingsRow(
                        tile: .tileGray,
                        symbol: "clock",
                        title: Text(wording.range(schedule)),
                        titleColor: schedule.isOn ? Color(uiColor: .label) : Color(uiColor: .secondaryLabel),
                        value: Text(wording.days(schedule)),
                        valueFont: .subheadline
                    )
                    // The words open the schedule's sheet; the switch stays the switch's. A tap
                    // gesture, not a button, so the row stays one VoiceOver element.
                    .contentShape(Rectangle())
                    .onTapGesture { openSheet = .edit(schedule) }
                }
                // One element: the schedule's words, then the switch's state, with Edit as an action.
                .accessibilityLabel(Text(wording.spoken(schedule)))
                .accessibilityAction(named: Text("Edit", comment: "Quiet Hours page: a schedule row's VoiceOver action that opens its Edit Schedule sheet.")) {
                    openSheet = .edit(schedule)
                }
            }
        } header: {
            Text("Schedules", comment: "Quiet Hours page: header of the list of quiet hours schedules.")
        } footer: {
            VStack(alignment: .leading, spacing: Design.Spacing.s2) {
                if quietHours.quietNowSince != nil {
                    Text("Quiet Now is holding every nudge. These schedules apply again when you turn it off.",
                         comment: "Quiet Hours page: under the schedules while Quiet Now is on.")
                }
                Text("Turn a schedule off to keep it for later.", comment: "Quiet Hours page: under the schedules.")
                Text("No nudge arrives during quiet hours, alarms included. A nudge held this way counts as one you didn't answer, so a reminder can still end as Missed.",
                     comment: "Quiet Hours page: under the schedules, what quiet hours do.")
            }
        }
    }

    /// The page's title, and the Settings row that opens it.
    static let title = LocalizedStringResource("Quiet Hours", comment: "Settings: the row that opens the Quiet Hours page, and that page's title.")

    /// The switch that holds every nudge until it is turned off (#498), named so too by How Quiet
    /// Hours Work (#468).
    nonisolated static let quietNowTitle = LocalizedStringResource("Quiet Now", comment: "Quiet Hours page: the switch that holds every nudge until it is turned off. Also How Quiet Hours Work's page about it: its heading and picture.")

    private var quietHours: QuietHours {
        model?.quietHours ?? previewEdits ?? previewQuietHours
    }

    /// The model's switch, which writes the record so the re-plan follows. Without a model, the previews'.
    private func isOn(_ id: QuietHoursSchedule.ID) -> Binding<Bool> {
        Binding {
            quietHours.schedules.first { $0.id == id }?.isOn ?? false
        } set: { on in
            if let model {
                model.switchQuietHoursSchedule(id, on: on)
            } else {
                changePreview { $0.switchSchedule(id, on: on) }
            }
        }
    }

    /// The Quiet Now switch: the model's, which writes the record so the re-plan follows. Without a
    /// model, the previews'.
    private var quietNowBinding: Binding<Bool> {
        Binding {
            quietHours.quietNowSince != nil
        } set: { on in
            if let model {
                model.turnQuietNow(on: on)
            } else {
                changePreview { if on { $0.turnOnQuietNow(at: .now) } else { $0.turnOffQuietNow() } }
            }
        }
    }

    /// The sheet's Add or Save: the model's, which writes the record so the re-plan follows.
    private func save(_ schedule: QuietHoursSchedule) {
        if let model { model.saveQuietHoursSchedule(schedule) } else { changePreview { $0.saveSchedule(schedule) } }
    }

    /// The sheet's Delete Schedule, once confirmed.
    private func delete(_ id: QuietHoursSchedule.ID) {
        if let model { model.deleteQuietHoursSchedule(id) } else { changePreview { $0.deleteSchedule(id) } }
    }

    private func changePreview(_ change: (inout QuietHours) -> Void) {
        var changed = quietHours
        change(&changed)
        previewEdits = changed
    }
}

#if DEBUG
private let sampleSchedules = QuietHours(schedules: [
    try! QuietHoursSchedule(start: TimeOfDay(hour: 22), end: TimeOfDay(hour: 7), days: [.sunday, .monday, .tuesday, .wednesday, .thursday]),
    try! QuietHoursSchedule(start: TimeOfDay(hour: 23), end: TimeOfDay(hour: 8), days: [.friday, .saturday]),
    try! QuietHoursSchedule(start: TimeOfDay(hour: 18, minute: 30), end: TimeOfDay(hour: 21), days: [.tuesday, .thursday], isOn: false),
])

#Preview("Schedules") {
    NavigationStack { QuietHoursPage(previewQuietHours: sampleSchedules) }
}

#Preview("Schedules, largest text") {
    NavigationStack { QuietHoursPage(previewQuietHours: sampleSchedules) }
        .dynamicTypeSize(.accessibility5)
}

#Preview("Schedules, landscape", traits: .landscapeLeft) {
    NavigationStack { QuietHoursPage(previewQuietHours: sampleSchedules) }
}

#Preview("Quiet Now on") {
    NavigationStack { QuietHoursPage(previewQuietHours: QuietHours(schedules: sampleSchedules.schedules, quietNowSince: .now)) }
}

#Preview("No schedules") {
    NavigationStack { QuietHoursPage() }
}
#endif
