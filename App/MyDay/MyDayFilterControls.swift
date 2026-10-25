import SwiftUI

/// The Filter button, in the bar beside New Reminder in both orientations (the filter-badge
/// mockup): an icon that turns accent-colored while the filter is on, with the system's badge
/// showing how many tags are chosen. A count of 0 hides the badge.
///
/// While any tag (or No Tags) is chosen a tap shows a menu, Filter by Tags and Clear All Tags; with
/// none, it opens the filter sheet. Not a long press: at the accessibility text sizes the bar takes
/// that for the Large Content Viewer, and lifting the finger opens the sheet (ticket 20).
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
    /// Removes every tag and No Tags from the filter.
    let clear: () -> Void

    /// A custom symbol in the asset catalog: the Tags tab's tag with a filter badge, so it says it
    /// filters by tags.
    private static let symbol = "tag.filter"
    /// The same tag with a × badge: removes the tags.
    private static let clearSymbol = "tag.xmark"

    private var badgeCount: Int { showsBadge ? chosen : 0 }

    var body: some View {
        control
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

    @ViewBuilder private var control: some View {
        if chosen > 0 {
            Menu {
                Button(action: open) {
                    Label {
                        Text("Filter by Tags", comment: "My Day: the item in the Filter button's menu that opens the filter.")
                    } icon: {
                        Image(Self.symbol)
                    }
                }
                Button(action: clear) {
                    Label {
                        Text("Clear All Tags", comment: "My Day: the item in the Filter button's menu that removes every tag from the filter.")
                    } icon: {
                        Image(Self.clearSymbol)
                    }
                }
            } label: {
                Image(Self.symbol)
            }
        } else {
            Button(action: open) {
                Image(Self.symbol)
            }
        }
    }

    private var value: Text {
        if chosen > 0 {
            Text("\(chosen) chosen", comment: "VoiceOver value of My Day's filter button while tags are chosen. The placeholder is how many.")
        } else {
            Text(verbatim: "")
        }
    }
}

/// The chosen tags as DESIGN.md's filter tokens, each removing itself when tapped, wrapping to at
/// most three rows so the counts below stay near the top, then the summary line. Tokens past the
/// third row go into "+N more", which opens the filter sheet, where every tag is listed. Clearing
/// them all is in the Filter button's menu (ticket 20).
struct MyDayFilterTokens: View {
    let tokens: [MyDayScreen.FilterToken]
    let summary: LocalizedStringResource?
    let remove: (MyDayScreen.FilterToken) -> Void
    let openFilter: () -> Void

    private static let maxRows = 3

    /// Each token's own width, and "+N more"'s at its widest, from the hidden copies in `measured`.
    @State private var widths: [MyDayScreen.FilterToken.ID: CGFloat] = [:]
    @State private var moreWidth: CGFloat = 0
    @State private var rowWidth: CGFloat?

    /// A token not measured yet, just chosen, counts as a whole row, so the row never draws more
    /// than three rows on its way to the right count.
    private var shown: Int {
        guard let rowWidth else { return tokens.count }
        return FlowLayout().shownCount(
            widths: tokens.map { widths[$0.id] ?? rowWidth }, moreWidth: moreWidth, in: rowWidth, maxRows: Self.maxRows
        )
    }

    var body: some View {
        if !tokens.isEmpty {
            VStack(alignment: .leading, spacing: Design.Spacing.s2) {
                FlowLayout {
                    ForEach(tokens.prefix(shown)) { token in
                        FilterTokenView(token: token) { remove(token) }
                    }
                    if shown < tokens.count {
                        MoreTokenView(count: tokens.count - shown, open: openFilter)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
                .background(alignment: .topLeading) { measured }
                if let summary {
                    Text(summary)
                        .subheadStyle()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Filtering by", comment: "VoiceOver label of the group of tokens for the tags My Day is filtered by."))
        }
    }

    /// Every token at its own size, drawn hidden, so `shown` knows their widths before choosing.
    private var measured: some View {
        ZStack(alignment: .topLeading) {
            ForEach(tokens) { token in
                FilterTokenView(token: token) {}
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { widths[token.id] = $0 }
            }
            MoreTokenView(count: tokens.count, open: {})
                .fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { moreWidth = $0 }
        }
        .hidden()
        .accessibilityHidden(true)
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
            .tokenCapsule()
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

/// The token after the third row's, for the tags that didn't fit: opens the filter sheet.
private struct MoreTokenView: View {
    let count: Int
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Text("+\(count) more", comment: "My Day: the filter token after the tags that fit in three rows. The placeholder is how many more are chosen. Opens the filter.")
                .tokenCapsule()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(count) more tags", comment: "VoiceOver label of My Day's \"+N more\" filter token. The placeholder is how many more tags are chosen."))
    }
}

private extension View {
    /// DESIGN.md's `filter-token` capsule.
    func tokenCapsule() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, Design.Spacing.s3)
            .frame(minHeight: Design.Spacing.rowMin)
            .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
    }
}

#Preview("Filter button and tokens") {
    VStack(alignment: .leading, spacing: Design.Spacing.s3) {
        MyDayFilterButton(chosen: 0, open: {}, clear: {})
        MyDayFilterButton(chosen: 2, open: {}, clear: {})
        MyDayFilterTokens(
            tokens: [
                .init(kind: .tag(UUID()), tagText: "#health"),
                .init(kind: .tag(UUID()), tagText: "#work"),
            ],
            summary: LocalizedStringResource("Due today with all selected tags", comment: "My Day: under the filter tokens when two or more tags are chosen and Match is All Tags."),
            remove: { _ in },
            openFilter: {}
        )
        MyDayFilterTokens(tokens: [.init(kind: .noTags, tagText: nil)], summary: nil, remove: { _ in }, openFilter: {})
    }
    .padding()
}
