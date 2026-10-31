import NudgeEngine
import SwiftUI

/// A My Day row, the mockup's `.cell`: the time, the title with its tags and note, and Done while
/// Nudging or the outcome otherwise, then a chevron. The row is a button that opens the
/// reminder's details, as Now's rows are. Done is its own button beside it, not inside it: nested
/// in a link, VoiceOver merged it into the row and listed Done twice.
struct MyDayRowView: View {
    let item: MyDayScreen.Item
    let now: Date
    let openDetails: () -> Void
    let markDone: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    /// Done was chosen with VoiceOver on it, which is still there: the Done slot shows the status
    /// in the button's place, and the opener leaves it out.
    @State private var isDoneHeld = false
    /// Wide enough for "12:30 PM", so the titles line up.
    @ScaledMetric(relativeTo: .body) private var timeWidth: CGFloat = Design.Size.timeColumn

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                    opener
                    if showsDoneSlot {
                        HStack {
                            doneButton
                            Spacer(minLength: 0)
                            chevron
                        }
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.s3) {
                    opener
                    doneButton
                    chevron
                }
            }
        }
        // Without this the separator starts where the row's first text does, and under a Done
        // row that was the status label's edge, so only the right of it was drawn.
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        // Only a Nudging row has the swipe, and not while VoiceOver is running: it lists a row's
        // swipe actions among its actions whatever `accessibilityHidden` says (the phone showed
        // it), so Done would be offered twice. VoiceOver has the row's own Done button.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if item.offersDone && !voiceOverEnabled {
                SwipeDoneTile(
                    label: Text("Done", comment: "My Day: a Nudging row's swipe action that marks the reminder Done and stops its nudges."),
                    action: markDone
                )
            }
        }
    }

    /// Done, or the status that took its place while VoiceOver is on it.
    private var showsDoneSlot: Bool { item.offersDone || isDoneHeld }

    /// The time, title and note, and the outcome for a row with no Done button. All of it opens
    /// the details, and VoiceOver reads it as one element. At accessibility sizes the outcome goes
    /// under the text, with the chevron: beside it, it left the text a few letters of width.
    private var opener: some View {
        SizeAdaptiveStack(
            rowAlignment: .firstTextBaseline, rowSpacing: Design.Spacing.s3, stackedSpacing: Design.Spacing.s1
        ) {
            text
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
                if !showsDoneSlot { outcome }
            } else if !showsDoneSlot {
                HStack {
                    outcome
                    Spacer(minLength: 0)
                    chevron
                }
            }
        }
        // Stacked, there's no spacer to widen it, and the row would open only where its text is.
        .frame(maxWidth: .infinity, alignment: .leading)
        .opensDetails(openDetails)
        .accessibilityElement(children: .combine)
    }

    /// DESIGN.md's Reminder row chevron, in the tertiary label color. Decorative.
    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(uiColor: .tertiaryLabel))
            .accessibilityHidden(true)
    }

    private var text: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Design.Spacing.line))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Design.Spacing.s3))
        return layout {
            time
                .frame(minWidth: stacked ? nil : timeWidth, alignment: .leading)
            titleAndDetail
        }
    }

    private var time: some View {
        Text(verbatim: item.time)
            .font(.body)
            .monospacedDigit()
    }

    private var titleAndDetail: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.line) {
            Text(verbatim: item.title)
                .font(.body)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
    }

    /// The tags, the ones the filter chose in bold, then the note.
    private var detail: AttributedString {
        let note = AttributedString(localized: item.note(at: now))
        guard !item.tags.isEmpty else { return note }
        var tags = AttributedString()
        for (index, tag) in item.tags.enumerated() {
            var text = AttributedString(index == 0 ? tag.text : " " + tag.text)
            if tag.isChosen { text.inlinePresentationIntent = .stronglyEmphasized }
            tags += text
        }
        return AttributedString(localized: "\(tags) · \(note)", comment: "My Day: under the title of a tagged reminder. 1: its tags, such as \"#home #errands\", the ones the filter chose in bold. 2: the note, such as \"Nudging · 2 nudges · next 1:15 PM\".")
    }

    /// What the row shows in place of Done: how it closed, or that it is paused. Nothing while
    /// it is still to come.
    @ViewBuilder private var outcome: some View {
        switch item.status {
        case .due(.nudging), .left:
            EmptyView()
        case .due(let state):
            StatusLabel(state: state)
        case .paused:
            PausedLabel()
        }
    }

    @ViewBuilder private var doneButton: some View {
        if showsDoneSlot {
            DoneSlot(title: item.title, isHeld: $isDoneHeld, markDone: markDone) { action in
                Button(action: action) {
                    Text("Done", comment: "My Day: the button on a Nudging row that marks the reminder Done and stops its nudges.")
                }
                .buttonStyle(SmallBorderedButtonStyle())
            }
        }
    }
}

/// The "Now, 9:07 AM" marker among the rows: a label and a line to the trailing edge.
struct NowMarkerView: View {
    let time: String

    var body: some View {
        HStack(spacing: Design.Spacing.s2) {
            Text("Now, \(time)", comment: "My Day: the marker among the rows that shows where the time is now. The placeholder is the time, such as \"1:00 PM\".")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .label))
                // The line takes what's left. Sharing the width with it broke the time mid-word
                // at accessibility sizes ("8:40 A / M", enhancement-pace ticket 15).
                .layoutPriority(1)
            Rectangle()
                .fill(Color(uiColor: .label).opacity(Design.Size.nowMarkerLineOpacity))
                .frame(height: Design.Size.nowMarkerLine)
                .accessibilityHidden(true)
        }
    }
}

#if DEBUG
#Preview("Rows") {
    let now = Calendar.current.dateInterval(of: .minute, for: .now)?.start ?? .now
    let screen = MyDayScreen(engine: .myDayPreview(), filter: MyDayFilter(), now: now)
    return NavigationStack {
        List(screen.rows) { row in
            switch row {
            case .item(let item): MyDayRowView(item: item, now: now, openDetails: {}, markDone: {})
            case .now(let time): NowMarkerView(time: time)
            }
        }
    }
}
#endif
