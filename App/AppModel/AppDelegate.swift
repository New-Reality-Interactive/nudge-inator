import AppIntents
import Foundation
import NudgeEngine
import NudgeShared
import UIKit

/// Builds the app model at launch. A delegate rather than the scene phase because Apple says
/// the notification center's delegate must be set "before your app finishes launching", or a
/// Done tapped on a notification that launched the app is missed. The notification adapter's
/// `init` sets it.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// `nil` when the app is only hosting tests (see `isHostingTests`). Lazy, so it is built by
    /// whichever comes first, `didFinishLaunching` or the scene reading it.
    private(set) lazy var model: AppModel? = Self.isHostingTests ? nil : Self.makeModel()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let model {
            // The alarm's Open runs `OpenReminderIntent` in this process (ticket 02 F), and reaches
            // the model through this opener. Here, as early as the model: Apple says the system
            // "can run app intents soon after your app or app extension launches".
            // Built here, on the main actor: the dependency is an autoclosure, and the docs don't
            // say which thread evaluates it.
            let opener = model.alarmOpener
            AppDependencyManager.shared.add(dependency: opener)
            // The alarm's Stop runs `RefreshBadgeIntent` in this process too (ticket 87), and
            // reaches the model through this refresher.
            let refresher = model.badgeRefresher
            AppDependencyManager.shared.add(dependency: refresher)
            Task { await model.launch() }
        }
        return true
    }

    /// The first unlock since a restart: the store, shut until now, can be read, and a Done chosen
    /// on the Lock Screen meanwhile is merged (ticket 32). Apple's docs don't say whether a
    /// suspended app gets this; App opened retries too.
    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        guard let model else { return }
        Task { await model.protectedDataBecameAvailable() }
    }

    /// Whether the app was launched to host the tests. Its own model would then plan from the
    /// real store and, on every foreground, hand the real adapters a plan that cancels the
    /// alarms the device checks schedule, and its notification delegate would replace theirs.
    /// `xcodebuild test` sets the variable for XCTest and Swift Testing alike.
    static var isHostingTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// The real wiring. The device checks pass a store and a queue of their own.
    static func makeModel(
        openStore: @escaping () throws -> ReminderStore = { try ReminderStore(location: .appGroup) },
        doneQueue: DoneQueue = .standard
    ) -> AppModel {
        let clock = SystemClock()
        return AppModel(
            clock: clock,
            openStore: openStore,
            notifications: NotificationAdapter(center: SystemNotificationCenter(), clock: clock),
            alarms: AlarmAdapter(
                manager: SystemAlarmManager(),
                clock: clock,
                openIntent: { item, alarmID in
                    OpenReminderIntent(alarmID: alarmID, reminderID: item.reminderID)
                },
                stopIntent: { RefreshBadgeIntent() }
            ),
            doneQueue: doneQueue
        )
    }
}
