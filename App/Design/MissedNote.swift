import NudgeEngine
import SwiftUI

/// The Missed note (#369): under how an occurrence closed, on an occurrence that closed as Missed
/// and that quiet hours held a nudge of, how many of its nudges were held. Now's Last 24 Hours, its
/// My Day row and the reminder details' Last occurrence row show it (the mockup
/// `docs/mockups/2026-11-21-missed-note/`). The engine reads each nudge under the schedules in
/// force when it was due, so editing a schedule later leaves the note as it was.
struct MissedNote: Equatable {
    /// How many of the occurrence's nudges quiet hours held.
    var held: Int
    /// All of its nudges, held or sent.
    var total: Int

    /// `nil` unless the occurrence closed as Missed with a nudge held: the engine's rule, by which
    /// Done, Skipped, and Missed with none held have no note.
    init?(_ closed: ClosedOccurrence) {
        guard let held = closed.missedNudgesHeld else { return nil }
        self.init(held: held, total: closed.nudgesSent)
    }

    init(held: Int, total: Int) {
        self.held = held
        self.total = total
    }

    var text: LocalizedStringResource {
        LocalizedStringResource("Quiet hours held \(held) of its \(total) nudges.", comment: "Under how an occurrence closed as Missed (Now's Last 24 Hours, My Day, and Last occurrence on a reminder's details), when quiet hours held some of its nudges. 1: how many were held. 2: how many nudges it had in all, held or sent.")
    }
}

/// The note as a line under how the occurrence closed, in the subheadline and the secondary
/// label color, as the line above it is (the mockup's `heldLine`).
struct MissedNoteLine: View {
    let note: MissedNote

    var body: some View {
        Text(note.text)
            .font(.subheadline)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
    }
}
