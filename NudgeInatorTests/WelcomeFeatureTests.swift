import Foundation
import Testing
@testable import NudgeInator

/// The welcome's points, shown in onboarding and again on Settings' How It Nudges. Only How It
/// Nudges tells a person who updated that the alarm sound can be chosen (#459); onboarding is
/// unchanged.
struct WelcomeFeatureTests {
    @Test func howItNudgesSaysTheAlarmSoundCanBeChosen() throws {
        let note = try #require(WelcomeFeature.ringsAsAlarms.note(on: .howItNudges))
        #expect(String(localized: note) == "Choose the sound alarms ring with in Settings, under Default Alarm Sound, and for each reminder, under Sound on its form.")
    }

    @Test(arguments: WelcomeFeature.allCases)
    func onboardingAddsNothing(feature: WelcomeFeature) {
        #expect(feature.note(on: .onboarding) == nil)
    }

    @Test(arguments: [WelcomeFeature.nudgesUntilDone, .chooseWhatBreaksThrough, .staysOnYourIPhone])
    func theOtherPointsAddNothingOnHowItNudges(feature: WelcomeFeature) {
        #expect(feature.note(on: .howItNudges) == nil)
    }
}
