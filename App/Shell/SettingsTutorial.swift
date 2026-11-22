import Foundation

/// A row in Settings' Tutorials section (#466, #467, #468): a feature's tutorial, its title and its feature's
/// symbol. The cases are in the order the rows show.
enum SettingsTutorial: CaseIterable, Identifiable {
    case howItNudges
    case howSharingWorks
    case howAlarmSoundsWork
    case howQuietHoursWork

    var title: LocalizedStringResource {
        switch self {
        case .howItNudges: HowItNudgesTutorialPage.title
        case .howSharingWorks: SharingTutorialPage.title
        case .howAlarmSoundsWork: AlarmSoundsTutorialPage.title
        case .howQuietHoursWork: QuietHoursTutorialPage.title
        }
    }

    /// The feature's own symbol, as its other rows and pages use it.
    var symbol: String {
        switch self {
        case .howItNudges: "bell"
        case .howSharingWorks: "person.2"
        case .howAlarmSoundsWork: "speaker.wave.2"
        case .howQuietHoursWork: "bell.slash"
        }
    }

    var id: Self { self }
}
