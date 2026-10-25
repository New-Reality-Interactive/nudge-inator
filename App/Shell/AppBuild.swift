import Foundation

/// The running app's version and build number, for Settings › About (spec story 46). Read from the
/// bundle at runtime, never written down: a TestFlight build's number is the one the Organizer set
/// on upload, not the repo's.
struct AppBuild {
    /// `CFBundleShortVersionString`, such as "1.1.0".
    let version: String?
    /// `CFBundleVersion`.
    let buildNumber: String?

    init(version: Any?, buildNumber: Any?) {
        self.version = version as? String
        self.buildNumber = buildNumber as? String
    }

    /// Through `object(forInfoDictionaryKey:)`, which Apple prefers to `infoDictionary`.
    init(bundle: Bundle) {
        self.init(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString"),
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion")
        )
    }

    /// What previews show, since they run without the app's bundle.
    static let preview = AppBuild(version: "1.1.0", buildNumber: "12")
}
