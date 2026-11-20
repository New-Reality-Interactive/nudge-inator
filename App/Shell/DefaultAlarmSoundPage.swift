import NudgeEngine
import SwiftUI

/// Settings' Default Alarm Sound page (#228): the alarm sound picker, for every new reminder, with
/// Settings' own footer line. A change applies as soon as it is made, to new reminders only. Under
/// it, Use for All Reminders (#458, the details tone and Use for All mockup) gives the reminders
/// already made the default too, after asking.
struct DefaultAlarmSoundPage: View {
    @Binding var sound: AlarmSound
    /// How many reminders Use for All Reminders would change. None dims it.
    let remindersToChange: Int
    let useForAllReminders: () -> Void

    @State private var isConfirmingUseForAll = false

    /// The Settings row's title, and this page's; How Alarm Sounds Work names it too.
    static let title = LocalizedStringResource("Default Alarm Sound", comment: "Settings: the row that opens the alarm sound list for every new reminder, and that page's title. Beside the row, the sound chosen, such as \"Chime\".")

    /// The row's title, and its confirmation's button; How Alarm Sounds Work names it too.
    static let useForAllTitle = LocalizedStringResource("Use for All Reminders", comment: "Default Alarm Sound page: the row that gives every reminder the sound chosen above, and the button in the question that asks before it does.")

    var body: some View {
        AlarmSoundPicker(
            title: Text(Self.title),
            sound: $sound,
            extraFooter: Text("New reminders, and reminders someone sends you, start with this sound.",
                              comment: "Default Alarm Sound page: under the alarm sound list, after the line on when it plays.")
        ) {
            useForAllSection
        }
    }

    private var soundName: String { Self.name(of: sound) }

    /// The sound's name, as a placeholder in the page's sentences.
    private static func name(of sound: AlarmSound) -> String { String(localized: sound.title) }

    /// The confirmation's message, counting only the reminders it changes, with its own words for
    /// one (#456's approval).
    static func useForAllMessage(changing count: Int, to sound: AlarmSound) -> LocalizedStringResource {
        LocalizedStringResource("\(count) reminders, including ones people sent you, will use \(name(of: sound)).",
                                comment: "Under the question asked before Use for All Reminders. 1: how many reminders change, only those not on the sound already. 2: the sound, such as \"Chime\".")
    }

    private var useForAllSection: some View {
        Section {
            Button {
                isConfirmingUseForAll = true
            } label: {
                Text(Self.useForAllTitle)
            }
            .disabled(remindersToChange == 0)
            // The system's confirmation dialog, from its row, as Delete Reminder asks (#286). Not
            // destructive: nothing is deleted (#456's approval). iOS places focus once it closes.
            .confirmationDialog(
                Text("Use \(soundName) for All Reminders?", comment: "Asked before Use for All Reminders on the Default Alarm Sound page. The placeholder is the sound chosen, such as \"Chime\"."),
                isPresented: $isConfirmingUseForAll,
                titleVisibility: .visible
            ) {
                Button(action: useForAllReminders) { Text(Self.useForAllTitle) }
                Button(role: .cancel) {
                } label: {
                    Text("Cancel", comment: "Leaves every reminder's sound as it is, instead of Use for All Reminders.")
                }
            } message: {
                Text(Self.useForAllMessage(changing: remindersToChange, to: sound))
            }
        } footer: {
            if remindersToChange == 0 {
                Text("Every reminder you have uses \(soundName).",
                     comment: "Default Alarm Sound page: under Use for All Reminders, dimmed because every reminder already has the sound chosen. The placeholder is that sound, such as \"Chime\".")
            } else {
                Text("Choosing a sound above leaves the reminders you already have as they are. This gives every one of them \(soundName), including reminders someone sent you.",
                     comment: "Default Alarm Sound page: under Use for All Reminders. The placeholder is the sound chosen above, such as \"Chime\".")
            }
        }
    }
}

#Preview("Default Alarm") {
    @Previewable @State var sound = AlarmSound.default
    NavigationStack {
        DefaultAlarmSoundPage(sound: $sound, remindersToChange: 3) {}
    }
}

#Preview("Every reminder on it") {
    @Previewable @State var sound = AlarmSound.chime
    NavigationStack {
        DefaultAlarmSoundPage(sound: $sound, remindersToChange: 0) {}
    }
}

#Preview("Largest text") {
    @Previewable @State var sound = AlarmSound.beacon
    NavigationStack {
        DefaultAlarmSoundPage(sound: $sound, remindersToChange: 1) {}
    }
    .dynamicTypeSize(.accessibility5)
}
