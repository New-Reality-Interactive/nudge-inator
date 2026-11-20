import Testing
@testable import NudgeInator

/// Settings' Tutorials section (#466): its rows in the order the features shipped, each with its
/// feature's symbol, as the approved mockup draws them (#465).
struct SettingsTutorialTests {
    @Test func rowsAreInTheOrderTheFeaturesShippedWithTheirFeaturesSymbols() {
        let rows = SettingsTutorial.allCases.map { "\(String(localized: $0.title)) · \($0.symbol)" }
        #expect(rows == ["How It Nudges · bell", "How Sharing Works · person.2"])
    }
}
