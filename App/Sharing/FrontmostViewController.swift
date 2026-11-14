import UIKit

extension UIViewController {
    /// The view controller on top of the foreground window, which an iOS screen that can't live
    /// inside SwiftUI (the compose screens, the contact picker) is presented over.
    @MainActor
    static func frontmost() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed { top = presented }
        return top
    }
}
