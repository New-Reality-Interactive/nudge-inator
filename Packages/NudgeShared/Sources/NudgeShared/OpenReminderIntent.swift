import AppIntents
import Foundation
import os

/// What the app does when the alarm's Open runs: stop the alarm, then show the reminder. The app
/// registers one with `AppDependencyManager` at launch. Apple: a dependency means the system
/// "can't run the app intent until the specified object is available", so an Open that launches
/// the app waits for it. A plain closure, so this module needs nothing from the app.
public struct AlarmOpener: Sendable {
    let open: @Sendable (_ alarmID: UUID, _ reminderID: UUID) async -> Void

    public init(_ open: @escaping @Sendable (_ alarmID: UUID, _ reminderID: UUID) async -> Void) {
        self.open = open
    }
}

/// The alarm's Open button. A `LiveActivityIntent`, because that is the only kind AlarmKit's
/// `secondaryIntent` takes. It lives here so the app and the widget extension both compile it.
///
/// Ticket 02's device answers decide what it does:
/// - B: tapping Open does not silence the ring. The intent has to stop the alarm (`stop(id:)`).
/// - C: on a locked phone, Open asks for Face ID or the passcode, and the ring goes on until the
///   person authenticates. Then the app opens and the stop silences it. Without the stop, the
///   alert goes away and the ring keeps going, with nothing left on screen to stop it.
/// - F: with `supportedModes = .foreground`, the intent ran in the app's process and brought the
///   app forward.
///
/// It carries the alarm's ID as well as the reminder's, because the alarm's ID is a one-way hash
/// of the nudge (`AlarmAdapter.alarmID(for:)`) and can't be turned back into the reminder.
public struct OpenReminderIntent: LiveActivityIntent {
    // Never shown to the person: the alert's button has its own text, and the intent isn't
    // discoverable. So these stay out of the String Catalogs.
    public static let title: LocalizedStringResource = "Open Reminder"
    /// "Bring the app to the foreground before the action runs." Not `openAppWhenRun`, which is
    /// deprecated in iOS 26 and "generates an error if the app intent runs in an app extension".
    public static let supportedModes: IntentModes = .foreground
    /// Kept from Siri, Spotlight and Shortcuts, where an alarm's IDs mean nothing.
    public static let isDiscoverable = false

    @Parameter(title: "Alarm ID") public var alarmID: String
    @Parameter(title: "Reminder ID") public var reminderID: String

    /// Internal so tests can set it: the system resolves it only inside its own run of the intent,
    /// and calling `perform()` without it set traps. (App Intents Testing needs iOS 27.)
    @Dependency var opener: AlarmOpener

    public init() {}

    public init(alarmID: UUID, reminderID: UUID) {
        self.alarmID = alarmID.uuidString
        self.reminderID = reminderID.uuidString
    }

    public func perform() async throws -> some IntentResult {
        // The app built both from UUIDs, so they should always parse. If one ever doesn't, the
        // app is already in front with nothing to show, so at least say why.
        guard let alarmID = UUID(uuidString: alarmID), let reminderID = UUID(uuidString: reminderID) else {
            Self.logger.error("Open got IDs that aren't UUIDs: alarm \(alarmID, privacy: .public), reminder \(reminderID, privacy: .public)")
            return .result()
        }
        await opener.open(alarmID, reminderID)
        return .result()
    }

    private static let logger = Logger(subsystem: "com.newrealityinteractive.nudgeinator", category: "OpenReminderIntent")
}
