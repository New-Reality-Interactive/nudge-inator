import SwiftUI

/// The Filter button, in the bar beside New Reminder in both orientations (the filter-badge
/// mockup): an icon that turns accent-colored while the filter is on, with the system's badge
/// showing how many tags are chosen. A count of 0 hides the badge.
///
/// At the accessibility text sizes there is no badge. The bar's icons stay bar-sized, but on iOS 27
/// the system draws the badge at the text size, so it covers the icon (an iPhone on iOS 27.0.1 and
/// the iOS 27.0 simulator; not the iOS 26.5 simulator). There the chosen-tag tokens and the
/// VoiceOver label carry the count.
struct MyDayFilterButton: View {
    /// How many tags (or No Tags) are chosen.
    let chosen: Int
    /// Whether the badge shows. False at the accessibility text sizes. The caller says, since inside
    /// a toolbar the Dynamic Type size is the bar's, which stays below them.
    var showsBadge = true
    let open: () -> Void

    /// A custom symbol in the asset catalog: the Tags tab's tag with a filter badge, so it says it
    /// filters by tags.
    private static let symbol = "tag.filter"

    private var badgeCount: Int { showsBadge ? chosen : 0 }

    var body: some View {
        Button(action: open) {
            Image(Self.symbol)
        }
        .badge(badgeCount)
        // The toolbar kept showing the old badge when a token took the count down (the iPhone and the
        // simulator, ticket 19), though the tint followed, so each count is its own button.
        .id(badgeCount)
        // The bar draws its icons monochrome, so the accent is set here, and only while the filter is
        // on, when the color means something (WWDC25, "Build a SwiftUI app with the new design").
        .tint(chosen > 0 ? Color.accentColor : nil)
        .accessibilityLabel(Text("Filter by Tags", comment: "VoiceOver label of My Day's filter button."))
        // The count is the value, not part of the label: with it in the label, VoiceOver read it twice,
        // the badge adding its own after the label (an iPhone, iOS 27.0.1, ticket 19).
        .accessibilityValue(value)
    }

    private var value: Text {
        if chosen > 0 {
            Text("\(chosen) chosen", comment: "VoiceOver value of My Day's filter button while tags are chosen. The placeholder is how many.")
        } else {
            Text(verbatim: "")
        }
    }
}

/// The chosen tags as DESIGN.md's filter tokens, each removing itself when tapped, with Clear
/// beside them from two on, then the summary line.
struct MyDayFilterTokens: View {
    let tokens: [MyDayScreen.FilterToken]
    let summary: LocalizedStringResource?
    let remove: (MyDayScreen.FilterToken) -> Void
    let clear: () -> Void

    var body: some View {
        if !tokens.isEmpty {
            VStack(alignment: .leading, spacing: Design.Spacing.s2) {
                FlowLayout {
                    ForEach(tokens) { token in
                        FilterTokenView(token: token) { remove(token) }
                    }
                    if tokens.count > 1 {
                        Button(action: clear) {
                            Text("Clear", comment: "My Day: removes every tag from the filter.")
                                .frame(minHeight: Design.Spacing.rowMin)
                        }
                    }
                }
                if let summary {
                    Text(summary)
                        .subheadStyle()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Filtering by", comment: "VoiceOver label of the group of tokens for the tags My Day is filtered by."))
        }
    }
}

/// DESIGN.md's `filter-token`: a 44 pt capsule on the tertiary fill with the tag and an `xmark`.
private struct FilterTokenView: View {
    let token: MyDayScreen.FilterToken
    let remove: () -> Void

    var body: some View {
        Button(action: remove) {
            HStack(spacing: Design.Spacing.s2) {
                switch token.kind {
                case .tag:
                    Text(verbatim: token.tagText ?? "")
                case .noTags:
                    Text("No Tags", comment: "My Day: the filter token that shows only reminders without tags.")
                }
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, Design.Spacing.s3)
            .frame(minHeight: Design.Spacing.rowMin)
            .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var label: Text {
        switch token.kind {
        case .tag:
            Text("Remove \(token.tagText ?? "") from the filter", comment: "VoiceOver label of a tag's filter token on My Day. The placeholder is the tag, such as \"#home\".")
        case .noTags:
            Text("Remove No Tags from the filter", comment: "VoiceOver label of My Day's No Tags filter token.")
        }
    }
}

#Preview("Filter button and tokens") {
    VStack(alignment: .leading, spacing: Design.Spacing.s3) {
        MyDayFilterButton(chosen: 0) {}
        MyDayFilterButton(chosen: 2) {}
        MyDayFilterTokens(
            tokens: [
                .init(kind: .tag(UUID()), tagText: "#health"),
                .init(kind: .tag(UUID()), tagText: "#work"),
            ],
            summary: LocalizedStringResource("Due today with \("#health and #work")", comment: "My Day: under the filter tokens when two or more tags are chosen. The placeholder lists them, such as \"#home and #money\" (Match All) or \"#home or #money\" (Match Any)."),
            remove: { _ in },
            clear: {}
        )
        MyDayFilterTokens(tokens: [.init(kind: .noTags, tagText: nil)], summary: nil, remove: { _ in }, clear: {})
    }
    .padding()
}
