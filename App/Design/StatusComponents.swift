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
            LocalizedStringResource("Done", comment: "Status label: an occurrence closed as Done.")
        case .nudging:
            LocalizedStringResource("Nudging", comment: "Status label: an occurrence that has come due and isn't Done yet.")
        case .missed:
            LocalizedStringResource("Missed", comment: "Status label: an occurrence closed without Done, by its give-up limit or a take-over.")
        case .skipped:
            LocalizedStringResource("Skipped", comment: "Status label: an occurrence closed because its reminder was paused.")
        }
    }
}

/// DESIGN.md's Status label: Done green with `checkmark.circle.fill`, Missed red, Skipped in the
/// secondary label color. The word always comes with the color.
struct StatusLabel: View {
    let state: OccurrenceState

    var body: some View {
        let text = Text(state.statusName)
        Group {
            if case .done = state {
                Label {
                    text
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
            } else {
                text
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(color)
    }

    private var color: Color {
        switch state {
        case .done: .positive
        case .nudging, .missed: .negative
        case .skipped: Color(uiColor: .secondaryLabel)
        }
    }
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
            .foregroundStyle(Color.accentColor)
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
        Text("Paused", comment: "Status label: the reminder is paused.")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(uiColor: .secondaryLabel))
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
