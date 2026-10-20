import NudgeEngine
import SwiftUI

/// DESIGN.md's Nudge card: a leading stripe in the urgency's color; the strength badge, urgency
/// word and nudge count; the title; the tags and due time; the next nudge; the meter; and Done.
/// A card at least `wideCard` wide puts Done in a side column (the mockup's `.nc` container
/// query). At accessibility sizes it always stacks, with Done right under the title.
struct NudgeCardView: View {
    let card: NudgeCard
    /// When the card is drawn, for "in 5 min".
    let now: Date
    let markDone: () -> Void
    /// Opens the reminder's details: the title is the link, with no chevron (DESIGN.md). `nil` on
    /// the details screen itself, where the card would open the screen it is on.
    var openDetails: (() -> Void)?
    /// Whether Done is held after it was chosen with VoiceOver on it (`DoneSlot`). The caller keeps
    /// the card on screen while it is. The slot is then the card's only VoiceOver element, so
    /// moving on leaves the card: the hold ends, and the card goes, only once VoiceOver is off it.
    let isDoneHeld: Binding<Bool>

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var width: CGFloat = 0
    /// The mockup's 13rem side column.
    @ScaledMetric private var sideWidth: CGFloat = Design.Size.sideColumn

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(card.status.urgency.color)
                .frame(width: Design.Size.stripeWidth)
                .accessibilityHidden(true)
            content
                .padding(.vertical, Design.Spacing.cardVertical)
                .padding(.horizontal, Design.Spacing.s4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.card))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    @ViewBuilder private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Design.Spacing.s2) {
                summary
                doneButton
                details
                footer
            }
        } else if width >= Design.Spacing.wideCard {
            HStack(spacing: Design.Spacing.sideColumnGap) {
                VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                    summary
                    details
                }
                VStack(alignment: .leading, spacing: Design.Spacing.s2) {
                    doneButton
                    footer
                }
                .frame(width: sideWidth)
            }
        } else {
            VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                summary
                details
                doneButton
                    .padding(.top, Design.Spacing.s3)
                footer
            }
        }
    }

    /// The top row and the title, which VoiceOver reads as one element whose value is everything
    /// the details show, so the details themselves are hidden from it.
    private var summary: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s2) {
            TopRow(card: card)
            Text(verbatim: card.title)
                .font(.headline)
                .foregroundStyle(Color(uiColor: .label))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: card.title))
        .accessibilityValue(Text(card.voiceOverValue))
        // The summary is one element, so say outright that it opens something.
        .accessibilityAddTraits(openDetails == nil ? [] : .isButton)
        .opensDetails(openDetails)
        .accessibilityHidden(isDoneHeld.wrappedValue)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.line) {
            Text(card.detail)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            nextLine
                .foregroundStyle(Color(uiColor: .label))
            NudgeMeter(nudgesSent: card.status.nudgesSent, nudgesInAll: card.status.nudgesInAll, urgency: card.status.urgency)
                .padding(.top, Design.Spacing.s3)
        }
        .font(.subheadline)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var nextLine: some View {
        if let next = card.status.nextNudge, let time = card.nextNudgeTime {
            let relative = next.fireTime.shortRelative(to: now)
            Text("Next nudge \(time) (\(relative)): \(ViaLabel(delivery: next.delivery).text) · \(next.urgency.name)",
                 comment: "Nudge card: the next nudge. 1: its time, such as \"9:45 AM\". 2: how soon, such as \"in 5 min\". 3: how it arrives, such as \"Alarm\". 4: its urgency, such as \"High\".")
        } else {
            Text(card.lastNudgeLine)
        }
    }

    private var doneButton: some View {
        DoneSlot(title: card.title, isHeld: isDoneHeld, markDone: markDone) { action in
            prominentDoneButton(action: action)
        }
    }

    private func prominentDoneButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text("Done", comment: "Nudge card: the button that marks the reminder Done and stops its nudges.")
            } icon: {
                Image(systemName: "checkmark")
            }
            .fontWeight(.semibold)
            .foregroundStyle(Color.onAccent)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        // Large is the system's tallest regular button, over the 44 pt every button needs.
        .controlSize(.large)
        .buttonBorderShape(.roundedRectangle(radius: Design.Radius.control))
    }

    private var footer: some View {
        Text("Only Done stops the nudging.", comment: "Nudge card: under the Done button.")
            .font(.footnote)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
            .accessibilityHidden(isDoneHeld.wrappedValue)
    }
}

/// The strength badge, the urgency word and "Nudge 3 of 20", stacked at accessibility sizes.
private struct TopRow: View {
    let card: NudgeCard
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Design.Spacing.s1))
            : AnyLayout(HStackLayout(spacing: Design.Spacing.s2))
        layout {
            StrengthBadge(strength: card.reminder.strength)
            UrgencyWord(urgency: card.status.urgency)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text("Nudge \(card.status.nudgesSent) of \(card.status.nudgesInAll)",
                 comment: "Nudge card: how many nudges it has sent of the most it sends, such as \"Nudge 3 of 20\".")
                .font(.footnote)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
    }
}

/// DESIGN.md's Via label: `alarm` or `bell` and how the nudge arrives, or "Notifications off" in
/// red with `bell.slash`. A `Text`, so it sits inside the next-nudge sentence.
struct ViaLabel {
    let delivery: NudgeDelivery

    var text: Text {
        let text = Text("\(Image(systemName: systemImage)) \(Text(NudgeCard.via(delivery)))",
                        comment: "Via label: a glyph, then how a nudge arrives. Keep the glyph first.")
        return delivery == .cannotArrive ? text.foregroundStyle(Color.negative) : text
    }

    /// The words alone, for VoiceOver, which would otherwise read the glyph's own name first
    /// ("Notifications: Notification", device check, ticket 31).
    var spokenText: Text {
        Text(NudgeCard.via(delivery))
    }

    private var systemImage: String {
        switch delivery {
        case .alarm: "alarm"
        case .notification: "bell"
        case .cannotArrive: "bell.slash"
        }
    }
}
