import SwiftUI

extension LocalizedStringResource {
    /// DESIGN.md's sync state (ticket 211): what was sent or changed hasn't gone through iCloud yet.
    static let waitingToSync = LocalizedStringResource("Waiting to sync", comment: "Trailing a sent reminder's row on the Sent view and a person on its details, and on a received reminder's From line: what was sent or changed hasn't gone through iCloud yet.")
}

/// DESIGN.md's sync state: "Waiting to sync" with `clock`, in the secondary label color (ticket
/// 211). A state, so never accent, warning or negative. Semibold where it trails a Sent row, as the
/// status labels there are; regular on a received reminder's From line, as the line is. Built as
/// `StatusLabel` builds Done's, glyph close beside the word: a `Label` in a list row takes the row's
/// icon spacing, and the row's separator lines up with its title (#211's phone check).
struct WaitingToSyncLabel: View {
    var weight: Font.Weight = .semibold

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.s1) {
            // The words say it; the glyph only shows it.
            Image(systemName: "clock")
                .accessibilityHidden(true)
            Text(.waitingToSync)
                // It wraps, never truncates, as the From line's name does.
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline.weight(weight))
        .foregroundStyle(Color(uiColor: .secondaryLabel))
    }
}
