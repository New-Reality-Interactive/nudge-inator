import NudgeEngine
import SwiftUI

/// A filter sheet's tag sections, the mockup's `dayFilterSheet`: Match All or Any (from two tags),
/// the tags, and No Tags, on My Day and on Reminders.
struct TagChoiceSections<NoTagsFooter: View>: View {
    @Binding var choice: TagChoice
    let rows: TagChoiceRows
    @ViewBuilder var noTagsFooter: NoTagsFooter

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Always shown, so checking a tag doesn't move the rows under the finger.
        Section {
            matchPicker
        }
        Section {
            if rows.rows.isEmpty {
                EmptyRow(text: Text("No tags yet. Add them when you edit a reminder.", comment: "A filter sheet: the Tags list when no tag exists."))
            }
            ForEach(rows.rows) { row in
                CheckmarkRow(title: Text(verbatim: row.text), isChecked: row.isChecked) { choice.toggle(row.id) }
            }
        } header: {
            Text("Tags", comment: "A filter sheet: header of the list of tags.")
        } footer: {
            Text(rows.footer)
        }
        Section {
            noTagsRow
        } footer: {
            noTagsFooter
        }
    }

    /// A segmented control, or a menu at accessibility sizes, where a segmented one would cut its
    /// labels off (DESIGN.md › Tags).
    ///
    /// Disabled, VoiceOver gets the reason as a hint. The menu reads "Match" and its value itself,
    /// but the segmented control reads only its segments, without "Match" or "dimmed" on the
    /// current one (iPhone 15, iOS 27.0.1), so disabled it's one element with both. That element
    /// isn't read as dimmed; the reason stands in for it. Representing it with the disabled menu
    /// (`accessibilityRepresentation`) hid it from VoiceOver altogether.
    @ViewBuilder private var matchPicker: some View {
        let canChoose = rows.canChooseMatch
        let label = Text("Match", comment: "A filter sheet: label of the choice between All Tags and Any Tag.")
        let reason = Text("Needs two or more checked tags.", comment: "A filter sheet: VoiceOver's reason the Match choice is disabled.")
        let picker = Picker(selection: $choice.match) {
            matchText(.all).tag(TagChoice.Match.all)
            matchText(.any).tag(TagChoice.Match.any)
        } label: {
            label
        }
        .disabled(!canChoose)
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
                .accessibilityHint(reason, isEnabled: !canChoose)
        } else if canChoose {
            picker.pickerStyle(.segmented)
        } else {
            picker.pickerStyle(.segmented)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityValue(matchText(choice.match))
                .accessibilityHint(reason)
        }
    }

    private func matchText(_ match: TagChoice.Match) -> Text {
        switch match {
        case .all: Text("All Tags", comment: "A filter sheet: the Match choice that needs every checked tag.")
        case .any: Text("Any Tag", comment: "A filter sheet: the Match choice that needs at least one checked tag.")
        }
    }

    private var noTagsRow: some View {
        let isChecked = rows.isNoTagsChecked
        return Button {
            choice.toggleNoTags()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Design.Spacing.line) {
                    Text("No Tags", comment: "A filter sheet: the row that shows only reminders without tags.")
                        .foregroundStyle(Color(uiColor: .label))
                    Text("Only reminders without tags", comment: "A filter sheet: under No Tags.")
                        .font(.subheadline)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                Spacer()
                if isChecked {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

/// Keeps a filter sheet's list from getting shorter while it is open (ticket 23). A tap that
/// shortens the text under the tags, such as No Tags dropping the Match explanation, would otherwise
/// make a list scrolled to its end scroll back, moving every row under the finger. Blank space at
/// the end makes up the difference. A new width, from turning the phone, or a new text size starts
/// again.
struct NeverShorter {
    private var width: CGFloat = 0
    private var tallest: CGFloat = 0
    private(set) var extra: CGFloat = 0

    /// `height` is the list's content height, `extra` included.
    mutating func update(width: CGFloat, height: CGFloat) {
        let natural = height - extra
        if width != self.width {
            self.width = width
            tallest = natural
        }
        tallest = max(tallest, natural)
        extra = tallest - natural
    }
}

extension View {
    /// Measures the list this modifies. Its last section adds `height.extra` as padding at its end.
    func neverShorter(_ height: Binding<NeverShorter>) -> some View {
        modifier(NeverShorterMeasure(height: height))
    }
}

private struct NeverShorterMeasure: ViewModifier {
    @Binding var height: NeverShorter

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGSize.self) { geometry in
                CGSize(width: geometry.containerSize.width, height: geometry.contentSize.height)
            } action: { _, size in
                height.update(width: size.width, height: size.height)
            }
            .onChange(of: dynamicTypeSize) {
                height = NeverShorter()
            }
    }
}
