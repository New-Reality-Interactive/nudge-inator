import SwiftUI

/// Settings' About page (spec stories 43 and 46): the privacy policy and support pages, opened in
/// the system browser, which Guideline 5.1.1(i) needs in the app, and the running build's version
/// and build number, so a tester's feedback names the build tested.
struct AboutPage: View {
    var build = AppBuild(bundle: .main)

    static let privacyPolicy = URL(string: "https://newrealityinteractive.com/nudge-inator/privacy/")
    static let support = URL(string: "https://newrealityinteractive.com/nudge-inator/support/")

    var body: some View {
        List {
            Section {
                if let privacyPolicy = Self.privacyPolicy {
                    link(
                        to: privacyPolicy,
                        symbol: "hand.raised",
                        title: Text("Privacy Policy", comment: "About page: row that opens the app's privacy policy on the website, in the web browser.")
                    )
                }
                if let support = Self.support {
                    link(
                        to: support,
                        symbol: "questionmark.circle",
                        title: Text("Support", comment: "About page: row that opens the app's support page on the website, in the web browser.")
                    )
                }
            } footer: {
                Text("These pages open in your web browser.", comment: "About page: under the Privacy Policy and Support rows.")
            }
            Section {
                buildInfoRow(
                    label: Text("Version", comment: "About page: row showing the app's version, such as \"1.1.0\"."),
                    value: build.version
                )
                buildInfoRow(
                    label: Text("Build", comment: "About page: row showing the app's build number, such as \"12\"."),
                    value: build.buildNumber
                )
            } header: {
                Text("This Build", comment: "About page: header of the section with the app's version and build number.")
            } footer: {
                Text("When you send feedback, include the version and build.",
                     comment: "About page: under the version and build number, for beta testers sending feedback.")
            }
        }
        .centeredInReadableColumn()
        .navigationTitle(Text("About", comment: "Title of the page in Settings with the privacy policy, support and the app's version."))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// `Link` opens the URL in the system browser. The docs don't say it carries VoiceOver's link
    /// trait, so it is added.
    private func link(to url: URL, symbol: String, title: Text) -> some View {
        Link(destination: url) {
            SettingsRow(tile: .tileGray, symbol: symbol, title: title, titleColor: .accentColor, accessory: .link)
        }
        .accessibilityAddTraits(.isLink)
    }

    /// On the iPhone, VoiceOver read `LabeledContent`'s label and value as two stops, so the row is
    /// one element with the label and value set on it ("Version, 1.1.0").
    private func buildInfoRow(label: Text, value: String?) -> some View {
        let value = valueText(value)
        return LabeledContent {
            value
        } label: {
            label
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private func valueText(_ text: String?) -> Text {
        if let text {
            Text(verbatim: text)
        } else {
            Text("Unknown", comment: "About page: shown for the version or build number when the app can't read it.")
        }
    }
}

#Preview("Light") {
    NavigationStack {
        AboutPage(build: .preview)
    }
}

#Preview("Largest text") {
    NavigationStack {
        AboutPage(build: .preview)
    }
    .dynamicTypeSize(.accessibility5)
}
