import NudgeEngine
import SwiftUI

/// A Coming Up row: the time and its day, the title and the repeat summary, who sent a received
/// one, and the strength badge. It opens the reminder's details.
struct ComingUpRowView: View {
    let row: ComingUpRow
    let openDetails: () -> Void

    var body: some View {
        ReminderRowLayout(openDetails: openDetails) {
            TimeColumn(time: row.time, day: row.day)
        } main: {
            Text(verbatim: row.title)
                .font(.body)
            Text(row.schedule)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            if let from = row.from {
                // The row's own badge shows the strength.
                FromLabel(from: from)
            }
        } trailing: {
            StrengthBadge(strength: row.reminder.strength)
        }
    }
}

/// A Waiting for You row (ticket 203, the mockup's `waitingSection`): the time and its day, the title
/// and who sent it, which open the reminder's details, then bordered small Accept and Remove, which
/// asks first as Remove does everywhere (#200). At accessibility sizes the pieces stack.
struct WaitingRowView: View {
    let row: WaitingRow
    /// Returns whether the reminder started, which VoiceOver then confirms.
    let accept: () -> Bool
    /// Returns whether the reminder went, which VoiceOver then confirms.
    let remove: () -> Bool
    let openDetails: () -> Void

    @State private var isConfirmingRemove = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// As `ReminderRowLayout`'s, so the titles line up with Coming Up's.
    @ScaledMetric(relativeTo: .body) private var timeWidth: CGFloat = Design.Size.timeColumn

    var body: some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: Design.Spacing.s2) {
            SizeAdaptiveStack(rowAlignment: .firstTextBaseline, rowSpacing: Design.Spacing.s3, stackedSpacing: Design.Spacing.s1) {
                TimeColumn(time: row.time, day: row.day)
                    .frame(minWidth: isStacked ? nil : timeWidth, alignment: .leading)
                VStack(alignment: .leading, spacing: Design.Spacing.line) {
                    Text(verbatim: row.title)
                        .font(.body)
                    if let from = row.from {
                        FromLabel(from: from, strength: row.reminder.strength)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opensDetails(openDetails)
            .accessibilityElement(children: .combine)
            SizeAdaptiveStack(rowSpacing: Design.Spacing.s2, stackedSpacing: Design.Spacing.s2) {
                Button {
                    if accept() {
                        VoiceOverAnnouncement.post(VoiceOverAnnouncement.accepted(row.title))
                    }
                } label: {
                    Text("Accept", comment: "Now, Waiting for You: starts a reminder someone sent, which waited for the person to accept it.")
                }
                .accessibilityLabel(Text(row.acceptVoiceOverLabel))
                Button(role: .destructive) {
                    isConfirmingRemove = true
                } label: {
                    Text("Remove", comment: "Now, Waiting for You: opens the question that asks before removing a reminder someone sent, which waits to be accepted.")
                }
                .accessibilityLabel(Text(row.removeVoiceOverLabel))
                // On the button, so a popover points at it.
                .deleteReminderConfirmation(title: row.title, kind: .received, isPresented: $isConfirmingRemove) {
                    if remove() {
                        VoiceOverAnnouncement.post(VoiceOverAnnouncement.removed(row.title))
                    }
                }
            }
            // Filled, so Remove doesn't read as dimmed (#402). Full width when stacked, where a
            // capsule's ends would grow with a wrapped label.
            .buttonStyle(SmallProminentButtonStyle(fillsWidth: isStacked))
            .padding(.leading, isStacked ? 0 : timeWidth + Design.Spacing.s3)
        }
    }
}

/// A Last 24 Hours row: when it closed, the title and how it closed, who sent a received one with
/// its strength, and the status label. It opens the reminder's details.
struct ClosedRowView: View {
    let row: ClosedRow
    let openDetails: () -> Void

    var body: some View {
        ReminderRowLayout(openDetails: openDetails) {
            TimeColumn(time: row.time, day: row.day)
        } main: {
            Text(verbatim: row.title)
                .font(.body)
            Text(row.detail)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            if let note = row.missedNote {
                MissedNoteLine(note: note)
            }
            if let from = row.from {
                FromLabel(from: from, strength: row.reminder.strength)
            }
        } trailing: {
            StatusLabel(state: row.closed.occurrence.state)
        }
    }
}

/// The mockup's `.cell`, on Now and the Reminders tab: a time column, the main text, and a
/// trailing item, then DESIGN.md's chevron. The row is a button that opens the reminder. At
/// accessibility sizes they stack and wrap. VoiceOver reads the row as one element.
struct ReminderRowLayout<Leading: View, Main: View, Trailing: View, Footer: View>: View {
    let openDetails: () -> Void
    /// Inside the button, so the height it adds opens the details too.
    var minHeight: CGFloat? = nil
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let main: () -> Main
    @ViewBuilder let trailing: () -> Trailing
    /// Under the whole row, across its width, inside the button: a Sent row's 7-day history
    /// (ticket 207).
    @ViewBuilder let footer: () -> Footer

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Wide enough for "12:30 PM", so the titles line up.
    @ScaledMetric(relativeTo: .body) private var timeWidth: CGFloat = Design.Size.timeColumn

    var body: some View {
        // No spacing of its own, so a row with an empty footer is as tall as before: the footer
        // brings its own gap.
        VStack(alignment: .leading, spacing: 0) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                    leading()
                    mainStack
                    HStack {
                        trailing()
                        Spacer(minLength: 0)
                        chevron
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.s3) {
                    leading()
                        .frame(minWidth: timeWidth, alignment: .leading)
                    mainStack
                        .frame(maxWidth: .infinity, alignment: .leading)
                    trailing()
                    chevron
                }
            }
            footer()
        }
        .frame(minHeight: minHeight)
        .opensDetails(openDetails)
        .accessibilityElement(children: .combine)
    }

    private var mainStack: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.line) {
            main()
        }
    }

    /// DESIGN.md's Reminder row chevron, in the tertiary label color. Decorative.
    private var chevron: some View {
        Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(uiColor: .tertiaryLabel))
            .accessibilityHidden(true)
    }
}

extension ReminderRowLayout where Footer == EmptyView {
    /// A row with nothing under it: every row but a repeating Sent row's.
    init(
        openDetails: @escaping () -> Void,
        minHeight: CGFloat? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder main: @escaping () -> Main,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.init(openDetails: openDetails, minHeight: minHeight, leading: leading, main: main, trailing: trailing, footer: { EmptyView() })
    }
}

/// The time, with its day ("Today", "Tomorrow" or a short date) under it.
struct TimeColumn: View {
    let time: LocalizedStringResource
    let day: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(time)
                .font(.body)
                .monospacedDigit()
            Text(day)
                .font(.footnote)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
    }
}
