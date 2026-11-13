import NudgeEngine
import SwiftUI

/// The Reminders tab's Sent view (ticket 201, the mockup's `viewSentTab`): what this person sent,
/// grouped under each person it went to, each row opening the sent reminder's details. Rows have no
/// swipe (DESIGN.md, Sent rows). Search, Filter, Sort and the count are #328's and #329's.
///
/// With no one connected it offers Invite Someone and Manage People, and with nothing sent New
/// Reminder (ticket 202). Neither empty state has tools (DESIGN.md, Sent's tools). While sharing
/// is paused (ticket 210) the paused banner leads it, empty or not, and Invite Someone is off.
struct SentList: View {
    let screen: SentScreen
    /// What Invite Someone invites through. Previews without one show the button but invite no one.
    let sharing: SharingModel?
    /// Manage People: Settings › Connections.
    let manageConnections: () -> Void
    let openDetails: (Reminder.ID) -> Void

    /// Invite Someone's flow, kept here above the empty states, so an invite under way isn't lost
    /// when someone connects and No One to Send To goes.
    @State private var isInviting = false

    var body: some View {
        content
            .inviteFlow(sharing: sharing, isPresented: $isInviting)
    }

    private var banner: SharingBanner? { sharing?.banner }

    @ViewBuilder private var content: some View {
        switch screen.emptyState {
        case .noOneToSendTo:
            NoOneToSendToView(banner: banner, invite: { isInviting = true }, manageConnections: manageConnections)
        case .nothingSent:
            NothingSentView(banner: banner)
        case nil:
            List {
                ForEach(screen.people) { person in
                    Section {
                        ForEach(person.rows) { row in
                            SentRowView(row: row) { openDetails(row.reminderID) }
                        }
                    } header: {
                        // Above the first person's name, as Now's first header holds its banners.
                        VStack(alignment: .leading, spacing: Design.Spacing.s3) {
                            if person.id == screen.people.first?.id {
                                SharingBannerView(banner: banner)
                            }
                            Text(verbatim: person.name)
                                // The banner beside it in the header drops the header trait,
                                // so the name keeps it for VoiceOver's headings.
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                }
            }
        }
    }
}

/// A Sent row, the mockup's `sentRow`: the due time and its day, the title, and Delivered once the
/// person's copy has arrived, or "Not delivered yet" under the title before it. Once their app
/// reports how the copy is going, the status label takes Delivered's place (ticket 206), and a
/// repeating reminder's 7-day history runs under the row (ticket 207). VoiceOver reads
/// `Row.voiceOverLabel`, then the history as the row's value.
private struct SentRowView: View {
    let row: SentScreen.Row
    let openDetails: () -> Void

    var body: some View {
        ReminderRowLayout(openDetails: openDetails) {
            TimeColumn(time: row.time, day: row.day)
        } main: {
            Text(verbatim: row.title)
                .font(.body)
            if let line = row.detailLine {
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        } trailing: {
            SentTrailingLabel(trailing: row.trailing)
        } footer: {
            if let history = row.history {
                SentHistoryStrip(history: history)
                    .padding(.top, Design.Spacing.s2)
            }
        }
        .accessibilityLabel(Text(row.voiceOverLabel))
        .accessibilityValue(spoken: row.history?.voiceOverValue)
    }
}

private extension View {
    /// The row's value, only when it has one: a one-off row reads its label alone, as before.
    @ViewBuilder func accessibilityValue(spoken value: String?) -> some View {
        if let value {
            accessibilityValue(Text(verbatim: value))
        } else {
            self
        }
    }
}

/// DESIGN.md's 7-day history, the mockup's `histStrip`: eight cells, oldest first, each with the
/// day's initial over its status glyph, today's on the tertiary fill. Four to a line at the
/// accessibility sizes, as the mockup's cells wrap. VoiceOver reads the row's value instead.
struct SentHistoryStrip: View {
    let history: SentHistory

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Grid(horizontalSpacing: Design.Spacing.s1, verticalSpacing: Design.Spacing.s1) {
            ForEach(lines, id: \.first?.id) { line in
                GridRow {
                    ForEach(line) { day in
                        SentHistoryCell(day: day)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var lines: [[SentHistory.Day]] {
        let perLine = dynamicTypeSize.isAccessibilitySize ? 4 : history.days.count
        return stride(from: 0, to: history.days.count, by: perLine).map {
            Array(history.days[$0..<min($0 + perLine, history.days.count)])
        }
    }
}

/// One day of the strip, the mockup's `.hday`.
private struct SentHistoryCell: View {
    let day: SentHistory.Day

    var body: some View {
        VStack(spacing: Design.Spacing.line) {
            Text(verbatim: day.initial)
                .font(day.isToday ? .footnote.weight(.semibold) : .footnote)
            // Every glyph in the box Done's takes, so a short one (a minus, a ✕) doesn't make its
            // cell shorter and drop its initial below the others' (the #207 phone check).
            Image(systemName: OccurrenceState.doneGlyph)
                .hidden()
                .overlay {
                    Image(systemName: day.glyph)
                        .foregroundStyle(day.status?.statusTint ?? textColor)
                }
                .font(.footnote)
                .imageScale(.small)
        }
        .foregroundStyle(textColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Design.Spacing.historyCellVertical)
        .background {
            if day.isToday {
                RoundedRectangle(cornerRadius: Design.Radius.historyCell, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
            }
        }
    }

    /// The label color on today's fill, as DESIGN.md asks; the secondary label color elsewhere.
    private var textColor: Color {
        day.isToday ? Color(uiColor: .label) : Color(uiColor: .secondaryLabel)
    }
}

/// A day on a sent reminder's details' "<name>, Last 7 Days" (the #207 change mockup): its strip
/// glyph beside its status word, as Done's status label has its check, or "Nothing due".
struct SentHistoryDayLabel: View {
    let day: SentHistory.Day

    var body: some View {
        HStack(spacing: Design.Spacing.s1) {
            // The word says it; the glyph only shows it.
            Image(systemName: day.glyph)
                .accessibilityHidden(true)
            if let status = day.status {
                Text(status.name)
            } else {
                Text(SentHistory.nothingDueText)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(day.status?.statusTint ?? Color(uiColor: .secondaryLabel))
    }
}

/// The label trailing a Sent row, or a recipient on a sent reminder's details: the copy's status, or
/// Delivered (ticket 206), or nothing while it hasn't arrived.
struct SentTrailingLabel: View {
    let trailing: SentReadOut.Trailing

    var body: some View {
        switch trailing {
        case .nothing: EmptyView()
        case .waitingToSync: WaitingToSyncLabel()
        case .delivered: DeliveredLabel()
        case .status(let status): ReportedStatusLabel(status: status)
        }
    }
}

/// DESIGN.md's Delivered status label, in the secondary label color as Skipped and Paused are.
struct DeliveredLabel: View {
    var body: some View {
        Text(SentScreen.Row.deliveredText)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(uiColor: .secondaryLabel))
    }
}

/// Sent with no one connected, the mockup's "No One to Send To": Invite Someone, as Connections
/// offers it, and Manage People, which goes to Settings › Connections (the spec; the mockup pushes
/// Connections on Reminders, README Known differences). It scrolls, so the buttons are reached at
/// the largest text size, on the grouped background the mockup's screens have.
private struct NoOneToSendToView: View {
    let banner: SharingBanner?
    let invite: () -> Void
    let manageConnections: () -> Void

    var body: some View {
        ScrollView {
            BannerAboveEmptyState(banner: banner)
            ContentUnavailableView {
                Label {
                    Text("No One to Send To", comment: "Reminders tab, Sent: title when this person is connected with no one.")
                } icon: {
                    Image(systemName: "person.2")
                }
            } description: {
                Text("Invite someone you trust, and what you send them shows here.", comment: "Reminders tab, Sent: under \"No One to Send To\".")
            } actions: {
                Button(action: invite) {
                    InviteSomeoneLabel()
                }
                .buttonStyle(.bordered)
                .disabled(banner?.pausesSharing == true)
                Button(action: manageConnections) {
                    Text("Manage People", comment: "Reminders tab, Sent: under Invite Someone when no one is connected. Opens Settings › Connections.")
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

/// Sent with someone connected but nothing sent to them, the mockup's "Nothing Sent": New Reminder,
/// the toolbar's button with its title showing.
private struct NothingSentView: View {
    let banner: SharingBanner?

    var body: some View {
        ScrollView {
            BannerAboveEmptyState(banner: banner)
            ContentUnavailableView {
                Label {
                    Text("Nothing Sent", comment: "Reminders tab, Sent: title when this person has sent nothing to anyone connected.")
                } icon: {
                    Image(systemName: "list.bullet.clipboard")
                }
            } description: {
                Text("Make a reminder and choose who to send it to.", comment: "Reminders tab, Sent: under \"Nothing Sent\", when someone is connected.")
            } actions: {
                NewReminderButton()
                    .buttonStyle(.bordered)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

#if DEBUG
private extension SentScreen {
    /// The pills sent to Riley and Sam, delivered to Riley; a call sent to Sam alone.
    static var preview: SentScreen {
        let pills = Reminder(title: "Take the pills", dueTime: .now.addingTimeInterval(3600), repeatRule: .everyDay, strength: .firm)
        let call = Reminder(title: "Call the clinic", dueTime: .now.addingTimeInterval(7200), strength: .gentle)
        let riley = SharingConnection(id: UUID(), name: "Riley Park", state: .connected)
        let sam = SharingConnection(id: UUID(), name: "Sam Rivera", state: .connected)
        var sharing = SharingData(connections: [riley, sam])
        sharing.sentReminders = [SentReminder(reminder: pills, revision: 0), SentReminder(reminder: call, revision: 0)]
        sharing.sentCopies = [
            SentCopy(connectionID: riley.id, reminderID: pills.id, createdAt: .now, receipt: .started, statusRecord: nil),
            SentCopy(connectionID: sam.id, reminderID: pills.id, createdAt: .now, receipt: .started, statusRecord: nil),
            SentCopy(connectionID: sam.id, reminderID: call.id, createdAt: .now.addingTimeInterval(60), receipt: .notDelivered, statusRecord: nil),
        ]
        return SentScreen(engine: .myDayPreview(), sharing: sharing)
    }
}

private extension SentList {
    init(preview screen: SentScreen) {
        self.init(screen: screen, sharing: nil, manageConnections: {}, openDetails: { _ in })
    }
}

/// Sent's screens with no one connected, then with Riley connected and nothing sent.
private extension SentScreen {
    static var noOneToSendTo: SentScreen {
        SentScreen(engine: .myDayPreview(), sharing: SharingData())
    }

    static var nothingSent: SentScreen {
        SentScreen(engine: .myDayPreview(), sharing: SharingData(connections: [SharingConnection(id: UUID(), name: "Riley Park", state: .connected)]))
    }
}

#Preview("Light") {
    SentList(preview: .preview)
}

#Preview("Dark") {
    SentList(preview: .preview)
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    SentList(preview: .preview)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("No one to send to") {
    SentList(preview: .noOneToSendTo)
}

#Preview("No one to send to, dark, largest text") {
    SentList(preview: .noOneToSendTo)
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Nothing sent") {
    SentList(preview: .nothingSent)
}

#Preview("Nothing sent, landscape", traits: .landscapeLeft) {
    SentList(preview: .nothingSent)
}
#endif
