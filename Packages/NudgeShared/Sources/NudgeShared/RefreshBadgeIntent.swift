import AppIntents

/// What the app does when the alarm's Stop runs: set the Icon badge to the live count. The app
/// registers one with `AppDependencyManager` at launch, as it does `AlarmOpener`. A plain closure,
/// so this module needs nothing from the app.
public struct BadgeRefresher: Sendable {
    let refresh: @Sendable () async -> Void

    public init(_ refresh: @escaping @Sendable () async -> Void) {
        self.refresh = refresh
    }
}

/// The alarm's Stop button. A `LiveActivityIntent`, because that is the only kind AlarmKit's
/// `stopIntent` takes; Apple: the system "launches your app process without opening the app,
/// performs the intent". It lives here beside `OpenReminderIntent`, so the widget extension
/// compiles every intent an alarm carries.
///
/// It only refreshes the badge. Stop still only silences the ring, and the occurrence keeps
/// nudging (ADR 0001): the intent stops, cancels and closes nothing. A Relentless reminder raises
/// the badge only when the app's code runs (spec #80, decision 6), and this is one such time.
public struct RefreshBadgeIntent: LiveActivityIntent {
    // Never shown to the person: the alert's Stop has the system's text, and the intent isn't
    // discoverable. So it stays out of the String Catalogs.
    public static let title: LocalizedStringResource = "Refresh Badge"
    /// Stop mustn't bring the app forward.
    public static let supportedModes: IntentModes = .background
    /// Kept from Siri, Spotlight and Shortcuts, where it means nothing.
    public static let isDiscoverable = false

    /// Internal so tests can set it: the system resolves it only inside its own run of the intent,
    /// and calling `perform()` without it set traps. (App Intents Testing needs iOS 27.)
    @Dependency var refresher: BadgeRefresher

    public init() {}

    public func perform() async throws -> some IntentResult {
        await refresher.refresh()
        return .result()
    }
}
