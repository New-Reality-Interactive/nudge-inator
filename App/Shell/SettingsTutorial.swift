import Foundation

/// A row in Settings' Tutorials section (#466, #467): a feature's tutorial, its title and its feature's
/// symbol. The cases are in the order the rows show.
enum SettingsTutorial: CaseIterable, Identifiable {
    case howItNudges
    case howSharingWorks
    case howAlarmSoundsWork

    var title: LocalizedStringResource {
        switch self {
        case .howItNudges: HowItNudgesTutorialPage.title
        case .howSharingWorks: SharingTutorialPage.title
        case .howAlarmSoundsWork: AlarmSoundsTutorialPage.title
        }
    }

    /// The feature's own symbol, as its other rows and pages use it.
    var symbol: String {
        switch self {
        case .howItNudges: "bell"
        case .howSharingWorks: "person.2"
        case .howAlarmSoundsWork: "speaker.wave.2"
        }
    }

    var id: Self { self }
}
