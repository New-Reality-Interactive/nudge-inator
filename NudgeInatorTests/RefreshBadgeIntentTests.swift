import AppIntents
@testable import NudgeShared
import Testing

/// The alarm's Stop intent through its one seam: `perform()`, with the refresher set by hand. The
/// system resolves the one the app registers only inside its own run of the intent, and the
/// simulator runs no App Intent from an alarm (ticket 02), so that path is a device check.
@MainActor
struct RefreshBadgeIntentTests {
    @Test func performAsksTheAppToRefreshTheBadgeOnce() async throws {
        let refreshes = RefreshCount()
        let intent = RefreshBadgeIntent()
        intent.refresher = BadgeRefresher { await refreshes.record() }

        _ = try await intent.perform()

        #expect(await refreshes.count == 1)
    }

    /// AlarmKit's `stopIntent` takes only a `LiveActivityIntent`. `.background`, so Stop doesn't
    /// open the app, and hidden from Siri, Spotlight and Shortcuts, where it means nothing.
    @Test func itIsALiveActivityIntentThatRunsInTheBackgroundAndIsntOfferedElsewhere() {
        let intent: any LiveActivityIntent = RefreshBadgeIntent()

        #expect(type(of: intent).supportedModes == .background)
        #expect(type(of: intent).isDiscoverable == false)
    }
}

/// How many times the refresher ran, across its `Sendable` boundary.
private actor RefreshCount {
    private(set) var count = 0

    func record() {
        count += 1
    }
}
