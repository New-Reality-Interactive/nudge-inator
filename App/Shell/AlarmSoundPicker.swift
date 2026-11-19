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
        // VoiceOver names the list after its page (#223's review), as My Day names its groups.
        // Kept unless the VoiceOver device check finds it adds a stop that repeats the title.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .centeredInReadableColumn()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    @Previewable @State var sound = AlarmSound.chime
    NavigationStack {
        AlarmSoundPicker(title: Text(verbatim: "Sound"), sound: $sound)
    }
}
