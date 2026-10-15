import WidgetKit
import SwiftUI
import NudgeShared

// Empty on purpose: AlarmKit expects a widget extension, and v2 may add widgets here.
@main
struct NudgeWidgets: WidgetBundle {
    var body: some Widget {
        EmptyWidget()
    }
}

struct EmptyWidget: Widget {
    var body: some WidgetConfiguration {
        EmptyWidgetConfiguration()
    }
}

// PROTOTYPE: ticket 02 spike. Lets the extension find the Open intent compiled into NudgeShared.
import AppIntents

struct SpikeWidgetIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [NudgeSharedIntents.self] }
}
