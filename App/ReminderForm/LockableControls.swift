import SwiftUI

/// A section that is one segmented choice, as Strength and Pace are: its label as the heading,
/// the segments, any rows that follow them, and a footer. Locked while nudging, the heading and
/// the label carry the `lock` and the segments are dimmed.
struct SegmentedChoiceSection<Selection: Hashable, Options: View, Rows: View, Footer: View>: View {
    let label: Text
    @Binding var selection: Selection
    /// The selected option's name, which VoiceOver reads while the choice is locked.
    let selectedTitle: Text
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
            .lockedChoiceElement(isLocked, label: label, selectedTitle: selectedTitle)
            .lockedWhileNudging(isLocked)
            rows()
        } header: {
            if !dynamicTypeSize.isAccessibilitySize {
                // Unlocked, VoiceOver reads the segments without the picker's label (device check,
                // ticket 25), so the heading names them. At accessibility sizes the menu carries it.
                // Locked, the one element carries it too.
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
        selectedTitle: Text,
        isLocked: Bool,
        @ViewBuilder options: @escaping () -> Options,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.init(label: label, selection: selection, selectedTitle: selectedTitle, isLocked: isLocked, options: options, rows: { EmptyView() }, footer: footer)
    }
}

private extension View {
    /// Locked, the choice reads as one element, its label and selected option, so the hint that
    /// `lockedWhileNudging` adds after it has an element to land on: VoiceOver reads segments one
    /// by one and never reads the picker's own hint (ticket 08's device check). Unlocked, the
    /// segments read as they always have.
    @ViewBuilder
    func lockedChoiceElement(_ isLocked: Bool, label: Text, selectedTitle: Text) -> some View {
        if isLocked {
            accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityValue(selectedTitle)
        } else {
            self
        }
    }
}

/// A stepper, as the Custom page's Every and After are. Locked, it is its label as plain text
/// without the − and +, as the Edit form's locked Every row is: iOS draws a disabled stepper's +
/// as enabled (ticket 16's simulator check). VoiceOver reads it as one element with the lock's
/// reason as its hint.
struct LockableStepper<Value: Strideable>: View {
    @Binding var value: Value
    let range: ClosedRange<Value>
    let isLocked: Bool
    let label: Text

    var body: some View {
        if isLocked {
            LockableLabel(isLocked: true) { label }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .lockedWhileNudging(true)
        } else {
            Stepper(value: $value, in: range) { label }
        }
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
