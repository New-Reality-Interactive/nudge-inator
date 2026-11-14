import Foundation
import MessageUI
import NudgeEngine
import UIKit

/// Hands an invite's link to the person who is inviting, to send (#217). The adapter calls it once
/// the share exists with the invited person on it: the link is only worth sending then.
@MainActor
protocol InviteDelivering: AnyObject {
    /// Delivers `link`, for `person`, by `route`. Returns `true` once the person has sent it (the
    /// compose screen's Send) or copied it, `false` if they canceled or nothing could be shown.
    func deliver(_ link: URL, to person: InvitedPerson, via route: InviteRoute) async -> Bool
}

/// Delivers nothing, for an adapter made where no screen can be shown (the adapter's tests).
@MainActor
final class NoInviteDelivery: InviteDelivering {
    func deliver(_ link: URL, to person: InvitedPerson, via route: InviteRoute) async -> Bool { false }
}

/// iOS's own delivery: the message and mail compose screens, over whatever screen is up, and the
/// clipboard. The app can't send a message itself, so the person taps Send in the compose screen;
/// Apple says the screen "doesn't guarantee the delivery", so `true` means it was handed on.
@MainActor
final class SystemInviteDelivery: NSObject, InviteDelivering {
    private var finish: ((Bool) -> Void)?

    /// Whether this iPhone can send texts, and mail from an account in Mail: a route is offered
    /// only where it can work.
    static func canDeliver(via route: InviteRoute) -> Bool {
        switch route {
        case .messages: MFMessageComposeViewController.canSendText()
        case .mail: MFMailComposeViewController.canSendMail()
        case .copyLink: true
        }
    }

    func deliver(_ link: URL, to person: InvitedPerson, via route: InviteRoute) async -> Bool {
        switch route {
        case .copyLink:
            UIPasteboard.general.url = link
            return true
        case .messages:
            guard MFMessageComposeViewController.canSendText(), let presenter = Self.frontmostViewController() else { return false }
            let controller = MFMessageComposeViewController()
            controller.messageComposeDelegate = self
            controller.recipients = [person.address]
            controller.body = Self.message(with: link)
            return await present(controller, over: presenter)
        case .mail:
            guard MFMailComposeViewController.canSendMail(), let presenter = Self.frontmostViewController() else { return false }
            let controller = MFMailComposeViewController()
            controller.mailComposeDelegate = self
            controller.setToRecipients([person.address])
            controller.setSubject(String(localized: "Invitation to Nudge-inator", comment: "Invite email: the subject."))
            controller.setMessageBody(Self.message(with: link), isHTML: false)
            return await present(controller, over: presenter)
        }
    }

    private static func message(with link: URL) -> String {
        String(localized: "I'd like us to send each other reminders in Nudge-inator. Open this on your iPhone to connect: \(link.absoluteString)", comment: "Invite message and email: the body. The argument is the invite's link.")
    }

    private func present(_ controller: UIViewController, over presenter: UIViewController) async -> Bool {
        await withCheckedContinuation { continuation in
            finish = { sent in continuation.resume(returning: sent) }
            presenter.present(controller, animated: true)
        }
    }

    private static func frontmostViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed { top = presented }
        return top
    }

    fileprivate func close(_ controller: UIViewController, sent: Bool) {
        controller.dismiss(animated: true)
        finish?(sent)
        finish = nil
    }
}

extension SystemInviteDelivery: MFMessageComposeViewControllerDelegate {
    // MessageUI calls its delegates on the main thread, which is why assuming main-actor isolation holds.
    nonisolated func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        MainActor.assumeIsolated { close(controller, sent: result == .sent) }
    }
}

extension SystemInviteDelivery: MFMailComposeViewControllerDelegate {
    // Likewise on the main thread.
    nonisolated func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: (any Error)?) {
        // A saved draft isn't an invite: the link would sit in Drafts and be sent by nobody.
        MainActor.assumeIsolated { close(controller, sent: result == .sent) }
    }
}
