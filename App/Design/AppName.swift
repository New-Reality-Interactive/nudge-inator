import Foundation

extension Bundle {
    /// The name under the app's icon, in the app's language (InfoPlist.xcstrings), for text that
    /// names the app.
    static var appDisplayName: String {
        main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? ""
    }
}
