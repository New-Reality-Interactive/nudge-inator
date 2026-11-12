import NudgeEngine
import SwiftUI

/// DESIGN.md's Strength badge: an outlined capsule with a 1-, 2- or 3-bar glyph, then the name.
/// Strength has no color, so the bars and the name carry it.
struct StrengthBadge: View {
    let strength: Strength

    var body: some View {
        HStack(spacing: Design.Spacing.s1) {
            StrengthBars(strength: strength)
            Text(strength.title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color(uiColor: .label))
        .padding(.vertical, Design.Size.badgeVerticalPadding)
        .padding(.leading, Design.Size.badgeLeadingPadding)
        .padding(.trailing, Design.Spacing.s2)
        .overlay(Capsule().strokeBorder(Color.neutral))
        // The name says it; the bars only show it.
        .accessibilityElement(children: .combine)
    }
}

/// The badge's bars, the mockup's `strengthBar`: rising bars, the ones above the strength
/// outlined. They scale with the text.
private struct StrengthBars: View {
    let strength: Strength
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = 11

    var body: some View {
        HStack(alignment: .bottom, spacing: height * 0.15) {
            ForEach(0..<3) { index in
                let bar = RoundedRectangle(cornerRadius: height * 0.07)
                let barHeight = height * (0.31 + 0.3 * CGFloat(index))
                Group {
                    if index < strength.bars {
                        bar.fill(.foreground)
                    } else {
                        bar.strokeBorder(.foreground.opacity(0.55), lineWidth: 1)
                    }
                }
                .frame(width: height * 0.24, height: barHeight)
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

extension Strength {
    /// How many of the badge's three bars are filled.
    var bars: Int {
        switch self {
        case .gentle: 1
        case .firm: 2
        case .relentless: 3
        }
    }
}

extension Urgency {
    /// A nudge card's only color: its stripe, meter and urgency word.
    var color: Color {
        switch self {
        case .normal: .neutral
        case .high: .warning
        case .urgent: .negative
        }
    }

    /// The urgency word's glyph. Normal has neither word nor glyph on a card.
    var systemImage: String? {
        switch self {
        case .normal: nil
        case .high: "arrow.up"
        case .urgent: "alarm"
        }
    }
}

/// DESIGN.md's urgency word: "High" with `arrow.up`, "Urgent" with `alarm`, in the urgency's
/// color, so the color is never the only signal. Nothing for Normal.
struct UrgencyWord: View {
    let urgency: Urgency

    var body: some View {
        if let systemImage = urgency.systemImage {
            Label {
                Text(verbatim: urgency.name)
            } icon: {
                Image(systemName: systemImage)
            }
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(urgency.color)
        }
    }
}

extension OccurrenceState {
    /// The status label's word.
    var statusName: LocalizedStringResource {
        switch self {
        case .done:
            LocalizedStringResource("Done", comment: "Status label, and a Status row in the Reminders filter sheet: an occurrence closed as Done.")
        case .nudging:
            LocalizedStringResource("Nudging", comment: "Status label, and a Status row in the Reminders filter sheet: an occurrence that has come due and isn't Done yet.")
        case .missed:
            LocalizedStringResource("Missed", comment: "Status label, and a Status row in the Reminders filter sheet: an occurrence closed without Done, by its give-up limit or a take-over.")
        case .skipped:
            LocalizedStringResource("Skipped", comment: "Status label, and a Status row in the Reminders filter sheet: an occurrence closed because its reminder was paused.")
        }
    }
}

/// DESIGN.md's Status label: Done green with `checkmark.circle.fill`, Nudging and Missed red,
/// Skipped in the secondary label color. The word always comes with the color. Done is drawn as its
/// own stack, not a `Label`: in a `List` a label's icon takes a column of its own, which indented it
/// from the row's text at accessibility sizes (enhancement-pace ticket 15).
struct StatusLabel: View {
    let state: OccurrenceState

    var body: some View {
        let text = Text(state.statusName)
        Group {
            if let glyph = state.statusGlyph {
                HStack(spacing: Design.Spacing.s1) {
                    // The word says it; the glyph only shows it.
                    Image(systemName: glyph)
                        .accessibilityHidden(true)
                    text
                }
            } else {
                text
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(state.statusTint ?? Color(uiColor: .secondaryLabel))
    }
}

extension OccurrenceState {
    /// DESIGN.md's status colors: Done positive, Nudging and Missed negative, or `nil` for a status
    /// with none of its own (Skipped), which takes the secondary label color, or the label color on
    /// a 7-day history's today. The status label and the history's glyphs both take it from here.
    var statusTint: Color? {
        switch self {
        case .done: .positive
        case .nudging, .missed: .negative
        case .skipped: nil
        }
    }

    /// The glyph the status label shows beside its word: only Done has one.
    var statusGlyph: String? {
        if case .done = self { Self.doneGlyph } else { nil }
    }

    /// Done's glyph, on its status label and in a 7-day history.
    static let doneGlyph = "checkmark.circle.fill"
}

/// DESIGN.md's `button-bordered` as a small capsule, or with `fillsWidth` a full-width rounded
/// rectangle: accent text on the tertiary fill, at least 44 pt tall. Drawn here rather than by
/// `.bordered`: the system's style carries a glass layer that the phone left drawn behind a My Day
/// row's status after Done.
struct SmallBorderedButtonStyle: ButtonStyle {
    /// Fills its container's width with the control radius, as a nudge card's Done does, in place
    /// of a capsule, whose round ends would grow with a label that wraps.
    var fillsWidth = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = fillsWidth
            ? AnyShape(RoundedRectangle(cornerRadius: Design.Radius.control))
            : AnyShape(Capsule())
        configuration.label
            .font(.subheadline.weight(.semibold))
            // A destructive one, such as Waiting for You's Remove, in destructive text (DESIGN.md).
            .foregroundStyle(configuration.role == .destructive ? Color.negative : Color.accentColor)
            .padding(.horizontal, Design.Spacing.s4)
            .padding(.vertical, fillsWidth ? Design.Spacing.s2 : 0)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: Design.Spacing.rowMin)
            .background(shape.fill(Color(uiColor: .tertiarySystemFill)))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// DESIGN.md's Status label for a reminder that is paused, in the secondary label color.
struct PausedLabel: View {
    var body: some View {
        ReminderStatusLabel(status: .paused)
    }
}

/// "Waiting" on a received reminder waiting to be accepted (ticket 203).
struct WaitingLabel: View {
    var body: some View {
        ReminderStatusLabel(status: .waiting)
    }
}

/// "Canceled" on a received reminder its sender deleted (ticket 205).
struct CanceledLabel: View {
    var body: some View {
        ReminderStatusLabel(status: .canceled)
    }
}

/// A reminder's status label, in DESIGN.md's Status label colors: Nudging red, Paused, Coming up
/// and Waiting in the secondary label color, a closed occurrence as the Now tab's status label.
/// The details page's hero and the Reminders tab's rows.
struct ReminderStatusLabel: View {
    let status: ReminderStatus

    var body: some View {
        switch status {
        case .nudging:
            // The label's word and color don't depend on the nudge number.
            StatusLabel(state: .nudging(nudgeNumber: 0))
        case .closed(let state):
            StatusLabel(state: state)
        case .paused, .comingUp, .waiting, .canceled:
            Text(status.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
    }
}

/// A status as the sender reads it on a Sent row (ticket 206): DESIGN.md's Status label, and
/// Removed in the secondary label color with Paused and Waiting.
struct ReportedStatusLabel: View {
    let status: ReportedStatus

    var body: some View {
        if let state = status.occurrenceState {
            StatusLabel(state: state)
        } else {
            Text(status.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
    }
}

extension ReportedStatus {
    /// The occurrence state whose status label this status shares, or `nil` for Coming up, Paused
    /// and Removed, which are in the secondary label color. The reasons mean nothing here: a
    /// label's word, color and glyph don't depend on one.
    var occurrenceState: OccurrenceState? {
        switch self {
        case .nudging: .nudging(nudgeNumber: 0)
        case .done: .done
        case .missed: .missed(reason: .giveUpLimit)
        case .skipped: .skipped(reason: .paused)
        case .comingUp, .paused, .removed: nil
        }
    }

    /// The status color its label and its 7-day history glyph share (`OccurrenceState.statusTint`).
    var statusTint: Color? { occurrenceState?.statusTint }

    /// DESIGN.md's 7-day history glyphs. A day's report never holds Removed (GLOSSARY's Status
    /// report); were it to, it reads as Skipped does.
    var historyGlyph: String {
        switch self {
        case .done: OccurrenceState.doneGlyph
        case .missed: "xmark"
        case .nudging: "bell"
        case .skipped, .removed: "minus"
        case .paused: "pause"
        case .comingUp: "clock"
        }
    }
}

extension ReportedStatus {
    /// The status label's word, for VoiceOver to read with the rest of a Sent row.
    var name: LocalizedStringResource {
        switch self {
        case .nudging: ReminderStatus.nudging.name
        case .comingUp: ReminderStatus.comingUp.name
        case .paused: ReminderStatus.paused.name
        case .done: OccurrenceState.done.statusName
        case .missed: OccurrenceState.missed(reason: .giveUpLimit).statusName
        case .skipped: OccurrenceState.skipped(reason: .paused).statusName
        case .removed: LocalizedStringResource("Removed", comment: "Status label on a Sent row: the person removed their copy of the reminder.")
        }
    }
}

extension ReminderStatus {
    /// The status label's word, for VoiceOver to read with the rest of a row.
    var name: LocalizedStringResource {
        switch self {
        case .nudging: OccurrenceState.nudging(nudgeNumber: 0).statusName
        case .closed(let state): state.statusName
        case .paused: LocalizedStringResource("Paused", comment: "Status label, and a Status row in the Reminders filter sheet: the reminder is paused.")
        case .comingUp: LocalizedStringResource("Coming up", comment: "Status label, and a Status row in the Reminders filter sheet: the reminder isn't due yet.")
        case .waiting: LocalizedStringResource("Waiting", comment: "Status label: a reminder someone sent is waiting for the person to accept it, so it doesn't nudge yet.")
        case .canceled: LocalizedStringResource("Canceled", comment: "Status label: the person who sent a reminder deleted it, so it no longer nudges.")
        }
    }
}

/// DESIGN.md's Nudge meter: a 6 pt capsule track that fills from the leading edge in the
/// urgency's color, nudges sent out of the give-up limit. The card's VoiceOver value says the
/// count, so the meter itself is hidden.
struct NudgeMeter: View {
    let nudgesSent: Int
    let nudgesInAll: Int
    let urgency: Urgency

    var body: some View {
        let fraction = nudgesInAll > 0 ? min(1, CGFloat(nudgesSent) / CGFloat(nudgesInAll)) : 0
        Capsule()
            .fill(Color(uiColor: .tertiarySystemFill))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(urgency.color)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: Design.Size.meterHeight)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Design.Spacing.s3) {
        HStack {
            StrengthBadge(strength: .gentle)
            StrengthBadge(strength: .firm)
            StrengthBadge(strength: .relentless)
        }
        HStack {
            UrgencyWord(urgency: .high)
            UrgencyWord(urgency: .urgent)
        }
        HStack {
            StatusLabel(state: .done)
            StatusLabel(state: .missed(reason: .giveUpLimit))
            StatusLabel(state: .skipped(reason: .paused))
        }
        NudgeMeter(nudgesSent: 7, nudgesInAll: 20, urgency: .urgent)
    }
    .padding()
}
