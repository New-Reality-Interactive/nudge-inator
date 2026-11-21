import Foundation

/// A page of the How Sharing Works sheet (#423, the mockup `2026-11-15-sharing-tutorial`), in the
/// order the sheet shows them.
enum SharingTutorialPage: TutorialPage, CaseIterable {
    case sendEachOtherReminders
    case connect
    case sendAReminder
    case whoSeesWhat

    static let title = LocalizedStringResource("How Sharing Works", comment: "How Sharing Works: the sheet's title, and the Settings row under Tutorials that opens it.")

    var heading: LocalizedStringResource {
        switch self {
        case .sendEachOtherReminders:
            LocalizedStringResource("Send Each Other Reminders", comment: "How Sharing Works: the first page's heading, about what sharing is.")
        case .connect:
            LocalizedStringResource("Connect", comment: "How Sharing Works: the second page's heading, about inviting someone and their accepting.")
        case .sendAReminder:
            LocalizedStringResource("Send a Reminder", comment: "How Sharing Works: the third page's heading, about sending a reminder to a connection.")
        case .whoSeesWhat:
            LocalizedStringResource("Who Sees What", comment: "How Sharing Works: the last page's heading, about who owns and sees what.")
        }
    }

    /// The pictures' example person, the mockup's, named in full as the app names people.
    private static let examplePerson = LocalizedStringResource("Maya Torres", comment: "How Sharing Works: an example person's full name in the pictures, the one a reminder is sent to and from. Translate as a common full name.")

    /// The mockup's art, with the real SF Symbols.
    var art: [TutorialArtPiece] {
        switch self {
        case .sendEachOtherReminders:
            [.pill(symbol: "iphone", text: LocalizedStringResource("You", comment: "How Sharing Works, Send Each Other Reminders: the picture's pill for the person reading, beside an iPhone.")),
             .arrow,
             .pill(symbol: "iphone", text: Self.examplePerson)]
        case .connect:
            [.pill(symbol: "person.badge.plus", text: LocalizedStringResource("Invite", comment: "How Sharing Works, Connect: the picture's first pill, an invite.")),
             .arrow,
             .pill(symbol: "checkmark.circle.fill", text: LocalizedStringResource("Connected", comment: "How Sharing Works, Connect: the picture's second pill, the connection made once the invite is accepted."))]
        case .sendAReminder:
            // The received reminder's own From label (`Senders`), so the two can't be worded apart.
            [.pill(symbol: "bell", text: LocalizedStringResource("From \(String(localized: Self.examplePerson))", comment: "Under a received reminder's title on Now, My Day and the Reminders tab. The placeholder is the sender's name, such as \"Riley Park\"."))]
        case .whoSeesWhat:
            [.pill(symbol: "lock", text: LocalizedStringResource("Yours", comment: "How Sharing Works, Who Sees What: the picture's first pill, what the sender owns.")),
             .pill(symbol: "eye", text: LocalizedStringResource("Status", comment: "How Sharing Works, Who Sees What: the picture's second pill, the status the recipient chooses to share."))]
        }
    }

