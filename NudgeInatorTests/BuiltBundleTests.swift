import Foundation
import Testing

/// What App Store Connect reads from the built app: the version and build number, the export
/// compliance answer and the privacy manifest. The test bundle is hosted in the app, so
/// `Bundle.main` is the app's bundle, and the widget's is the extension inside its PlugIns.
struct BuiltBundleTests {
    static let app = Bundle.main

    static var widget: Bundle? {
        app.builtInPlugInsURL
            .map { $0.appendingPathComponent("NudgeWidgets.appex") }
            .flatMap { Bundle(url: $0) }
    }

    /// The literal is the pin: a release edits this and `MARKETING_VERSION` in project.yml together.
    @Test func theVersionIs1_2_0AndTheWidgetHasTheSame() throws {
        let widget = try #require(Self.widget)

        #expect(Self.app.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == "1.2.0")
        #expect(widget.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == "1.2.0")
    }

    /// The repo's number is a placeholder: the export step or the Organizer raises it for the app and
    /// widget together on upload. They must start equal, as App Store Connect reads one number for the archive.
    @Test func theWidgetsBuildNumberIsTheApps() throws {
        let widget = try #require(Self.widget)

        let build = try #require(Self.app.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        #expect(widget.object(forInfoDictionaryKey: "CFBundleVersion") as? String == build)
    }

    /// Without this key every upload stops at the export compliance questionnaire. `NO` because
    /// the only cryptography is `Insecure.SHA1` hashing for alarm IDs.
    @Test func exportComplianceIsDeclaredAsNoNonExemptEncryption() {
        #expect(Self.app.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool == false)
    }

    /// App Store Connect turns an upload away without a manifest for the required reason APIs the
    /// app uses. `UserDefaults` is one: `CA92.1` is the app reading its own standard defaults.
    @Test func thePrivacyManifestSaysNoTrackingNoCollectedDataAndUserDefaultsForItsOwnUse() throws {
        let url = try #require(Self.app.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let manifest = try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        let accessed = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(accessed.count == 1)
        #expect(accessed.first?["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults")
        #expect(accessed.first?["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }

    /// The widget uses no required reason API, so it has no manifest (scripts/test.sh keeps
    /// `UserDefaults` out of its sources).
    @Test func theWidgetHasNoPrivacyManifest() throws {
        let widget = try #require(Self.widget)

        #expect(widget.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") == nil)
    }
}
