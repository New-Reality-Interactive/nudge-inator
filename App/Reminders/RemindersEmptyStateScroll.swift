import SwiftUI

/// The screen around an empty state on Reminders, Mine's and Sent's: the quiet hours banner at the
/// top, under the Mine | Sent control, and the empty state centered in what is left (#379). Both
/// are one scrolling page, so the largest text sizes reach the end of it. Pinned above the scroll
/// view instead, a banner taller than the screen pushed the Mine | Sent control over the
/// "Reminders" heading (#516). The two sides share it, so switching Mine | Sent doesn't move one
/// against the other (#399's phone check).
struct RemindersEmptyStateScroll<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { visible in
            ScrollView {
                // Each part keeps its natural height: held to the visible height, text taller
                // than it would truncate where the page should grow and scroll. The inner stack
                // centers the content's parts, such as a sharing banner and its empty state, as one.
                VStack(spacing: 0) {
                    QuietHoursBannerAboveEmptyState()
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    VStack { content }
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: visible.size.height)
            }
        }
    }
}

#Preview("Holding, largest text") {
    RemindersEmptyStateScroll {
        ContentUnavailableView {
            Label {
                Text(verbatim: "No Reminders")
            } icon: {
                Image(systemName: AppTab.reminders.systemImage)
            }
        }
    }
    .environment(\.quietHoursHoldingDetail, QuietHoursWording(calendar: .current).holdingBannerDetail(.off, quietNowSince: .now))
    .dynamicTypeSize(.accessibility5)
}
