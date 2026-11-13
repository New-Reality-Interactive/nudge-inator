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

    /// Under Couldn't Send the Reminder, when Add found sharing paused: nothing was sent, why, and
    /// what to do.
    var couldntSendText: LocalizedStringResource {
        switch self {
        case .noAccount:
            LocalizedStringResource("Nothing was sent. Sharing is paused: sign in to iCloud in iOS Settings, then try again.",
                                    comment: "The reminder form: under Couldn't Send the Reminder, when Add found no iCloud account signed in.")
        case .restricted:
            LocalizedStringResource("Nothing was sent. Sharing is paused: iCloud is restricted on this iPhone. Screen Time or whoever manages it can change that.",
                                    comment: "The reminder form: under Couldn't Send the Reminder, when Add found iCloud restricted, for example by Screen Time or a device management profile.")
        case .temporarilyUnavailable:
            LocalizedStringResource("Nothing was sent. Sharing is paused: iCloud isn't available right now. Try again in a little while.",
                                    comment: "The reminder form: under Couldn't Send the Reminder, when Add found iCloud can't be reached for now.")
        }
    }

    /// Whether the banner offers Open Settings: not when iCloud comes back by itself.
    var offersOpenSettings: Bool {
        self != .temporarilyUnavailable
    }
}

/// What the banner on Connections, Send To and Sent says (DESIGN.md, Sharing paused and offline):
/// sharing is paused without iCloud (ticket 210), or the iPhone is offline (ticket 211). Two
/// different reasons, and paused wins (`SharingModel.banner`).
enum SharingBanner: Equatable {
    case paused(SharingReach.Pause)
    case offline

    /// The banner's words, the lead sentence in bold.
    var text: LocalizedStringResource {
        switch self {
        case .paused(let pause): pause.bannerText
        case .offline:
            LocalizedStringResource("**You're offline.** Reminders you've received keep nudging. What you send or change goes when you're back online.",
                                    comment: "Offline banner on Connections, Send To and Sent, while the iPhone can't reach iCloud. Keep the first sentence bold.")
        }
    }

    var systemImage: String {
        switch self {
        case .paused: "icloud.slash"
        case .offline: "wifi.slash"
        }
    }

    /// Whether sharing is paused, which switches Invite off; offline leaves it on, as the mockup does.
    var pausesSharing: Bool {
        if case .paused = self { true } else { false }
    }

    /// Whether the banner offers Open Settings: only to sign in to iCloud or lift a restriction.
    var offersOpenSettings: Bool {
        if case .paused(let pause) = self { pause.offersOpenSettings } else { false }
    }
}

/// DESIGN.md's sharing paused and offline banner: the Permission banner's look in Warning, with
/// `icloud.slash` or `wifi.slash`, on Connections, Send To and Sent only. Open Settings opens the
/// app's own page in iOS Settings, the one Apple documents an app can open
/// (`openSettingsURLString`); iCloud is a step back from there. Nothing while sharing works and the
/// iPhone is online, or before the account is known.
struct SharingBannerView: View {
    let banner: SharingBanner?

    var body: some View {
        if let banner {
            BannerCard(systemImage: banner.systemImage, text: Text(AttributedString(localized: banner.text)), borderColor: .warning) {
                if banner.offersOpenSettings {
                    OpenSettingsButton {
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

/// The sharing banner above an empty state on Connections and Sent (tickets 210 and 211), in the
/// list's margins.
struct BannerAboveEmptyState: View {
    let banner: SharingBanner?

    var body: some View {
        SharingBannerView(banner: banner)
            .padding(.horizontal, Design.Spacing.s4)
            .padding(.top, Design.Spacing.s3)
    }
}

#Preview("Every reason") {
    ScrollView {
        VStack(spacing: Design.Spacing.s3) {
            SharingBannerView(banner: .paused(.noAccount))
            SharingBannerView(banner: .paused(.restricted))
            SharingBannerView(banner: .paused(.temporarilyUnavailable))
            SharingBannerView(banner: .offline)
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Largest text") {
    ScrollView {
        SharingBannerView(banner: .offline).padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .dynamicTypeSize(.accessibility5)
}
