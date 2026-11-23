import SwiftUI

extension EnvironmentValues {
    /// The line under the holding banner's title while quiet hours are holding nudges, or nil while
    /// nothing is held (#499). Each of Now, My Day and Reminders sets it from the minute's clock, and
    /// every banner below reads it, so none needs it passed down.
    @Entry var quietHoursHoldingDetail: LocalizedStringResource?
}

/// The banner on Now, My Day and Reminders while quiet hours are holding nudges (#499, the approved
/// Quiet hours banner mockup): the permission banner's card with a gray border and `bell.slash`,
/// since being held is the person's own choice, not a problem to fix. It isn't tappable: it says in
/// words where to change quiet hours, so a tap never leaves the tab. VoiceOver reads it as one note.
struct QuietHoursBannerView: View {
    @Environment(\.quietHoursHoldingDetail) private var detail

    var body: some View {
        if let detail {
            BannerCard(systemImage: "bell.slash", text: text(detail), borderColor: .neutral) {}
                .textCase(nil)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(Self.spoken(detail)))
                // In a header, but not one itself.
                .accessibilityRemoveTraits(.isHeader)
        }
    }

    private static let title = LocalizedStringResource("Quiet hours are holding nudges", comment: "Banner on Now, My Day and Reminders while quiet hours are holding nudges: its bold title.")

    /// What VoiceOver reads: the title, a pause, then the detail. On screen the two are on separate
    /// lines, which VoiceOver reads as one run (#379's phone check).
    static func spoken(_ detail: LocalizedStringResource) -> LocalizedStringResource {
        let title = String(localized: Self.title)
        let detail = String(localized: detail)
        return LocalizedStringResource("\(title). \(detail)", comment: "VoiceOver label of the holding banner on Now, My Day and Reminders. 1: its title, \"Quiet hours are holding nudges\". 2: its detail, such as \"Until 7:00 AM. Change this in Settings, under Quiet Hours.\"")
    }

    /// The bold title, then the detail in the secondary label color, on its own line.
    private func text(_ detail: LocalizedStringResource) -> Text {
        var title = AttributedString(localized: Self.title)
        title.inlinePresentationIntent = .stronglyEmphasized
        var detail = AttributedString(localized: detail)
        detail.foregroundColor = Color(uiColor: .secondaryLabel)
        return Text(title + AttributedString("\n") + detail)
    }
}

extension View {
    /// Sets what the holding banners below read, from the minute's clock (#499). Each of Now, My Day
    /// and Reminders applies it inside its `TimelineView`.
    func quietHoursHolding(_ model: AppModel?, at date: Date) -> some View {
        environment(\.quietHoursHoldingDetail, model?.quietHoursHoldingDetail(at: date))
    }
}

/// The banner above an empty state on Reminders, in the list's margins, as the sharing banner is.
struct QuietHoursBannerAboveEmptyState: View {
    @Environment(\.quietHoursHoldingDetail) private var detail

    var body: some View {
        if detail != nil {
            QuietHoursBannerView()
                .padding(.horizontal, Design.Spacing.s4)
                .padding(.top, Design.Spacing.s3)
        }
    }
}

#Preview("Holding") {
    QuietHoursBannerView()
        .environment(\.quietHoursHoldingDetail, QuietHoursWording(calendar: .current).holdingBannerDetail(.quietUntil(.now.addingTimeInterval(3600)), quietNowSince: nil))
        .padding()
}

#Preview("Largest text, dark") {
    QuietHoursBannerView()
        .environment(\.quietHoursHoldingDetail, QuietHoursWording(calendar: .current).holdingBannerDetail(.off, quietNowSince: .now))
        .padding()
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}
