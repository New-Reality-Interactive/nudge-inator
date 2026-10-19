import NudgeEngine
import Testing
import UIKit
@testable import NudgeInator

/// Which permission banners show (ticket 31), worked out from `Engine.reach` so they say what the
/// plan does, as the mockup's `permBanner`. The reaches come from a real engine, so a test can't
/// pass on a `Reach` the engine never produces.
struct PermissionBannerTests {
    func banners(_ permissions: PermissionStates) -> [PermissionBanner] {
        let engine = Engine(clock: FakeClock(now: .now), scheduler: FakeScheduler(), permissions: permissions)
        return PermissionBanner.banners(for: engine.reach)
    }

    @Test(arguments: [
        (PermissionStates(alarms: .allowed), [PermissionBanner]()),
        // Not asked yet is no problem to flag: onboarding asks.
        (PermissionStates(alarms: .notDetermined), []),
        (PermissionStates(alarms: .denied), [.alarmsOff(urgentIsTimeSensitive: true)]),
        (PermissionStates(alarms: .allowed, timeSensitive: .off), [.timeSensitiveOff]),
        // Both can show together.
        (PermissionStates(alarms: .denied, timeSensitive: .off), [.alarmsOff(urgentIsTimeSensitive: false), .timeSensitiveOff]),
        // Notifications off replaces the others: it already says what can still reach you.
        (PermissionStates(notifications: .denied, alarms: .allowed), [.notificationsOff(urgentStillRings: true)]),
        (PermissionStates(notifications: .denied, alarms: .denied, timeSensitive: .off), [.notificationsOff(urgentStillRings: false)]),
    ])
    func theBannersFollowWhatCanStillReachThePerson(permissions: PermissionStates, expected: [PermissionBanner]) {
        #expect(banners(permissions) == expected)
    }

    /// Alarms are turned on in the app's own page; the others in its notification settings.
    @Test(arguments: [
        (PermissionBanner.notificationsOff(urgentStillRings: true), UIApplication.openNotificationSettingsURLString),
        (.alarmsOff(urgentIsTimeSensitive: true), UIApplication.openSettingsURLString),
        (.timeSensitiveOff, UIApplication.openNotificationSettingsURLString),
    ])
    func openSettingsGoesWhereThatPermissionIsChanged(banner: PermissionBanner, urlString: String) {
        #expect(banner.openSettings.urlString == urlString)
    }
}
