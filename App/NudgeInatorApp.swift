import SwiftUI

@main
struct NudgeInatorApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            // Ticket 22's tab shell replaces this and reads the model from the environment.
            Text("Nudge-inator")
                .environment(appDelegate.model)
        }
        // App opened (ticket 07): read from the App, the phase is `.active` while any scene is.
        // Repeats cost nothing, since both adapters change only what differs from the plan.
        .onChange(of: scenePhase) {
            guard scenePhase == .active, let model = appDelegate.model else { return }
            Task { await model.appOpened() }
        }
    }
}
