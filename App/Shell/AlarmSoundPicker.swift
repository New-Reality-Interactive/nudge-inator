import NudgeEngine
import SwiftUI

/// The alarm sound picker (#228, the alarm sound mockup): Default Alarm first, then the six tones,
/// a checkmark on the current choice. One page serves Settings' Default Alarm Sound and the reminder
/// form's Sound row (#230): the caller gives it its title, the current choice to save into, and any
/// footer line of its own under `footer`. A choice is saved at once, plays the whole tone as the
/// Clock app does (#229), and the page stays open. The same tap or VoiceOver double-tap does both.
/// A caller's own sections, such as Settings' Use for All Reminders (#458), go under the list.
struct AlarmSoundPicker<MoreSections: View>: View {
    let title: Text
    @Binding var sound: AlarmSound
    /// A caller's own line under `footer`, such as Settings' note on which reminders start with it.
    var extraFooter: Text?
    @ViewBuilder var moreSections: MoreSections

    @State private var preview = TonePreview(player: AudioTonePlayer())
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                ForEach(AlarmSound.allCases, id: \.self) { choice in
                    CheckmarkRow(title: Text(choice.title), isChecked: choice == sound) {
                        sound = choice
                        preview.play(choice)
                    }
                }
            } footer: {
                VStack(alignment: .leading, spacing: Design.Spacing.s2) {
                    AlarmSoundFooter.text
                    // The picker's own line, not under the form's Sound row (#229's mockup).
                    Text("Choosing a sound plays it. Default Alarm is iOS's own sound, which apps can't play, so you'll hear it when an alarm rings.",
                         comment: "Under the alarm sound list, after the line on when it plays. Default Alarm is the first sound in the list, iOS's own alarm sound.")
                    if let extraFooter { extraFooter }
                }
            }
            moreSections
        }
        // VoiceOver names the list after its page (#223's review), as My Day names its groups.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .centeredInReadableColumn()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { preview.stop() }
        // Leaving the app leaves the page too. The app has no background audio, so a preview cut off
        // there would otherwise leave other apps' audio paused.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { preview.stop() }
        }
    }
}

/// The line on when an alarm sound plays, under the picker and under the form's Sound row (#230),
/// so both say the same. Apart from the picker, which is generic and can't store a static.
enum AlarmSoundFooter {
    static let text = Text("Plays when a nudge arrives as an alarm. Other nudges use the standard notification sound.",
                           comment: "Under the alarm sound list, and under the reminder form's Sound row.")
}

extension AlarmSoundPicker where MoreSections == EmptyView {
    /// The picker alone, as the reminder form's Sound row opens it.
    init(title: Text, sound: Binding<AlarmSound>, extraFooter: Text? = nil) {
        self.init(title: title, sound: sound, extraFooter: extraFooter) { EmptyView() }
    }
}

#Preview {
    @Previewable @State var sound = AlarmSound.chime
    NavigationStack {
        AlarmSoundPicker(title: Text(verbatim: "Sound"), sound: $sound)
    }
}
