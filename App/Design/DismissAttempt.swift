import SwiftUI
import UIKit

extension View {
    /// Calls `action` when a person tries to swipe this sheet away while `interactiveDismissDisabled`
    /// holds it, so it can ask them why rather than only spring back. SwiftUI has no callback for
    /// this. UIKit's `presentationControllerDidAttemptToDismiss` is the documented one.
    func onDismissAttempt(_ action: @escaping () -> Void) -> some View {
        background(DismissAttemptObserver(action: action).frame(width: 0, height: 0).accessibilityHidden(true))
    }
}

private struct DismissAttemptObserver: UIViewControllerRepresentable {
    let action: () -> Void

    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.relay.action = action
    }

    @MainActor
    final class Controller: UIViewController {
        let relay = Relay()

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let presentation = presentationController, presentation.delegate !== relay else { return }
            relay.original = presentation.delegate
            presentation.delegate = relay
        }
    }

    /// Stands in as the presentation's delegate and passes everything else on to SwiftUI's, which
    /// needs its calls: a swipe that does dismiss has to set the sheet's binding back.
    @MainActor
    final class Relay: NSObject, UIAdaptivePresentationControllerDelegate {
        weak var original: UIAdaptivePresentationControllerDelegate?
        var action: () -> Void = {}

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            original?.presentationControllerDidAttemptToDismiss?(presentationController)
            action()
        }

        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || (original?.responds(to: selector) ?? false)
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            original
        }
    }
}
