import Foundation
import Testing
@testable import NudgeInator

/// The orientations and device family the built app declares (ticket 23).
struct OrientationTests {
    private let info = Bundle(for: AppDelegate.self).infoDictionary ?? [:]

    /// Upside-down stays off, and the order doesn't matter.
    @Test func theAppTurnsToPortraitAndBothLandscapes() {
        let orientations = info["UISupportedInterfaceOrientations"] as? [String]

        #expect(Set(orientations ?? []) == [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight",
        ])
        #expect(orientations?.count == 3)
    }

    /// 1 is iPhone; iPad (2) stays out of scope.
    @Test func theAppIsStillIPhoneOnly() {
        #expect(info["UIDeviceFamily"] as? [Int] == [1])
    }
}
