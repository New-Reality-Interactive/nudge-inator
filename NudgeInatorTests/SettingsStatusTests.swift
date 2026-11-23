import NudgeEngine
import Testing
import UIKit
@testable import NudgeInator

/// Settings' status rows and where each opens in iOS Settings, as a value of the adapters' permission
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

    /// Provisional and notifications off already read as denied badges, from the adapter.
    @Test(arguments: [
        (BadgePermission.allowed, BadgesStatus.on),
        (.denied, .off),
        (.notDetermined, .notSet),
    ])
    func theBadgesRowFollowsTheBadgeState(badges: BadgePermission, expected: BadgesStatus) {
        #expect(SettingsStatus(PermissionStates(badges: badges)).badges == expected)
    }

    @Test func onlyAStatusThatIsOffIsFlaggedAsAProblem() {
        #expect(NotificationsStatus.on.isOff == false)
        #expect(NotificationsStatus.timeSensitiveOff.isOff)
        #expect(NotificationsStatus.off.isOff)
        #expect(AlarmsStatus.on.isOff == false)
        #expect(AlarmsStatus.notSet.isOff == false)
        #expect(AlarmsStatus.off.isOff)
    }

    /// The three permission rows are shortcuts (#372): each opens where its permission is changed,
    /// whatever the states say, so a row that reads On opens Settings too.
    @Test(arguments: [
        (SettingsStatus.PermissionRow.notifications, SettingsStatus.OpenSettings.notificationSettings),
        (.alarms, .appSettings),
        (.badges, .notificationSettings),
    ])
    func eachPermissionRowOpensWhereItsPermissionIsChanged(row: SettingsStatus.PermissionRow, expected: SettingsStatus.OpenSettings) {
        #expect(row.opensSettings == expected)
    }

    @Test func theTwoDestinationsAreTheDocumentedLinks() {
        #expect(SettingsStatus.OpenSettings.notificationSettings.urlString == UIApplication.openNotificationSettingsURLString)
        #expect(SettingsStatus.OpenSettings.appSettings.urlString == UIApplication.openSettingsURLString)
    }

    @Test func theTwoDestinationsAreDifferentLinks() {
        #expect(SettingsStatus.OpenSettings.notificationSettings.urlString != SettingsStatus.OpenSettings.appSettings.urlString)
    }

    /// The footer says what the engine says reaches the person, sentence by sentence, so a language
    /// can order and join them its own way.
    @Test(arguments: [
        (
            Reach(normal: .notification, high: .timeSensitiveNotification, urgent: .alarm),
            [FooterSentence.normalIsOrdinary, .highIsTimeSensitive, .urgentRingsAsAlarms, .relentlessIsUrgent, .allowInFocus, .changeInSettings]
        ),
        (
            Reach(normal: .notification, high: .timeSensitiveNotification, urgent: .timeSensitiveNotification),
            [.normalIsOrdinary, .highIsTimeSensitive, .urgentIsTimeSensitive, .relentlessIsUrgent, .allowInFocus, .changeInSettings]
        ),
        (
            Reach(normal: .notification, high: .notification, urgent: .alarm),
            [.normalIsOrdinary, .highIsOrdinary, .urgentRingsAsAlarms, .relentlessIsUrgent, .allowInFocus, .changeInSettings]
        ),
        (
            Reach(normal: .notification, high: .notification, urgent: .notification),
            [.normalIsOrdinary, .highIsOrdinary, .urgentIsOrdinary, .relentlessIsUrgent, .allowInFocus, .changeInSettings]
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
