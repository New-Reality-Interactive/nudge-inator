import SwiftUI

extension View {
    /// How Sharing Works, opened by itself the first time Sharing is turned on (#424): over
    /// Settings when the switch turned it on, and after the Connected sheet's Done when an invite's
    /// Turn On Sharing did (`AppModel.isSharingTutorialDue`). Closing it, however it closes, means it
    /// never opens by itself again; the Settings row still opens it (#423).
    func sharingTutorialFirstTime(model: AppModel?) -> some View {
        sheet(isPresented: Binding { model?.isSharingTutorialDue ?? false } set: { if !$0 { model?.sharingTutorialClosed() } }) {
            TutorialSheet<SharingTutorialPage>()
        }
    }
}
