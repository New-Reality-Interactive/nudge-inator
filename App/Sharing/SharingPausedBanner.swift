import NudgeEngine
import SwiftUI

/// What the screens say while sharing is paused without iCloud (ticket 210), the mockup's
/// `ICLOUD_WHY`: why, and what to do. Whole sentences per reason, so a translation keeps them
/// whole.
extension SharingReach.Pause {
    /// The banner on Connections, Send To and Sent, the lead sentence in bold.
    var bannerText: LocalizedStringResource {
        switch self {
        case .noAccount:
            LocalizedStringResource("**Sharing is paused.** Sign in to iCloud in iOS Settings to send and receive reminders. Reminders you've received keep nudging.",
                                    comment: "Sharing paused banner on Connections, Send To and Sent, when no iCloud account is signed in. Keep the first sentence bold.")
        case .restricted:
            LocalizedStringResource("**Sharing is paused.** iCloud is restricted on this iPhone. Screen Time or whoever manages it can change that. Reminders you've received keep nudging.",
                                    comment: "Sharing paused banner on Connections, Send To and Sent, when iCloud is restricted, for example by Screen Time or a device management profile. Keep the first sentence bold.")
        case .temporarilyUnavailable:
            LocalizedStringResource("**Sharing is paused.** iCloud isn't available right now. Sharing starts again by itself. Reminders you've received keep nudging.",
                                    comment: "Sharing paused banner on Connections, Send To and Sent, when iCloud can't be reached for now. Keep the first sentence bold.")
        }
    }

    /// Under the reminder form's Send To row, which is shown off.
    var sendToFooter: LocalizedStringResource {
        switch self {
        case .noAccount:
            LocalizedStringResource("Sharing is paused. Sign in to iCloud in iOS Settings to send and receive reminders.",
                                    comment: "Under the reminder form's Send To row, shown off, when no iCloud account is signed in.")
        case .restricted:
            LocalizedStringResource("Sharing is paused. iCloud is restricted on this iPhone. Screen Time or whoever manages it can change that.",
                                    comment: "Under the reminder form's Send To row, shown off, when iCloud is restricted, for example by Screen Time or a device management profile.")
        case .temporarilyUnavailable:
            LocalizedStringResource("Sharing is paused. iCloud isn't available right now. Sharing starts again by itself.",
                                    comment: "Under the reminder form's Send To row, shown off, when iCloud can't be reached for now.")
        }
    }

    /// Whether the banner offers Open Settings: not when iCloud comes back by itself.
    var offersOpenSettings: Bool {
        self != .temporarilyUnavailable
    }
}

/// DESIGN.md's sharing paused banner: the Permission banner's look in Warning, with
/// `icloud.slash`, on Connections, Send To and Sent only. Open Settings opens the app's own page in
/// iOS Settings, the one Apple documents an app can open (`openSettingsURLString`); iCloud is a
/// step back from there. Nothing while sharing works or the account isn't known yet.
struct SharingPausedBanner: View {
    let pause: SharingReach.Pause?

    var body: some View {
        if let pause {
            BannerCard(systemImage: "icloud.slash", text: Text(AttributedString(localized: pause.bannerText)), borderColor: .warning) {
                if pause.offersOpenSettings {
                    OpenSettingsButton(accessibilityLabel: Text("Open Settings for iCloud", comment: "VoiceOver label of the sharing paused banner's Open Settings button.")) {
                        SettingsStatus.OpenSettings.appSettings.open()
                    }
                }
            }
            .textCase(nil)
            // In a header, but not one itself.
            .accessibilityRemoveTraits(.isHeader)
        }
    }
}

/// The sharing paused banner above an empty state on Connections and Sent (ticket 210), in the
/// list's margins.
struct PausedBannerAboveEmptyState: View {
    let pause: SharingReach.Pause?

    var body: some View {
        SharingPausedBanner(pause: pause)
            .padding(.horizontal, Design.Spacing.s4)
            .padding(.top, Design.Spacing.s3)
    }
}

#Preview("Every reason") {
    ScrollView {
        VStack(spacing: Design.Spacing.s3) {
            SharingPausedBanner(pause: .noAccount)
            SharingPausedBanner(pause: .restricted)
            SharingPausedBanner(pause: .temporarilyUnavailable)
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Largest text") {
    ScrollView {
        SharingPausedBanner(pause: .noAccount).padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .dynamicTypeSize(.accessibility5)
}
