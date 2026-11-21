import Foundation

/// The sound a reminder's alarms ring with (GLOSSARY.md, Alarm sound): the standard one, or one of
/// six tones the app ships. The engine knows only the choice and its saved ID, nothing of files or
/// AlarmKit; the app maps a choice to the file or the system sound.
public enum AlarmSound: Equatable, Hashable, CaseIterable, Sendable {
    /// The standard alarm sound, which alarms ring with unless a tone is chosen. Its name on screen
    /// is "Default Alarm"; not to be confused with the Default alarm sound setting.
    case `default`
    case chime
    case bell
    case pulse
    case beacon
    case rise
    case siren

    /// The ID that is saved, so a tone can be renamed or replaced without breaking a saved reminder.
    /// Never change one.
    public var id: String {
        switch self {
        case .default: "default"
        case .chime: "chime"
        case .bell: "bell"
        case .pulse: "pulse"
        case .beacon: "beacon"
        case .rise: "rise"
        case .siren: "siren"
        }
    }

    /// The sound saved under `id`. An ID this build doesn't recognize, such as one a newer build
    /// saved, reads as Default, so a reminder never fails to load over its sound.
    public init(id: String) {
        self = Self.allCases.first { $0.id == id } ?? .default
    }
}
