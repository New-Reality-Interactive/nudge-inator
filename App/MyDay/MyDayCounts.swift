import NudgeEngine
import SwiftUI

extension MyDayCount {
    /// The count's caption, and the word in "Showing only Missed".
    var title: LocalizedStringResource {
        switch self {
        case .done: LocalizedStringResource("Done", comment: "My Day: the caption of the count of occurrences done today.")
        case .nudging: LocalizedStringResource("Nudging", comment: "My Day: the caption of the count of occurrences nudging now.")
        case .missed: LocalizedStringResource("Missed", comment: "My Day: the caption of the count of occurrences missed today.")
        case .left: LocalizedStringResource("Left", comment: "My Day: the caption of the count of occurrences still to come today.")
        }
    }

    /// DESIGN.md's Counts: Done positive, Nudging and Missed negative, Left the label color.
    fileprivate var color: Color {
        switch self {
        case .done: .positive
        case .nudging, .missed: .negative
        case .left: Color(uiColor: .label)
        }
    }
}

/// DESIGN.md's Counts (My Day): four cells, Done, Nudging, Missed and Left, that double as a
/// filter. In landscape they are capsules in a row, as the mockup's compact layout has them.
struct MyDayCounts: View {
    let counts: [MyDayScreen.Count]
    let tap: (MyDayCount) -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let compact = verticalSizeClass == .compact
        layout(compact: compact)
            .padding(compact ? 0 : Design.Spacing.s1)
            .background {
                if !compact {
                    RoundedRectangle(cornerRadius: Design.Radius.control)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Today's counts. Choose one to show only those.", comment: "VoiceOver label of the group of four counts on My Day."))
    }

    /// Four equal cells in portrait, capsules that wrap to rows in landscape. At accessibility
    /// sizes two columns, in both, so a large number and its caption aren't squeezed. Not a
    /// `LazyVGrid`: in a list row it reports too little height and the bottom is cut off.
    @ViewBuilder private func layout(compact: Bool) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            grid(columns: 2, compact: compact)
        } else if compact {
            FlowLayout(spacing: Design.Spacing.s2) {
                ForEach(counts) { cell($0, compact: true) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            grid(columns: counts.count, compact: false)
        }
    }

    private func grid(columns: Int, compact: Bool) -> some View {
        let spacing = compact ? Design.Spacing.s2 : Design.Spacing.s1
        let rows = stride(from: 0, to: counts.count, by: columns).map { Array(counts[$0..<min($0 + columns, counts.count)]) }
        return Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(rows.indices, id: \.self) { row in
                GridRow {
                    ForEach(rows[row]) { cell($0, compact: compact) }
                }
            }
        }
    }

    private func cell(_ count: MyDayScreen.Count, compact: Bool) -> some View {
        CountCell(count: count, style: compact ? .pill : .cell) { tap(count.kind) }
    }
}

private struct CountCell: View {
    enum Style {
        case cell
        case pill
    }

    let count: MyDayScreen.Count
    let style: Style
    let tap: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: tap) {
            content
                .frame(maxWidth: .infinity, minHeight: Design.Spacing.rowMin)
                .background(background)
                .overlay {
                    // Drawn at twice the width and clipped, so the whole ring is inside the cell.
                    if count.isChosen {
                        shape.stroke(Color.accentColor, lineWidth: Design.Size.ringWidth * 2)
                    }
                }
                .clipShape(shape)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!count.isEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(count.isChosen ? .isSelected : [])
    }

    @ViewBuilder private var content: some View {
        let number = Text(count.number, format: .number)
            .monospacedDigit()
            .foregroundStyle(count.number > 0 ? count.kind.color : Color(uiColor: .secondaryLabel))
        let caption = Text(count.kind.title)
            .foregroundStyle(Color(uiColor: count.isChosen ? .label : .secondaryLabel))
        // A capsule beside its number can't hold a large caption on one line: it stacks, as a cell.
        switch stackedStyle {
        case .cell:
            VStack(spacing: 0) {
                number.font(.title2.bold())
                caption.font(.caption)
            }
            .padding(.vertical, Design.Spacing.s1)
        case .pill:
            HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.s2) {
                number.font(.headline.bold())
                caption.font(.subheadline)
            }
            .padding(.horizontal, Design.Spacing.s3)
            .padding(.vertical, Design.Spacing.s2)
        }
    }

    private var stackedStyle: Style {
        dynamicTypeSize.isAccessibilitySize ? .cell : style
    }

    private var shape: AnyShape {
        switch stackedStyle {
        case .cell: AnyShape(RoundedRectangle(cornerRadius: Design.Radius.control - Design.Spacing.s1 / 2))
        case .pill: AnyShape(Capsule())
        }
    }

    @ViewBuilder private var background: some View {
        switch (style, count.isChosen) {
        case (_, true): shape.fill(Color(uiColor: .tertiarySystemFill))
        case (.pill, false): shape.fill(Color(uiColor: .secondarySystemGroupedBackground))
        case (.cell, false): Color.clear
        }
    }
}

#Preview("Counts") {
    VStack {
        MyDayCounts(counts: [
            .init(kind: .done, number: 2, isChosen: false),
            .init(kind: .nudging, number: 1, isChosen: true),
            .init(kind: .missed, number: 0, isChosen: false),
            .init(kind: .left, number: 3, isChosen: false),
        ]) { _ in }
    }
    .padding()
}
