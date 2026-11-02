import SwiftUI

/// The Filter button on Reminders, in the bar: as My Day's, an icon that turns accent-colored while
/// the sheet's filters are on, with the system's badge showing how many of its sections are in use.
///
/// While any is on a tap shows a menu, Filter and Clear All Filters; with none, it opens the sheet.
/// At the accessibility text sizes there is no badge, as on My Day (`MyDayFilterButton` says why),
/// and the VoiceOver value carries the count.
struct RemindersFilterButton: View {
    /// How many of the sheet's sections are in use.
    let sectionsInUse: Int
    /// Whether the badge shows. The caller says, since inside a toolbar the Dynamic Type size is the
    /// bar's, which stays below the accessibility sizes.
    var showsBadge = true
    let open: () -> Void
    let clear: () -> Void

    private static let symbol = "line.3.horizontal.decrease"

    private var badgeCount: Int { showsBadge ? sectionsInUse : 0 }

    var body: some View {
        control
            .badge(badgeCount)
            // As on My Day: the toolbar kept showing an old badge, so each count is its own button.
            .id(badgeCount)
            .tint(sectionsInUse > 0 ? Color.accentColor : nil)
            .accessibilityLabel(Text("Filter", comment: "VoiceOver label of the Reminders tab's Filter button."))
            // The value, not the label: VoiceOver read a count in the label twice (My Day, ticket 19).
            .accessibilityValue(value)
    }

    @ViewBuilder private var control: some View {
        if sectionsInUse > 0 {
            Menu {
                Button(action: open) {
                    Label {
                        Text("Filter", comment: "Reminders tab: the item in the Filter button's menu that opens the filter sheet.")
                    } icon: {
                        Image(systemName: Self.symbol)
                    }
                }
                Button(action: clear) {
                    Label {
                        Text("Clear All Filters", comment: "Reminders tab: the item in the Filter button's menu that removes every sheet filter, and leaves the search.")
                    } icon: {
                        Image(systemName: "xmark")
                    }
                }
            } label: {
                Image(systemName: Self.symbol)
            }
        } else {
            Button(action: open) {
                Image(systemName: Self.symbol)
            }
        }
    }

    private var value: Text {
        if sectionsInUse > 0 {
            Text("\(sectionsInUse) filters on", comment: "VoiceOver value of the Reminders tab's Filter button while the sheet's filters are on. The placeholder is how many of its sections are in use.")
        } else {
            Text(verbatim: "")
        }
    }
}

#Preview("Filter button") {
    VStack(spacing: Design.Spacing.s3) {
        RemindersFilterButton(sectionsInUse: 0, open: {}, clear: {})
        RemindersFilterButton(sectionsInUse: 2, open: {}, clear: {})
    }
}
