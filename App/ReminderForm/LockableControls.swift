import SwiftUI

/// A section that is one segmented choice, as Strength and Pace are: its label as the heading,
/// the segments, any rows that follow them, and a footer. Locked while nudging, the heading and
/// the label carry the `lock` and the segments are dimmed.
struct SegmentedChoiceSection<Selection: Hashable, Options: View, Rows: View, Footer: View>: View {
    let label: Text
    @Binding var selection: Selection
    let isLocked: Bool
    @ViewBuilder let options: () -> Options
    @ViewBuilder let rows: () -> Rows
    @ViewBuilder let footer: () -> Footer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Section {
            Picker(selection: $selection) {
                options()
            } label: {
                LockableLabel(isLocked: isLocked) { label }
            }
            .segmentedPickerStyle(isMenu: dynamicTypeSize.isAccessibilitySize)
            .lockedWhileNudging(isLocked)
            rows()
        } header: {
            if !dynamicTypeSize.isAccessibilitySize {
                // VoiceOver reads the segments without the picker's label (device check, ticket
                // 25), so the heading names them. At accessibility sizes the menu carries it.
                LockableLabel(isLocked: isLocked) { label }
            }
        } footer: {
            footer()
        }
    }
}

extension SegmentedChoiceSection where Rows == EmptyView {
    /// A choice with no rows after its segments, as Strength is.
    init(
        label: Text,
        selection: Binding<Selection>,
        isLocked: Bool,
        @ViewBuilder options: @escaping () -> Options,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.init(label: label, selection: selection, isLocked: isLocked, options: options, rows: { EmptyView() }, footer: footer)
    }
}

/// A row whose value is locked while nudging: plain text, without the arrows or chevron of the
/// control it replaces, read by VoiceOver as one element with the lock's reason as its hint.
struct LockedValueRow: View {
    let label: Text
    let value: Text

    var body: some View {
        LabeledContent {
            value
        } label: {
            LockableLabel(isLocked: true) { label }
        }
        .accessibilityElement(children: .combine)
        .lockedWhileNudging(true)
    }
}

/// A control's label, with the `lock` glyph after it while the field is locked.
struct LockableLabel<Content: View>: View {
    let isLocked: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: Design.Spacing.s1) {
            content()
            if isLocked { LockGlyph() }
        }
    }
}
