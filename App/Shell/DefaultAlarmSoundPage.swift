import NudgeEngine
import SwiftUI

/// Settings' Default Alarm Sound page (#228): the alarm sound picker, for every new reminder, with
/// Settings' own footer line. A change applies as soon as it is made.
struct DefaultAlarmSoundPage: View {
    @Binding var sound: AlarmSound

    /// The Settings row's title, and this page's.
    static let title = Text("Default Alarm Sound", comment: "Settings: the row that opens the alarm sound list for every new reminder, and that page's title. Beside the row, the sound chosen, such as \"Chime\".")

    var body: some View {
        AlarmSoundPicker(
            title: Self.title,
            sound: $sound,
            extraFooter: Text("New reminders, and reminders someone sends you, start with this sound. Reminders you already have keep theirs.",
                              comment: "Default Alarm Sound page: under the alarm sound list, after the line on when it plays.")
        )
    }
}

#Preview("Default Alarm") {
    @Previewable @State var sound = AlarmSound.default
    NavigationStack {
        DefaultAlarmSoundPage(sound: $sound)
    }
}

#Preview("Largest text") {
    @Previewable @State var sound = AlarmSound.beacon
    NavigationStack {
        DefaultAlarmSoundPage(sound: $sound)
    }
    .dynamicTypeSize(.accessibility5)
}
