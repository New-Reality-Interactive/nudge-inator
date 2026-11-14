import SwiftUI

extension View {
    /// On a scroll view: centers its content while it's shorter than the screen, as an empty state
    /// sits, and scrolls from the top when it's taller, so the largest text sizes reach the end of it.
    /// The Reminders tab's empty states, Mine's and Sent's, share it, so switching Mine | Sent doesn't
    /// move one against the other (#399's phone check).
    func centeredWhenShort() -> some View {
        defaultScrollAnchor(.center, for: .alignment)
    }
}
