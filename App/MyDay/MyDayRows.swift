import NudgeEngine
import SwiftUI

/// A My Day row, the mockup's `.cell`: the time, the title with its tags and note, and Done while
/// Nudging or the outcome otherwise, then the system's chevron. The row opens the reminder's
/// details. Done keeps its own action, so it is a borderless button inside the link.
struct MyDayRowView: View {
    let item: MyDayScreen.Item
    let now: Date
    let markDone: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Wide enough for "12:30 PM", so the titles line up.
    @ScaledMetric(relativeTo: .body) private var timeWidth: CGFloat = Design.Size.timeColumn

    var body: some View {
        NavigationLink(value: OpenedReminder(id: item.reminder.id)) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                    text
                    trailing
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.s3) {
                    text
                    Spacer(minLength: 0)
                    trailing
                }
            }
        }
        // Only a Nudging row has the swipe; VoiceOver has the row's own Done button instead.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if item.offersDone {
                Button(action: markDone) {
                    Label {
                        Text("Done", comment: "My Day: a Nudging row's swipe action that marks the reminder Done and stops its nudges.")
                    } icon: {
                        Image(systemName: "checkmark")
                    }
                }
                .tint(Color.tileGreen)
                .accessibilityHidden(true)
            }
        }
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
        .accessibilityElement(children: .combine)
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

    @ViewBuilder private var trailing: some View {
        switch item.status {
        case .due(.nudging):
            Button(action: markDone) {
                Text("Done", comment: "My Day: the button on a Nudging row that marks the reminder Done and stops its nudges.")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            // Regular is 34 pt tall; every button is at least 44 (DESIGN.md › Buttons).
            .controlSize(.large)
            .accessibilityLabel(Text("Done, stop nudging: \(item.title)", comment: "VoiceOver label of the Done button on a nudge card or a My Day row. The placeholder is the reminder's title."))
        case .due(let state):
            StatusLabel(state: state)
        case .paused:
            PausedLabel()
        case .left:
            EmptyView()
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
            case .item(let item): MyDayRowView(item: item, now: now) {}
            case .now(let time): NowMarkerView(time: time)
            }
        }
    }
}
#endif
