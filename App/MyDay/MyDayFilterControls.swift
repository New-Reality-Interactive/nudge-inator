import SwiftUI

/// The Filter button, in the bar beside New Reminder in both orientations (the tag-filter mockup):
/// an icon, with the number of tags chosen beside it, in the accent color, while the filter is on.
struct MyDayFilterButton: View {
    /// How many tags (or No Tags) are chosen.
    let chosen: Int
    let open: () -> Void

    /// A custom symbol in the asset catalog: a tag with filter lines, so it says it filters by tags.
    private static let symbol = "tag.filter"

    var body: some View {
        Button(action: open) {
            HStack(spacing: Design.Spacing.s1) {
                Image(Self.symbol)
                if chosen > 0 {
                    Text(chosen, format: .number)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityLabel(label)
    }

    private var label: Text {
        if chosen > 0 {
            Text("Filter by Tags, \(chosen) chosen", comment: "VoiceOver label of My Day's filter button while tags are chosen. The placeholder is how many.")
        } else {
            Text("Filter by Tags", comment: "VoiceOver label of My Day's filter button while no tag is chosen.")
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
