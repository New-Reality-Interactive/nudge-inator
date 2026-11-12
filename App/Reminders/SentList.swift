import NudgeEngine
import SwiftUI

/// The Reminders tab's Sent view (ticket 201, the mockup's `viewSentTab`): what this person sent,
/// grouped under each person it went to, each row opening the sent reminder's details. Rows have no
/// swipe (DESIGN.md, Sent rows). Search, Filter, Sort and the count are #328's and #329's; the
/// empty states #202's.
struct SentList: View {
    let screen: SentScreen
    let openDetails: (Reminder.ID) -> Void

    var body: some View {
        if screen.isEmpty {
            NothingSentView()
        } else {
            List {
                ForEach(screen.people) { person in
                    Section {
                        ForEach(person.rows) { row in
                            SentRowView(row: row) { openDetails(row.reminderID) }
                        }
                    } header: {
                        Text(verbatim: person.name)
                    }
                }
            }
        }
    }
}

/// A Sent row, the mockup's `sentRow`: the due time and its day, the title, and Delivered once the
/// person's copy has arrived, or "Not delivered yet" under the title before it. The status label is
/// #206's. VoiceOver reads `Row.voiceOverLabel`.
private struct SentRowView: View {
    let row: SentScreen.Row
    let openDetails: () -> Void

    var body: some View {
        ReminderRowLayout(openDetails: openDetails) {
            TimeColumn(time: row.time, day: row.day)
        } main: {
            Text(verbatim: row.title)
                .font(.body)
            if !row.isDelivered {
                Text(SentScreen.Row.notDeliveredText)
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        } trailing: {
            if row.isDelivered {
                DeliveredLabel()
            }
        }
        .accessibilityLabel(Text(row.voiceOverLabel))
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

/// Sent with nothing in it, until #202 brings the mockup's two empty states.
private struct NothingSentView: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                Text("Nothing Sent", comment: "Reminders tab, Sent: title when this person has sent nothing to anyone connected.")
            } icon: {
                Image(systemName: "list.bullet.clipboard")
            }
        }
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
            SentCopy(connectionID: riley.id, reminderID: pills.id, createdAt: .now, receipt: .started, statusRecord: nil, waitingToSync: false),
            SentCopy(connectionID: sam.id, reminderID: pills.id, createdAt: .now, receipt: .started, statusRecord: nil, waitingToSync: false),
            SentCopy(connectionID: sam.id, reminderID: call.id, createdAt: .now.addingTimeInterval(60), receipt: .notDelivered, statusRecord: nil, waitingToSync: false),
        ]
        return SentScreen(engine: .myDayPreview(), sharing: sharing)
    }
}

#Preview("Light") {
    SentList(screen: .preview) { _ in }
}

#Preview("Dark") {
    SentList(screen: .preview) { _ in }
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    SentList(screen: .preview) { _ in }
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Nothing sent") {
    SentList(screen: SentScreen(engine: .myDayPreview(), sharing: SharingData())) { _ in }
}
#endif
