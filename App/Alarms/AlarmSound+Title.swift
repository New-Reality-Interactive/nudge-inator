import Foundation
import NudgeEngine

extension AlarmSound {
    /// The sound's name on screen: the picker's rows, and the Settings and form rows that show the
    /// current choice. The engine knows only the IDs.
    var title: LocalizedStringResource {
        switch self {
        case .default: LocalizedStringResource("Default Alarm", comment: "Alarm sound name: iOS's own alarm sound, the first choice in the alarm sound list.")
        case .chime: LocalizedStringResource("Chime", comment: "Alarm sound name: a gentle chime tone that ships with the app.")
        case .bell: LocalizedStringResource("Bell", comment: "Alarm sound name: a bell tone that ships with the app.")
        case .pulse: LocalizedStringResource("Pulse", comment: "Alarm sound name: a pulsing beep tone that ships with the app.")
        case .beacon: LocalizedStringResource("Beacon", comment: "Alarm sound name: a beacon-like signal tone that ships with the app.")
        case .rise: LocalizedStringResource("Rise", comment: "Alarm sound name: a tone that rises in pitch, shipped with the app.")
        case .siren: LocalizedStringResource("Siren", comment: "Alarm sound name: the most insistent tone that ships with the app, like a siren.")
        }
    }
}
