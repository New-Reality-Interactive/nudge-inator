// PROTOTYPE: ticket 02 spike. Same Open intent, compiled into the app target instead of
// NudgeShared, to tell "package intent not found" apart from other failures.
import AppIntents
import Foundation
import NudgeShared

struct SpikeAppOpenIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Open (spike, app target)"
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Alarm ID") var alarmID: String

    init() {}
    init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

    func perform() async throws -> some IntentResult {
        SpikeLog.write("OPEN(app target) ran, mode=\(systemContext.currentMode)")
        return .result()
    }
}
