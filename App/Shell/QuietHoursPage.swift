import NudgeEngine
import SwiftUI

/// Settings' Quiet Hours page (#370, the approved Quiet Hours page mockup): the schedules in the
/// order they were added, each its times, its days under them, and a switch. Off keeps a schedule,
/// its times dimmed; on again brings it back. Tapping a schedule's words opens its sheet (#371), and
/// Add Schedule follows the list. With none, an empty state with its own Add Schedule.
struct QuietHoursPage: View {
    /// What previews show and change, since they have no app model.
    var previewQuietHours = QuietHours()

    @Environment(AppModel.self) private var model: AppModel?
    /// The previews' schedules once a switch or a sheet has changed them.
    @State private var previewEdits: QuietHours?
    @State private var openSheet: QuietHoursSheetKind?

    private let wording = QuietHoursWording(calendar: .autoupdatingCurrent)

    var body: some View {
        Group {
            if quietHours.schedules.isEmpty { emptyState } else { scheduleList }
        }
        .navigationTitle(Text(Self.title))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $openSheet) { kind in
            QuietHoursScheduleSheet(kind: kind, wording: wording, save: save, delete: delete)
        }
    }

    private var emptyState: some View {
        ScrollView {
            ContentUnavailableView {
                EmptyStateLabel(systemImage: "bell.slash") {
                    Text("No Schedules", comment: "Quiet Hours page: title of the empty state, with no quiet hours schedule.")
                }
            } description: {
                Text("Add a schedule, and no nudge arrives while it runs.", comment: "Quiet Hours page: under \"No Schedules\".")
            } actions: {
                Button { openSheet = .add } label: {
                    Label { Text(QuietHoursScheduleSheet.addTitle) } icon: { Image(systemName: "plus") }
                }
                .buttonStyle(.bordered)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var scheduleList: some View {
        List {
            Section {
                // A schedule is known by its place in the list, the order they were added.
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
                    Text("Turn a schedule off to keep it for later.", comment: "Quiet Hours page: under the schedules.")
                    Text("No nudge arrives during quiet hours, alarms included. A nudge held this way counts as one you didn't answer, so a reminder can still end as Missed.",
                         comment: "Quiet Hours page: under the schedules, what quiet hours do.")
                }
            }
            // No footer: what quiet hours do stays under Schedules (#370's review).
            Section {
                Button { openSheet = .add } label: {
                    SettingsRow(tile: .tileBlue, symbol: "plus", title: Text(QuietHoursScheduleSheet.addTitle), titleColor: .accentColor)
                }
            }
        }
    }

    /// The page's title, and the Settings row that opens it.
    static let title = LocalizedStringResource("Quiet Hours", comment: "Settings: the row that opens the Quiet Hours page, and that page's title.")

    private var quietHours: QuietHours {
        model?.quietHours ?? previewEdits ?? previewQuietHours
    }

    /// The model's switch, which writes the record so the re-plan follows. Without a model, the previews'.
    private func isOn(_ id: QuietHoursSchedule.ID) -> Binding<Bool> {
        Binding {
            quietHours.schedules.first { $0.id == id }?.isOn ?? false
        } set: { on in
            if let model {
                model.setQuietHoursSchedule(id, on: on)
            } else {
                changePreview { $0.switchSchedule(id, on: on) }
            }
        }
    }

    /// The sheet's Add or Save: the model's, which writes the record so the re-plan follows.
    private func save(_ schedule: QuietHoursSchedule) {
        if let model { model.saveQuietHoursSchedule(schedule) } else { changePreview { $0.save(schedule) } }
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

#Preview("No schedules") {
    NavigationStack { QuietHoursPage() }
}
#endif
