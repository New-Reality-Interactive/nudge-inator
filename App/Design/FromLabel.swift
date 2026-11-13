import NudgeEngine
import SwiftUI

/// DESIGN.md's "From <name>" label (Shared reminders), under a received reminder's title on Now's
/// cards and every list row: `person`, then "From Riley Park" in the subhead and the secondary
/// label color. Who sent it isn't a status, so it has no color of its own. On a row with no
/// strength badge of its own (My Day, Reminders, Last 24 Hours) the badge follows it, as the
/// mockup's `fromLabel(r)`, and Waiting to sync after them while it applies (ticket 211); they wrap
/// onto the next line as words do when they don't fit.
struct FromLabel: View {
    let from: FromLine
    /// The strength badge to follow the label, or `nil` where the row already shows one.
    var strength: Strength?

    var body: some View {
        if strength == nil && !from.waitsToSync {
            name
        } else {
            // The pieces flow and wrap as words do, as the mockup's `fromline` does: what fits on a
            // line stays there (#211's phone check: all or nothing stacked each piece alone).
            FlowLayout(spacing: Design.Spacing.s2, lineSpacing: Design.Spacing.line) { parts }
        }
    }

    /// The name, then the strength badge where the row has none, then Waiting to sync (ticket 211)
    /// while it applies, as the mockup's `fromLabel`.
    @ViewBuilder private var parts: some View {
        name
        if let strength {
            StrengthBadge(strength: strength)
        }
        if from.waitsToSync {
            WaitingToSyncLabel(weight: .regular)
        }
    }

    private var name: some View {
        HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.s1) {
            // The words say who; the glyph only shows it.
            Image(systemName: "person")
                .accessibilityHidden(true)
            Text(from.label)
                // It wraps, never truncates: when neither of `ViewThatFits`'s layouts fits (the
                // largest text sizes), the stacked one could get one line's height, and the phone
                // showed "From Riley…" (#199's phone check).
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .foregroundStyle(Color(uiColor: .secondaryLabel))
    }
}

#if DEBUG
/// "From Riley Park", as `Senders` writes it, so the previews add no string to the catalog.
private let previewFrom: FromLine = {
    let connectionID = UUID()
    let reminder = Reminder(
        title: "Take the pills",
        dueTime: .now,
        strength: .gentle,
        origin: .received(connectionID: connectionID, sendersReminderID: UUID(), revision: 0, state: .accepted)
    )
    let senders = Senders(connections: [SharingConnection(id: connectionID, name: "Riley Park", state: .connected)])
    // A received reminder always has a label.
    return senders.fromLine(of: reminder)!
}()

#Preview("With the strength") {
    FromLabel(from: previewFrom, strength: .relentless)
        .padding()
}

#Preview("Waiting to sync") {
    FromLabel(from: FromLine(label: previewFrom.label, waitsToSync: true), strength: .firm)
        .padding()
}

#Preview("Largest text") {
    FromLabel(from: previewFrom, strength: .gentle)
        .padding()
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
