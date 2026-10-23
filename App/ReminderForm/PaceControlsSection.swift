import NudgeEngine
import SwiftUI

/// Escalating or Consistent, and for Consistent the Every row's wait from the engine's list: the
/// reminder form's Pace section and Settings' Default Pace page (spec story 38). Both are locked
/// while nudging.
struct PaceControlsSection<Footer: View>: View {
    @Binding var choice: PaceChoice
    @Binding var wait: TimeInterval
    var isLocked = false
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        SegmentedChoiceSection(
            label: Text("Pace", comment: "The pace choice, in the reminder form and on Settings' Default Pace page: Escalating or Consistent."),
            selection: $choice,
            isLocked: isLocked
        ) {
            ForEach(PaceChoice.allCases, id: \.self) { choice in
                Text(choice.title).tag(choice)
            }
        } rows: {
            if choice == .consistent {
                EveryRow(wait: $wait, isLocked: isLocked)
            }
        } footer: {
            footer()
        }
    }
}

/// A Consistent pace's wait. Locked, it is plain text without the menu's arrows.
private struct EveryRow: View {
    @Binding var wait: TimeInterval
    let isLocked: Bool

    var body: some View {
        let label = Text("Every", comment: "The row for a Consistent pace's wait between nudges, such as \"10 min\", in the reminder form and on Settings' Default Pace page.")
        if isLocked {
            LockedValueRow(label: label, value: Text(verbatim: HowItNudgesDuration.text(wait)))
        } else {
            Picker(selection: $wait) {
                ForEach(Pace.consistentWaits, id: \.self) { wait in
                    Text(verbatim: HowItNudgesDuration.text(wait)).tag(wait)
                }
            } label: {
                label
            }
            .pickerStyle(.menu)
        }
    }
}
