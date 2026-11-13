import CloudKit
import UIKit

/// The system sharing sheet for one connection's share (#217): `UICloudSharingController` with
/// private access and read-write permission only, so the person can only invite named people and
/// never publish a link.
@MainActor
final class InviteSheet: NSObject, UICloudSharingControllerDelegate {
    private var continuation: CheckedContinuation<Void, Never>?

    /// No screen in the foreground to show the sheet on.
    struct NoScreen: Error {}

    /// Presents the sheet over the frontmost screen and returns once it has closed.
    static func present(share: CKShare, container: CKContainer) async throws {
        guard let presenter = frontmostViewController() else { throw NoScreen() }
        let sheet = InviteSheet()
        let controller = InviteSharingController(share: share, container: container)
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = sheet
        // The controller holds its delegate weakly, so the sheet is kept alive until it closes.
        await withCheckedContinuation { continuation in
            sheet.continuation = continuation
            controller.onClose = { [weak sheet] in sheet?.finish() }
            presenter.present(controller, animated: true)
        }
        withExtendedLifetime(sheet) {}
    }

    private func finish() {
        continuation?.resume()
        continuation = nil
    }

    private static func frontmostViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed { top = presented }
        return top
    }

    // MARK: UICloudSharingControllerDelegate

    /// Only logged: the invite flow reads the share back when the sheet closes, and sends nobody
    /// when the save failed.
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: any Error) {
        CloudKitSharingAdapter.logger.error("The sharing sheet couldn't save the share: \(error, privacy: .public)")
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        String(localized: "Nudge-inator reminders", comment: "Invite: the title the system's sharing sheet shows for the connection.")
    }
}

/// Tells when the sheet has gone, whichever way: Done, Cancel or a swipe.
private final class InviteSharingController: UICloudSharingController {
    var onClose: () -> Void = {}

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil { onClose() }
    }
}
