import Foundation
import Testing
@testable import NudgeInator

/// The holding banner's VoiceOver label (#379's phone check): on screen the title and the detail are
/// on separate lines, which VoiceOver would run together.
struct QuietHoursBannerTests {
    @Test func theSpokenLabelPausesBetweenTheTitleAndTheDetail() {
        let detail = LocalizedStringResource("Until 7:00 AM. Change this in Settings, under Quiet Hours.", comment: "")

        let spoken = String(localized: QuietHoursBannerView.spoken(detail))

        #expect(spoken == "Quiet hours are holding nudges. Until 7:00 AM. Change this in Settings, under Quiet Hours.")
    }
}
