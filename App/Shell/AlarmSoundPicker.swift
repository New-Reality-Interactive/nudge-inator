import NudgeEngine
import SwiftUI

/// The alarm sound picker (#228, the alarm sound mockup): Default Alarm first, then the six tones,
/// a checkmark on the current choice. One page serves Settings' Default Alarm Sound and the reminder
/// form's Sound row (#230): the caller gives it its title, the current choice to save into, and any
/// footer line of its own under `footer`. A choice is saved at once and the page stays open.
struct AlarmSoundPicker: View {
    let title: Text
    @Binding var sound: AlarmSound
    /// A caller's own line under `footer`, such as Settings' note on which reminders start with it.
    var extraFooter: Text?

    /// Under the picker and under the form's Sound row (#230), so both say the same.
    static let footer = Text("Plays when a nudge arrives as an alarm. Other nudges use the standard notification sound.",
                             comment: "Under the alarm sound list, and under the reminder form's Sound row.")

    var body: some View {
        List {
            Section {
                ForEach(AlarmSound.allCases, id: \.self) { choice in
                    CheckmarkRow(title: Text(choice.title), isChecked: choice == sound) {
                        sound = choice
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: Design.Spacing.s2) {
                    Self.footer
                    if let extraFooter { extraFooter }
                }
            }
        }
        // VoiceOver names the list after its page (#223's review), as My Day names its groups. A
        // device check: VoiceOver on the picker.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .centeredInReadableColumn()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension AlarmSoundPicker {
    /// The Settings row's title and its page's.
    static let defaultAlarmSoundTitle = Text("Default Alarm Sound", comment: "Settings: the row that opens the alarm sound list for every new reminder, and that page's title. Beside the row, the sound chosen, such as \"Chime\".")

    /// Settings' Default Alarm Sound page.
    static func defaultAlarmSound(_ sound: Binding<AlarmSound>) -> AlarmSoundPicker {
        AlarmSoundPicker(
            title: defaultAlarmSoundTitle,
            sound: sound,
            extraFooter: Text("New reminders, and reminders someone sends you, start with this sound. Reminders you already have keep theirs.",
                              comment: "Default Alarm Sound page: under the alarm sound list, after the line on when it plays.")
        )
    }
}

#Preview("Settings") {
    @Previewable @State var sound = AlarmSound.default
    NavigationStack {
        AlarmSoundPicker.defaultAlarmSound($sound)
    }
}

#Preview("Largest text") {
    @Previewable @State var sound = AlarmSound.beacon
    NavigationStack {
        AlarmSoundPicker.defaultAlarmSound($sound)
    }
    .dynamicTypeSize(.accessibility5)
}
