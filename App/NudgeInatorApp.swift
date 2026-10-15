import SwiftUI
import NudgeEngine
import NudgeShared

@main
struct NudgeInatorApp: App {
    var body: some Scene {
        WindowGroup {
            // PROTOTYPE: ticket 02 spike screen; main keeps the plain Text.
            SpikeView(model: SpikeModel(label: "Nudge", tint: .orange))
        }
    }
}
