import NudgeEngine
import SwiftUI

/// Settings' Quiet Hours page (#370, the approved Quiet Hours page mockup): the schedules in the
/// order they were added, each its times, its days under them, and a switch. Off keeps a schedule,
/// its times dimmed; on again brings it back. With none, an empty state.
struct QuietHoursPage: View {
    /// What previews show and change, since they have no app model.
    var previewQuietHours = QuietHours()

    @Environment(AppModel.self) private var model: AppModel?
    /// The previews' schedules once a switch has changed them.
    @State private var previewEdits: QuietHours?

    private let wording = QuietHoursWording(calendar: .autoupdatingCurrent)

    var body: some View {
        Group {
            if quietHours.schedules.isEmpty { emptyState } else { scheduleList }
        }
        .navigationTitle(Text(Self.title))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        ScrollView {
            ContentUnavailableView {
                EmptyStateLabel(systemImage: "bell.slash") {
                    Text("No Schedules", comment: "Quiet Hours page: title of the empty state, with no quiet hours schedule.")
                }
            } description: {
                Text("Add a schedule, and no nudge arrives while it runs.", comment: "Quiet Hours page: under \"No Schedules\".")
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var scheduleList: some View {
        List {
            Section {
                // A schedule is known by its place in the list, the order they were added.
                ForEach(Array(quietHours.schedules.enumerated()), id: \.offset) { index, schedule in
                    Toggle(isOn: isOn(index)) {
                        SettingsRow(
                            tile: .tileGray,
                            symbol: "clock",
                            title: Text(wording.range(schedule)),
                            titleColor: schedule.isOn ? Color(uiColor: .label) : Color(uiColor: .secondaryLabel),
                            value: Text(wording.days(schedule)),
                            valueFont: .subheadline
                        )
                    }
                    // One element: the schedule's words, then the switch's state.
                    .accessibilityLabel(Text(wording.spoken(schedule)))
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
        }
    }

    /// The page's title, and the Settings row that opens it.
    static let title = LocalizedStringResource("Quiet Hours", comment: "Settings: the row that opens the Quiet Hours page, and that page's title.")

    private var quietHours: QuietHours {
        model?.quietHours ?? previewEdits ?? previewQuietHours
    }

    /// The model's switch, which writes the record so the re-plan follows. Without a model, the previews'.
    private func isOn(_ index: Int) -> Binding<Bool> {
        Binding {
            quietHours.schedules.indices.contains(index) && quietHours.schedules[index].isOn
        } set: { on in
            if let model {
                model.setQuietHoursSchedule(at: index, on: on)
            } else {
                var changed = quietHours
                changed.switchSchedule(at: index, on: on)
                previewEdits = changed
            }
        }
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
