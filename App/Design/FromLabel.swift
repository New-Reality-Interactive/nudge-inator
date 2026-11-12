import NudgeEngine
import SwiftUI

/// DESIGN.md's "From <name>" label (Shared reminders), under a received reminder's title on Now's
/// cards and every list row: `person`, then "From Riley Park" in the subhead and the secondary
/// label color. Who sent it isn't a status, so it has no color of its own. On a row with no
/// strength badge of its own (My Day, Reminders, Last 24 Hours) the badge follows it, as the
/// mockup's `fromLabel(r)`; when the two don't fit side by side, the badge goes under it.
struct FromLabel: View {
    let from: LocalizedStringResource
    /// The strength badge to follow the label, or `nil` where the row already shows one.
    var strength: Strength?

    var body: some View {
        if let strength {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Design.Spacing.s2) { name; StrengthBadge(strength: strength) }
                VStack(alignment: .leading, spacing: Design.Spacing.line) { name; StrengthBadge(strength: strength) }
            }
        } else {
            name
        }
    }

    private var name: some View {
        HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.s1) {
            // The words say who; the glyph only shows it.
            Image(systemName: "person")
                .accessibilityHidden(true)
            Text(from)
        }
        .font(.subheadline)
        .foregroundStyle(Color(uiColor: .secondaryLabel))
    }
}

#if DEBUG
/// "From Riley Park", as `Senders` writes it, so the previews add no string to the catalog.
private let previewFrom: LocalizedStringResource = {
    let connectionID = UUID()
    let reminder = Reminder(
        title: "Take the pills",
        dueTime: .now,
        strength: .gentle,
        origin: .received(connectionID: connectionID, sendersReminderID: UUID(), revision: 0, state: .accepted)
    )
    let senders = Senders(connections: [SharingConnection(id: connectionID, name: "Riley Park", state: .connected)])
    // A received reminder always has a label.
    return senders.label(of: reminder)!
}()

#Preview("With the strength") {
    FromLabel(from: previewFrom, strength: .relentless)
        .padding()
}

#Preview("Largest text") {
    FromLabel(from: previewFrom, strength: .gentle)
        .padding()
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
