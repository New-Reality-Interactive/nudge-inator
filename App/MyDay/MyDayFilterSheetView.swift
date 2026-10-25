import NudgeEngine
import SwiftUI

/// The filter sheet, the mockup's `dayFilterSheet`: check tags, choose Match All or Any (from two
/// tags), or No Tags. Changes apply as they are made, so My Day behind it follows, and Clear is the
/// bar's leading button.
struct MyDayFilterSheetView: View {
    let engine: Engine
    @Binding var filter: MyDayFilter

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var listHeight = NeverShorter()

    var body: some View {
        let sheet = MyDayFilterSheet(engine: engine, filter: filter)
        NavigationStack {
            List {
                // Always shown, so checking a tag doesn't move the rows under the finger.
                Section {
                    matchPicker(canChoose: sheet.canChooseMatch)
                }
                Section {
                    if sheet.tags.isEmpty {
                        EmptyRow(text: Text("No tags yet. Add them when you edit a reminder.", comment: "My Day's filter sheet: the Tags list when no tag exists."))
                    }
                    ForEach(sheet.tags) { row in
                        CheckmarkRow(title: Text(verbatim: row.text), isChecked: row.isChecked) { filter.toggle(row.id) }
                    }
                } header: {
                    Text("Tags", comment: "My Day's filter sheet: header of the list of tags.")
                } footer: {
                    Text(sheet.tagsFooter)
                }
                Section {
                    noTagsRow(isChecked: sheet.isNoTagsChecked)
                } footer: {
                    Text(sheet.result)
                        .padding(.bottom, listHeight.extra)
                }
            }
            .onScrollGeometryChange(for: CGSize.self) { geometry in
                CGSize(width: geometry.containerSize.width, height: geometry.contentSize.height)
            } action: { _, size in
                listHeight.update(width: size.width, height: size.height)
            }
            .onChange(of: dynamicTypeSize) {
                listHeight = NeverShorter()
            }
            .navigationTitle(Text("Filter My Day", comment: "Title of My Day's tag filter sheet."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        filter.clearTags()
                    } label: {
                        Text("Clear", comment: "My Day's filter sheet: removes every tag from the filter.")
                    }
                    .disabled(!filter.hasTags)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        dismiss()
                    } label: {
                        Text("Done", comment: "My Day's filter sheet: closes the sheet.")
                    }
                }
            }
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
    @ViewBuilder private func matchPicker(canChoose: Bool) -> some View {
        let label = Text("Match", comment: "My Day's filter sheet: label of the choice between All Tags and Any Tag.")
        let reason = Text("Needs two or more checked tags.", comment: "My Day's filter sheet: VoiceOver's reason the Match choice is disabled.")
        let picker = Picker(selection: $filter.match) {
            matchText(.all).tag(MyDayFilter.Match.all)
            matchText(.any).tag(MyDayFilter.Match.any)
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
                .accessibilityValue(matchText(filter.match))
                .accessibilityHint(reason)
        }
    }

    private func matchText(_ match: MyDayFilter.Match) -> Text {
        switch match {
        case .all: Text("All Tags", comment: "My Day's filter sheet: the Match choice that needs every checked tag.")
        case .any: Text("Any Tag", comment: "My Day's filter sheet: the Match choice that needs at least one checked tag.")
        }
    }

    /// Keeps the list from getting shorter while the sheet is open (ticket 23). A tap that shortens
    /// the text under the tags, such as No Tags dropping the Match explanation, would otherwise make
    /// a list scrolled to its end scroll back, moving every row under the finger. Blank space at
    /// the end makes up the difference. A new width, from turning the phone, or a new text size
    /// starts again.
    private struct NeverShorter {
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

    private func noTagsRow(isChecked: Bool) -> some View {
        Button {
            filter.toggleNoTags()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Design.Spacing.line) {
                    Text("No Tags", comment: "My Day's filter sheet: the row that shows only reminders without tags.")
                        .foregroundStyle(Color(uiColor: .label))
                    Text("Only reminders without tags", comment: "My Day's filter sheet: under No Tags.")
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

#if DEBUG
#Preview("Filter sheet") {
    var filter = MyDayFilter()
    let engine = Engine.myDayPreview()
    if let first = engine.tags.first { filter.toggle(first.id) }
    return MyDayFilterSheetView(engine: engine, filter: .constant(filter))
}
#endif
