import Foundation

/// A row in Settings' Tutorials section (#466): a feature's tutorial, its title and its feature's
/// symbol. The cases are in the order the rows show.
enum SettingsTutorial: CaseIterable {
    case howItNudges
    case howSharingWorks

    var title: LocalizedStringResource {
        switch self {
        case .howItNudges:
            LocalizedStringResource("How It Nudges", comment: "Settings: row under Tutorials that opens the page explaining how each strength nudges, and what onboarding said.")
        case .howSharingWorks:
            LocalizedStringResource("How Sharing Works", comment: "How Sharing Works: the sheet's title, and the Settings row under Tutorials that opens it.")
        }
    }

    /// The feature's own symbol, as its other rows and pages use it.
    var symbol: String {
        switch self {
        case .howItNudges: "bell"
        case .howSharingWorks: "person.2"
        }
    }
}
