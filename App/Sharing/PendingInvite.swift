import SwiftUI

/// An invite the person opened while Sharing is off, waiting for their answer (#389).
struct PendingInvite: Equatable {
    /// The sender, as iCloud names them to this person.
    var senderName: String
}

extension View {
    /// The prompt for an invite opened while Sharing is off (#389), over whatever screen is showing,
    /// since iCloud hands the app the invite wherever it is. Turn On Sharing turns Sharing on and
    /// accepts the invite, and the usual Connected sheet follows (`inviteAcceptance`). Not Now
    /// leaves both as they were. The Sharing-switch mockup's alert (#386).
    func inviteWhileSharingOff(model: AppModel?) -> some View {
        modifier(InviteWhileSharingOffPresenter(model: model))
    }
}

private struct InviteWhileSharingOffPresenter: ViewModifier {
    let model: AppModel?
    /// The invite last asked about, so the text stays while the alert dismisses, after the model has
    /// dropped the invite.
    @State private var shown: PendingInvite?

    func body(content: Content) -> some View {
        let invite = model?.pendingInvite
        let name = (invite ?? shown)?.senderName ?? ""
        content.onChange(of: invite) { _, new in
            if let new { shown = new }
        }
        .alert(
            Text("Turn on sharing to connect with \(name)?", comment: "Opening an invite while Sharing is off: title of the question. The argument is the name of the person who sent the invite, such as \"Alex Morgan\"."),
            isPresented: Binding { invite != nil } set: { if !$0, model?.pendingInvite != nil { model?.answerPendingInvite(turnOnSharing: false) } }
        ) {
            Button(role: .cancel) {
                model?.answerPendingInvite(turnOnSharing: false)
            } label: {
                Text("Not Now", comment: "Opening an invite while Sharing is off: leaves Sharing off and the invite unanswered.")
            }
            Button {
                model?.answerPendingInvite(turnOnSharing: true)
            } label: {
                Text("Turn On Sharing", comment: "Opening an invite while Sharing is off: turns Sharing on and accepts the invite.")
            }
            .keyboardShortcut(.defaultAction)
        } message: {
            Text("\(name) invited you to send each other reminders through iCloud. Sharing is off on this iPhone.", comment: "Opening an invite while Sharing is off: under the title. The argument is the name of the person who sent the invite, such as \"Alex Morgan\".")
        }
    }
}
