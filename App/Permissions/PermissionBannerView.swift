import NudgeEngine
import SwiftUI

/// DESIGN.md's Permission banner: the cell color, a 2 pt border (red for notifications off,
/// orange otherwise), an icon, a bold lead sentence and Open Settings as a small bordered button.
struct PermissionBannerView: View {
    let banner: PermissionBanner

    var body: some View {
        BannerCard(systemImage: banner.systemImage, text: banner.text, borderColor: banner.isNegative ? .negative : .warning) {
            OpenSettingsButton(accessibilityLabel: banner.openSettingsLabel) { banner.openSettings.open() }
        }
    }
}

/// The look of DESIGN.md's Permission banner, which the sharing paused banner shares (ticket 210):
/// the cell color, a 2 pt border, an icon, the text and, under it, the banner's action, if any
/// (Open Settings). At accessibility sizes the icon goes above the text.
struct BannerCard<Action: View>: View {
    let systemImage: String
    let text: Text
    let borderColor: Color
    @ViewBuilder let action: () -> Action

    var body: some View {
        SizeAdaptiveStack(rowAlignment: .firstTextBaseline, rowSpacing: Design.Spacing.controlGap,
                          stackedSpacing: Design.Spacing.s2) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(borderColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Design.Spacing.s2) {
                text
                    .font(.subheadline)
                    // In a section header, which would turn it gray.
                    .foregroundStyle(Color(uiColor: .label))
                    .fixedSize(horizontal: false, vertical: true)
                action()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Design.Spacing.s3)
        .padding(.horizontal, Design.Spacing.s4)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: shape)
        .overlay { shape.strokeBorder(borderColor, lineWidth: Design.Size.bannerBorder) }
        .accessibilityElement(children: .contain)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Design.Radius.card)
    }
}

/// A banner's Open Settings, a small bordered button. At accessibility sizes it fills the banner's
/// width, as a nudge card's Done does, its label wrapping rather than being cut to "Open…".
struct OpenSettingsButton: View {
    /// What VoiceOver calls it, since two permission banners can show at once. `nil` keeps its
    /// own words: the sharing paused banner shows alone.
    var accessibilityLabel: Text?
    let open: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: open) {
            Text("Open Settings", comment: "Permission banner and the sharing paused banner: opens the iOS Settings page where the missing permission, or iCloud, is turned on.")
                .multilineTextAlignment(.center)
        }
        .buttonStyle(SmallBorderedButtonStyle(fillsWidth: dynamicTypeSize.isAccessibilitySize))
        // At the largest sizes even the full width holds less than its two words, so the label may
        // wrap, and the whole button, background too, grows to fit it. On one line these change
        // nothing.
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(accessibilityLabel ?? Text("Open Settings", comment: "Permission banner and the sharing paused banner: opens the iOS Settings page where the missing permission, or iCloud, is turned on."))
    }
}

/// Every banner that applies, one under the other, for the top of Now, My Day and Settings.
/// Nothing when every permission is given or not yet asked for. Each screen puts it in its first
/// section's header: as a list row, iOS 26 clipped the border to the cell's rounder corners
/// (device check).
struct PermissionBanners: View {
    let reach: Reach

    var body: some View {
        let banners = PermissionBanner.banners(for: reach)
        if !banners.isEmpty {
            VStack(spacing: Design.Spacing.s3) {
                ForEach(banners, id: \.self) { PermissionBannerView(banner: $0) }
            }
            .textCase(nil)
            // In a header, but not one itself.
            .accessibilityRemoveTraits(.isHeader)
        }
    }
}

extension PermissionBanner {
    /// The mockup's banner text. One string per banner, with the lead sentence in bold, so a
    /// translation keeps both sentences whole.
    var text: Text {
        switch self {
        case .notificationsOff(urgentStillRings: true):
            Text("**Notifications are off.** Only Urgent nudges can reach you, as alarms: every Relentless nudge, and a Firm reminder's from nudge 4 with Break Through Focus on. Gentle reminders can't reach you at all.",
                 comment: "Permission banner, when notifications are off but alarms are allowed. Keep the first sentence bold.")
        case .notificationsOff(urgentStillRings: false):
            Text("**Notifications are off.** Nudges can't reach you.",
                 comment: "Permission banner, when notifications and alarms are both off. Keep the first sentence bold.")
        case .alarmsOff(urgentIsTimeSensitive: true):
            Text("**Alarms are off.** Urgent nudges, and so every Relentless nudge, now come as Time Sensitive notifications, which silent mode can mute.",
                 comment: "Permission banner, when alarms are off and Time Sensitive is on. Keep the first sentence bold.")
        case .alarmsOff(urgentIsTimeSensitive: false):
            Text("**Alarms are off.** Urgent nudges, and so every Relentless nudge, now come as ordinary notifications, which silent mode can mute and a Focus can hold.",
                 comment: "Permission banner, when alarms and Time Sensitive are both off. Keep the first sentence bold.")
        case .timeSensitiveOff:
            Text("**Time Sensitive is off.** High nudges come as ordinary notifications, so a Focus can hold them.",
                 comment: "Permission banner, when the app's Time Sensitive notifications are turned off. Keep the first sentence bold.")
        }
    }

    /// What VoiceOver calls the banner's Open Settings button.
    var openSettingsLabel: Text {
        switch self {
        case .notificationsOff:
            Text("Open Settings for notifications", comment: "VoiceOver label of the notifications-off banner's Open Settings button.")
        case .alarmsOff:
            Text("Open Settings for alarms", comment: "VoiceOver label of the alarms-off banner's Open Settings button.")
        case .timeSensitiveOff:
            Text("Open Settings for Time Sensitive notifications", comment: "VoiceOver label of the Time Sensitive-off banner's Open Settings button.")
        }
    }

    var systemImage: String {
        switch self {
        case .notificationsOff: "exclamationmark.triangle"
        case .alarmsOff: "alarm"
        case .timeSensitiveOff: "bell"
        }
    }
}

#Preview("Every banner") {
    ScrollView {
        VStack(spacing: Design.Spacing.s3) {
            PermissionBannerView(banner: .notificationsOff(urgentStillRings: true))
            PermissionBannerView(banner: .notificationsOff(urgentStillRings: false))
            PermissionBannerView(banner: .alarmsOff(urgentIsTimeSensitive: true))
            PermissionBannerView(banner: .alarmsOff(urgentIsTimeSensitive: false))
            PermissionBannerView(banner: .timeSensitiveOff)
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Largest text, dark") {
    ScrollView {
        PermissionBannerView(banner: .alarmsOff(urgentIsTimeSensitive: true))
            .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .dynamicTypeSize(.accessibility5)
    .preferredColorScheme(.dark)
}
