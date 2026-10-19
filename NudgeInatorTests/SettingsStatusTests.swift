import NudgeEngine
import Testing
import UIKit
@testable import NudgeInator

/// Settings' status rows and its one Open iOS Settings row, as a value of the adapters' permission
/// states (ticket 30), before any view draws them.
struct SettingsStatusTests {
    @Test(arguments: [
        (PermissionStates(notifications: .allowed, timeSensitive: .on), NotificationsStatus.on),
        (PermissionStates(notifications: .allowed, timeSensitive: .off), .timeSensitiveOff),
        (PermissionStates(notifications: .denied, timeSensitive: .on), .off),
        // Time Sensitive can't be on when notifications are off, so the notifications show Off.
        (PermissionStates(notifications: .denied, timeSensitive: .off), .off),
    ])
    func theNotificationsRowFollowsTheNotificationAndTimeSensitiveStates(states: PermissionStates, expected: NotificationsStatus) {
        #expect(SettingsStatus(states).notifications == expected)
    }

    @Test(arguments: [
        (AlarmPermission.allowed, AlarmsStatus.on),
        (.denied, .off),
        (.notDetermined, .notSet),
    ])
    func theAlarmsRowFollowsTheAlarmState(alarms: AlarmPermission, expected: AlarmsStatus) {
        #expect(SettingsStatus(PermissionStates(alarms: alarms)).alarms == expected)
    }

    @Test func onlyAStatusThatIsOffIsFlaggedAsAProblem() {
        #expect(NotificationsStatus.on.isOff == false)
        #expect(NotificationsStatus.timeSensitiveOff.isOff)
        #expect(NotificationsStatus.off.isOff)
        #expect(AlarmsStatus.on.isOff == false)
        #expect(AlarmsStatus.notSet.isOff == false)
        #expect(AlarmsStatus.off.isOff)
    }

    @Test func everythingOnOrNotAskedYetOffersNoWayToOpenSettings() {
        #expect(SettingsStatus(PermissionStates(alarms: .allowed)).openSettings == nil)
        #expect(SettingsStatus(PermissionStates(alarms: .notDetermined)).openSettings == nil)
    }

    @Test(arguments: [
        PermissionStates(notifications: .denied, alarms: .allowed),
        PermissionStates(notifications: .allowed, alarms: .allowed, timeSensitive: .off),
    ])
    func deniedNotificationsOrTimeSensitiveOpenTheAppsNotificationSettings(states: PermissionStates) {
        let openSettings = SettingsStatus(states).openSettings

        #expect(openSettings == .notificationSettings)
        #expect(openSettings?.urlString == UIApplication.openNotificationSettingsURLString)
    }

    @Test(arguments: [
        PermissionStates(notifications: .allowed, alarms: .denied),
        PermissionStates(notifications: .denied, alarms: .denied),
        PermissionStates(notifications: .allowed, alarms: .denied, timeSensitive: .off),
    ])
    func deniedAlarmsOpenTheAppsPageInSettings(states: PermissionStates) {
        let openSettings = SettingsStatus(states).openSettings

        #expect(openSettings == .appSettings)
        #expect(openSettings?.urlString == UIApplication.openSettingsURLString)
    }

    @Test func theTwoDestinationsAreDifferentLinks() {
        #expect(SettingsStatus.OpenSettings.notificationSettings.urlString != SettingsStatus.OpenSettings.appSettings.urlString)
    }

    /// The footer says what the engine says reaches the person, sentence by sentence, so a language
    /// can order and join them its own way.
    @Test(arguments: [
        (
            Reach(normal: .notification, high: .timeSensitiveNotification, urgent: .alarm),
            [FooterSentence.normalIsOrdinary, .highIsTimeSensitive, .urgentRingsAsAlarms, .allowInFocus, .changeInSettings]
        ),
        (
            Reach(normal: .notification, high: .timeSensitiveNotification, urgent: .timeSensitiveNotification),
            [.normalIsOrdinary, .highIsTimeSensitive, .urgentIsTimeSensitive, .allowInFocus, .changeInSettings]
        ),
        (
            Reach(normal: .notification, high: .notification, urgent: .alarm),
            [.normalIsOrdinary, .highIsOrdinary, .urgentRingsAsAlarms, .allowInFocus, .changeInSettings]
        ),
        (
            Reach(normal: .notification, high: .notification, urgent: .notification),
            [.normalIsOrdinary, .highIsOrdinary, .urgentIsOrdinary, .allowInFocus, .changeInSettings]
        ),
        // Notifications off: Urgent nudges can still ring as alarms, but nothing else reaches the person.
        (Reach(normal: nil, high: nil, urgent: .alarm), [.changeInSettings]),
        (Reach(normal: nil, high: nil, urgent: nil), [.changeInSettings]),
    ])
    func theFooterSaysHowEachUrgencyReachesThePerson(reach: Reach, expected: [FooterSentence]) {
        #expect(SettingsStatus.footer(for: reach) == expected)
    }

    @Test func aTestNudgeCanBeSentOnlyWhileNotificationsAreAllowed() {
        #expect(SettingsStatus(PermissionStates(notifications: .allowed)).canSendTestNudge)
        #expect(SettingsStatus(PermissionStates(notifications: .allowed, timeSensitive: .off)).canSendTestNudge)
        #expect(SettingsStatus(PermissionStates(notifications: .denied)).canSendTestNudge == false)
    }
}
