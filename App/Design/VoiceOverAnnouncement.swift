import SwiftUI

/// A short sentence the app asks VoiceOver to speak, without moving its focus, when something
/// changes away from the item VoiceOver is on (#221): a result, an error, a reminder that left the
/// list. With VoiceOver off, posting it does nothing.
///
/// Two priorities (`accessibilitySpeechAnnouncementPriority`; the compiler marks the older
/// queued-announcement attribute deprecated, renamed to it, in iOS 27's SDK). What answers the
/// person's own action, a confirmation or a filter sheet's count, has the high priority, which
/// Apple documents as interrupting other speech and not interruptible once started (WWDC23, "Build
/// accessible apps with SwiftUI and UIKit"). At the default priority, VoiceOver's move to the next
/// row, the focus iOS places as an alert closes, or a relabeled button cut it off; at the low
/// priority, a filter sheet's count was dropped (#221's phone check). An error under a field has
/// the low priority: queued until other speech has finished, so it doesn't cut off the typing.
enum VoiceOverAnnouncement {
    /// What answers the person's own action, at the high priority.
    static func post(_ sentence: LocalizedStringResource) {
        post(AttributedString(localized: sentence), priority: .high)
    }

    /// News beside VoiceOver's focus, as an error or a count, at the low priority.
    static func mention(_ sentence: LocalizedStringResource) {
        post(AttributedString(localized: sentence), priority: .low)
    }

    private static func post(_ sentence: AttributedString, priority: AttributeScopes.AccessibilityAttributes.AnnouncementPriorityAttribute.Value) {
        var spoken = sentence
        spoken.accessibilitySpeechAnnouncementPriority = priority
        AccessibilityNotification.Announcement(spoken).post()
    }

    /// Done on a Reminders row's VoiceOver action, and the Done slot's place
    /// after its own Done (Now, My Day): one sentence, so both say the same.
    static func done(_ title: String) -> LocalizedStringResource {
        LocalizedStringResource("\(title) is Done. Its nudges have stopped.", comment: "VoiceOver: spoken after Done on a Reminders row's action, and what a nudge card's or My Day row's Done button place says after Done. The placeholder is the reminder's title.")
    }

    /// Accept on a Waiting for You row, which leaves the section.
    static func accepted(_ title: String) -> LocalizedStringResource {
        LocalizedStringResource("\(title) accepted. It nudges you as your own reminders do.", comment: "VoiceOver: spoken after Accept on a Waiting for You row on Now, as the row leaves the section. The placeholder is the reminder's title.")
    }

    /// Remove on a Waiting for You row, once confirmed.
    static func removed(_ title: String) -> LocalizedStringResource {
        LocalizedStringResource("\(title) removed.", comment: "VoiceOver: spoken after Remove on a Waiting for You row on Now is confirmed, as the row goes. The placeholder is the reminder's title.")
    }

    /// Pause Reminder on the details, whose button becomes Resume Reminder.
    static func paused(_ title: String) -> LocalizedStringResource {
        LocalizedStringResource("\(title) paused. It won't nudge you until you resume it.", comment: "VoiceOver: spoken after Pause Reminder on a reminder's details. The placeholder is the reminder's title.")
    }

    /// Resume Reminder on the details, whose button becomes Pause Reminder.
    static func resumed(_ title: String) -> LocalizedStringResource {
        LocalizedStringResource("\(title) resumed. It nudges you when it's next due.", comment: "VoiceOver: spoken after Resume Reminder on a reminder's details. The placeholder is the reminder's title.")
    }

    /// An invite sent from Messages or Mail, as Invite Someone or Invite Again closes. Copy Link has
    /// its own Link Copied message instead.
    static func inviteSent(to name: String) -> LocalizedStringResource {
        LocalizedStringResource("Invite sent to \(name).", comment: "VoiceOver: spoken as Invite Someone or Invite Again closes after the invite went by Messages or Mail. The placeholder is the invited person's name, such as \"Riley Park\".")
    }

    /// Disconnect on a connection's page, as the page closes.
    static func disconnected(from name: String) -> LocalizedStringResource {
        LocalizedStringResource("Disconnected from \(name).", comment: "VoiceOver: spoken after Disconnect's sheet ends a connection, as the connection's page closes. The placeholder is the other person's name, such as \"Alex Morgan\".")
    }

    /// What to speak when a message changes from `old` to `new`: the new one when it appears or
    /// becomes another, and nothing when it goes away or stays the same.
    static func spoken<Message: Equatable>(from old: Message?, to new: Message?) -> Message? {
        guard let new, new != old else { return nil }
        return new
    }
}

extension View {
    /// Has VoiceOver mention `message`'s sentence when it appears or changes, as an error under a
    /// field, which VoiceOver's focus isn't on.
    func speaksAsItChanges<Message: Equatable>(_ message: Message?, sentence: @escaping (Message) -> LocalizedStringResource) -> some View {
        onChange(of: message) { old, new in
            if let spoken = VoiceOverAnnouncement.spoken(from: old, to: new) {
                VoiceOverAnnouncement.mention(sentence(spoken))
            }
        }
    }

    /// Text in a List's section header that isn't a heading itself, as a count or a subhead: SwiftUI
    /// gives a header's text the heading trait, and VoiceOver's rotor would list it (#221).
    func notAHeading() -> some View {
        accessibilityRemoveTraits(.isHeader)
    }

    /// The hint of a dimmed confirm button: why it is dimmed. Always set, empty while it isn't, so
    /// the button keeps its identity, and VoiceOver its place, as it dims and brightens.
    func dimmedBecause(_ reason: LocalizedStringResource?) -> some View {
        accessibilityHint(reason.map { Text($0) } ?? Text(verbatim: ""))
    }
}
