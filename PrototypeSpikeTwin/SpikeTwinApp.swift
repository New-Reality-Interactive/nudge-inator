// PROTOTYPE: ticket 02 spike. A second app (own bundle ID, no widget extension) to test
// whether the alarm limit is per app or shared across apps.
import SwiftUI

@main
struct SpikeTwinApp: App {
    var body: some Scene {
        WindowGroup {
            SpikeView(model: SpikeModel(label: "Twin", tint: .purple))
        }
    }
}
