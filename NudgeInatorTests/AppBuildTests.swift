import Foundation
import Testing
@testable import NudgeInator

/// Settings › About's version and build (testflight-readiness ticket 02): read from the running
/// app's bundle, so a TestFlight install shows the build number the Organizer set on upload. The
/// test bundle is hosted in the app, so `Bundle.main` is the app's bundle.
struct AppBuildTests {
    @Test func itShowsTheRunningBundlesVersionAndBuildNumber() throws {
        let version = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let build = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)

        let shown = AppBuild(bundle: .main)

        #expect(shown.version == version)
        #expect(shown.buildNumber == build)
    }

    /// No bundle built by Xcode lacks them, but About shows "Unknown" rather than crashing.
    @Test(arguments: [nil, 110] as [Int?])
    func withoutTheKeysAsTextItKnowsNeither(value: Int?) {
        let shown = AppBuild(version: value, buildNumber: value)

        #expect(shown.version == nil)
        #expect(shown.buildNumber == nil)
    }
}