    var content: TutorialContent {
        switch self {
        case .sendEachOtherReminders:
            .points(lead: LocalizedStringResource("Connect with someone you trust, and the reminders you send them nudge on their iPhone like their own.", comment: "How Sharing Works, Send Each Other Reminders: the line under the heading."), [
                TutorialPoint(symbol: "icloud",
                      title: LocalizedStringResource("You both need iCloud", comment: "How Sharing Works, Send Each Other Reminders: the row about iCloud."),
                      text: LocalizedStringResource("Sharing goes through iCloud, so each of you signs in to iCloud on your iPhone.", comment: "How Sharing Works, Send Each Other Reminders: under \"You both need iCloud\".")),
                TutorialPoint(symbol: "hand.raised",
                      title: LocalizedStringResource("Only people you agree to", comment: "How Sharing Works, Send Each Other Reminders: the row about connecting only through an accepted invite."),
                      text: LocalizedStringResource("You're connected only after one of you accepts the other's invite. Until then, nobody can send you a reminder.", comment: "How Sharing Works, Send Each Other Reminders: under \"Only people you agree to\".")),
            ])
        case .connect:
            .steps([
                TutorialStep(title: LocalizedStringResource("Invite Someone", comment: "How Sharing Works, Connect: the first numbered step. Invite Someone is the Connections page's button."),
                     text: LocalizedStringResource("Settings › Connections. Enter the email address or phone number of their Apple Account.", comment: "How Sharing Works, Connect: under \"Invite Someone\". Settings › Connections is where the button is.")),
                TutorialStep(title: LocalizedStringResource("Send the Invite", comment: "How Sharing Works, Connect: the second numbered step."),
                     text: LocalizedStringResource("Through Messages, Mail or Copy Link. Nothing is sent until you tap Send.", comment: "How Sharing Works, Connect: under \"Send the Invite\". Messages, Mail and Copy Link are the ways the invite can be sent.")),
                TutorialStep(title: LocalizedStringResource("They Accept", comment: "How Sharing Works, Connect: the third numbered step."),
                     text: LocalizedStringResource("They open the invite on their iPhone, and you're both connected.", comment: "How Sharing Works, Connect: under \"They Accept\".")),
            ], footnote: LocalizedStringResource("An invite opens only for the Apple Account it was sent to, and you both need the latest Nudge-inator.", comment: "How Sharing Works, Connect: the note under the steps."))
        case .sendAReminder:
            .points(lead: LocalizedStringResource("Pick Send To when you make a reminder, and choose who gets it. It nudges them at the strength you chose.", comment: "How Sharing Works, Send a Reminder: the line under the heading. Send To is the reminder form's row."), [
                TutorialPoint(symbol: "paperplane",
                      title: LocalizedStringResource("It shows your name", comment: "How Sharing Works, Send a Reminder: the row about how a sent reminder is labeled."),
                      text: LocalizedStringResource("It appears among their reminders, labeled From you. They can mark it Done, pause it, remove it and tag it.", comment: "How Sharing Works, Send a Reminder: under \"It shows your name\". \"From you\" stands for the From label with the sender's name.")),
                TutorialPoint(symbol: "clock",
                      title: LocalizedStringResource("Their Delivery Mode", comment: "How Sharing Works, Send a Reminder: the row about the recipient's Delivery Mode, the connection's setting."),
                      text: LocalizedStringResource("Each person chooses, for each connection, whether reminders start right away or wait for them to accept first.", comment: "How Sharing Works, Send a Reminder: under \"Their Delivery Mode\".")),
            ])
        case .whoSeesWhat:
            .points(lead: nil, [
                TutorialPoint(symbol: "lock",
                      title: LocalizedStringResource("You own what you send", comment: "How Sharing Works, Who Sees What: the row about the sender owning a sent reminder."),
                      text: LocalizedStringResource("Only you can change what it says or when it's due. They can't edit it.", comment: "How Sharing Works, Who Sees What: under \"You own what you send\".")),
                TutorialPoint(symbol: "eye",
                      title: LocalizedStringResource("Status is their choice", comment: "How Sharing Works, Who Sees What: the row about the recipient's Status Sharing."),
                      text: LocalizedStringResource("With Status Sharing on, you see whether it's Done, Paused, Missed or Removed. With it off, you see only that it was Delivered.", comment: "How Sharing Works, Who Sees What: under \"Status is their choice\". Done, Paused, Missed, Removed and Delivered are a sent reminder's statuses.")),
                TutorialPoint(symbol: "person.2",
                      title: LocalizedStringResource("Disconnect any time", comment: "How Sharing Works, Who Sees What: the row about disconnecting."),
                      text: LocalizedStringResource("Settings › Connections. They choose to keep or remove the reminders you sent.", comment: "How Sharing Works, Who Sees What: under \"Disconnect any time\". Settings › Connections is where Disconnect is.")),
                TutorialPoint(symbol: "list.bullet.rectangle",
                      title: LocalizedStringResource("Share Activity", comment: "How Sharing Works, Who Sees What: the row about the Share Activity page."),
                      text: LocalizedStringResource("Settings › Share Activity shows what happened to sharing that you'd otherwise never see.", comment: "How Sharing Works, Who Sees What: under \"Share Activity\".")),
            ])
        }
    }
}
