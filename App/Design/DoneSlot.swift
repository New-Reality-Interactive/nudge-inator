import NudgeEngine
import SwiftUI

/// The place of a Done button, as one VoiceOver element that stays put after Done. With VoiceOver
/// on Done, choosing it marks the reminder Done and holds the slot, now "✓ Done", where it was
/// until VoiceOver moves on; the caller then lets the slot go. A removed button left VoiceOver's
/// cursor drawn over the empty place, and moving the cursor in code cut off what VoiceOver was
/// saying (ticket 33). Apple's advice is the same: don't remove a view while VoiceOver is on it
/// (WWDC21, "SwiftUI Accessibility: Beyond the basics").
struct DoneSlot<DoneButton: View>: View {
    let title: String
    /// Whether the slot is held after Done. Set while VoiceOver is on it, cleared once it isn't.
    @Binding var isHeld: Bool
    let markDone: () -> Void
    /// The button as the caller draws it, given the action to run.
    @ViewBuilder let button: (_ action: @escaping () -> Void) -> DoneButton

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @AccessibilityFocusState private var isFocused: Bool

    var body: some View {
        // One container, so VoiceOver's element keeps its identity when the button gives way to
        // the status inside it.
        ZStack(alignment: .leading) {
            if isHeld {
                StatusLabel(state: .done)
            } else {
                button(choose)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isHeld
            ? Text("\(title) is Done. Its nudges have stopped.", comment: "VoiceOver, after Done on a nudge card or a My Day row: what the Done button's place now says. The placeholder is the reminder's title.")
            : Text("Done, stop nudging: \(title)", comment: "VoiceOver label of the Done button on a nudge card or a My Day row. The placeholder is the reminder's title."))
        .accessibilityAddTraits(isHeld ? [] : .isButton)
        .accessibilityAction {
            if !isHeld { choose() }
        }
        // The new label is spoken after what VoiceOver is saying, not over it.
        .speechAnnouncementsQueued()
        .accessibilityFocused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if !focused { isHeld = false }
        }
        .onChange(of: voiceOverEnabled) { _, enabled in
            if !enabled { isHeld = false }
        }
        // Gone from the screen (another tab, the details popped), the focus change may never
        // arrive, and a held card would stay on Now.
        .onDisappear { isHeld = false }
    }

    /// Holds only while VoiceOver is on the slot, so a slot it never reached isn't left held.
    private func choose() {
        isHeld = voiceOverEnabled && isFocused
        markDone()
    }
}

#if DEBUG
#Preview("Done, then held") {
    VStack(alignment: .leading, spacing: Design.Spacing.s4) {
        DoneSlot(title: "Take the bins out", isHeld: .constant(false), markDone: {}) { action in
            Button(action: action) { Text(verbatim: "Done") }
                .buttonStyle(SmallBorderedButtonStyle())
        }
        DoneSlot(title: "Take the bins out", isHeld: .constant(true), markDone: {}) { action in
            Button(action: action) { Text(verbatim: "Done") }
                .buttonStyle(SmallBorderedButtonStyle())
        }
    }
    .padding()
}
#endif
