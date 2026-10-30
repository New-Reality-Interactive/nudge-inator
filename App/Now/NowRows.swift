import NudgeEngine
import SwiftUI

/// A Coming Up row: the time and its day, the title and the repeat summary, and the strength
/// badge. It opens the reminder's details.
struct ComingUpRowView: View {
    let row: ComingUpRow
    let openDetails: () -> Void

    var body: some View {
        ReminderRowLayout(openDetails: openDetails) {
            TimeColumn(time: row.time, day: row.day)
        } main: {
            Text(verbatim: row.title)
                .font(.body)
            Text(verbatim: row.schedule)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        } trailing: {
            StrengthBadge(strength: row.reminder.strength)
        }
    }
}

/// A Last 24 Hours row: when it closed, the title and how it closed, and the status label. It
/// opens the reminder's details.
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
        } trailing: {
            StatusLabel(state: row.closed.occurrence.state)
        }
    }
}

/// The mockup's `.cell`, on Now and the Reminders tab: a time column, the main text, and a
/// trailing item, then DESIGN.md's chevron. The row is a button that opens the reminder. At
/// accessibility sizes they stack and wrap. VoiceOver reads the row as one element.
struct ReminderRowLayout<Leading: View, Main: View, Trailing: View>: View {
    let openDetails: () -> Void
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let main: () -> Main
    @ViewBuilder let trailing: () -> Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Wide enough for "12:30 PM", so the titles line up.
    @ScaledMetric(relativeTo: .body) private var timeWidth: CGFloat = Design.Size.timeColumn

    var body: some View {
        Group {
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
        }
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
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(uiColor: .tertiaryLabel))
            .accessibilityHidden(true)
    }
}

/// The time, with its day ("Today", "Tomorrow" or a short date) under it.
struct TimeColumn: View {
    let time: String
    let day: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: time)
                .font(.body)
                .monospacedDigit()
            Text(verbatim: day)
                .font(.footnote)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
    }
}
