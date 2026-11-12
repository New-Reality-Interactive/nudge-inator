import NudgeEngine
import SwiftUI

/// The New Reminder form's Send To row (ticket 198), as the mockup's `sendToSection`: with someone
/// connected it opens the Send To page and names who's chosen; with no one, it is Invite Someone New.
/// Under it, once someone is chosen, a line saying it nudges them, not the person.
struct SendToSection: View {
    @Bindable var form: ReminderForm
    @Binding var isInviting: Bool

    var body: some View {
        Section {
            if form.sendToChoices.isEmpty {
                Button {
                    isInviting = true
                } label: {
                    LabeledContent {
                        Text("Invite Someone New", comment: "The reminder form's Send To row when no one is connected: invites someone.")
                            .foregroundStyle(Color.accentColor)
                    } label: {
                        Text("Send To", comment: "The reminder form's row that chooses who the reminder is sent to.")
                            .foregroundStyle(Color(uiColor: .label))
                    }
                }
            } else {
                NavigationLink(value: ReminderFormPage.sendTo) {
                    LabeledContent {
                        if form.recipientNames.isEmpty {
                            Text("None", comment: "The reminder form's Send To row when no one is chosen.")
                        } else {
                            // People's own names, never translated.
                            Text(verbatim: form.recipientNames.formatted(.list(type: .and)))
                        }
                    } label: {
                        Text("Send To", comment: "The reminder form's row that chooses who the reminder is sent to.")
                    }
                }
            }
        } footer: {
            if !form.recipientNames.isEmpty {
                Text("It nudges \(form.recipientNames.formatted(.list(type: .and))), not you, and you'll find it under Sent.",
                     comment: "Under the reminder form's Send To row once someone is chosen. The argument is the chosen people's whole names as a list, such as \"Riley Park and Sam Rivera\".")
            }
        }
    }
}

/// The form's Send To page, as the mockup's `editorSendTo`: everyone connected, with a checkmark on
/// the chosen, then Invite Someone New.
struct SendToPage: View {
    @Bindable var form: ReminderForm
    @Binding var isInviting: Bool

    var body: some View {
        Form {
            Section {
                ForEach(form.sendToChoices) { connection in
                    // The person's own name, never translated.
                    CheckmarkRow(title: Text(verbatim: connection.name), isChecked: form.isRecipient(connection.id)) {
                        form.toggleRecipient(connection.id)
                    }
                }
                Button {
                    isInviting = true
                } label: {
                    Label {
                        Text("Invite Someone New", comment: "The Send To page's last row: invites someone to connect.")
                    } icon: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            } footer: {
                Text("Choose one or more people. Each gets their own copy, at this strength, and it won't nudge you.",
                     comment: "Under the Send To page's list of people.")
            }
        }
        .centeredInReadableColumn()
        .navigationTitle(Text("Send To", comment: "Title of the reminder form's Send To page."))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("Form with Send To") {
    ReminderFormSheet(form: .previewSendTo())
}

#Preview("Form, no one to send to") {
    ReminderFormSheet(form: .previewSendTo(seeded: false))
}

#Preview("Send To page") {
    NavigationStack { SendToPage(form: .previewSendTo(), isInviting: .constant(false)) }
}

#Preview("Send To page, largest text") {
    NavigationStack { SendToPage(form: .previewSendTo(), isInviting: .constant(false)) }
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
