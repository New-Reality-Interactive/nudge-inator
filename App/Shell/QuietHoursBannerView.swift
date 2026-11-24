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
                // The title is the label and the detail the value, which VoiceOver speaks as two
                // phrases with a pause between: on screen they are two lines, and a full stop
                // inside one label gave no pause (#379's phone check).
                .accessibilityLabel(Text(Self.title))
                .accessibilityValue(Text(detail))
                // In a header, but not one itself.
                .accessibilityRemoveTraits(.isHeader)
        }
    }

    static let title = LocalizedStringResource("Quiet hours are holding nudges", comment: "Banner on Now, My Day and Reminders while quiet hours are holding nudges: its bold title.")

    /// The bold title, then the detail in the secondary label color, on its own line.
    private func text(_ detail: LocalizedStringResource) -> Text {
        // String needed: styled, the title bold.
        var title = AttributedString(localized: Self.title)
        title.inlinePresentationIntent = .stronglyEmphasized
        // String needed: styled, the detail in the secondary color.
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
