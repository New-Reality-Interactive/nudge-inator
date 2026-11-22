import SwiftUI

extension View {
    /// How Quiet Hours Work, opened by itself over the Quiet Hours page the first time the page opens
    /// (#468, `AppModel.isQuietHoursTutorialDue`). Closing it, however it closes, means it never
    /// opens by itself again; Settings' Tutorials row still opens it.
    func quietHoursTutorialFirstTime(model: AppModel?) -> some View {
        sheet(isPresented: Binding { model?.isQuietHoursTutorialDue ?? false } set: { if !$0 { model?.quietHoursTutorialClosed() } }) {
            TutorialSheet<QuietHoursTutorialPage>()
        }
    }
}
