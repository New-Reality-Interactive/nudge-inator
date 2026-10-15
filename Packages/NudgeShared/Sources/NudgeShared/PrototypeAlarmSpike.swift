// PROTOTYPE: ticket 02 AlarmKit spike. Throwaway; lives only on prototype/alarmkit-spike.
import AlarmKit
import AppIntents
import Foundation

public struct SpikeMetadata: AlarmMetadata {
    public init() {}
}

/// Signpost so the system finds the intents compiled into this package (AppIntentsPackage docs).
public struct NudgeSharedIntents: AppIntentsPackage {}

/// Appends to a file in the App Group container so lines written by any process
/// (app or widget extension) end up in one place the debug screen can show.
public enum SpikeLog {
    static var url: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NudgeShared.appGroup)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appending(path: "PROTOTYPE-alarm-spike-log.txt")
    }

    public static var processDescription: String {
        "\(Bundle.main.bundleIdentifier ?? "?") [\(ProcessInfo.processInfo.processName) pid \(ProcessInfo.processInfo.processIdentifier)]"
    }

    public static func write(_ message: String) {
        let stamp = Date().formatted(.dateTime.hour().minute().second())
        let line = "\(stamp) \(message) — \(processDescription)\n"
        let data = Data(line.utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }

    public static func read() -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}

/// Open button, using the iOS 26 replacement for openAppWhenRun.
public struct SpikeOpenIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Open (spike, supportedModes)"
    public static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Alarm ID") public var alarmID: String
    @Parameter(title: "Stop in intent") public var stopsAlarm: Bool

    public init() {}
    public init(alarmID: UUID, stopsAlarm: Bool) {
        self.alarmID = alarmID.uuidString
        self.stopsAlarm = stopsAlarm
    }

    public func perform() async throws -> some IntentResult {
        SpikeLog.write("OPEN(supportedModes) ran, mode=\(systemContext.currentMode), stopsAlarm=\(stopsAlarm)")
        await spikeStop(alarmID: alarmID, if: stopsAlarm)
        return .result()
    }
}

/// Same Open button with the deprecated flag WWDC25-230 shows, for comparison.
public struct SpikeOpenLegacyIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Open (spike, openAppWhenRun)"
    public static let openAppWhenRun = true

    @Parameter(title: "Alarm ID") public var alarmID: String
    @Parameter(title: "Stop in intent") public var stopsAlarm: Bool

    public init() {}
    public init(alarmID: UUID, stopsAlarm: Bool) {
        self.alarmID = alarmID.uuidString
        self.stopsAlarm = stopsAlarm
    }

    public func perform() async throws -> some IntentResult {
        SpikeLog.write("OPEN(openAppWhenRun) ran, stopsAlarm=\(stopsAlarm)")
        await spikeStop(alarmID: alarmID, if: stopsAlarm)
        return .result()
    }
}

/// Logs that the system Stop button ran, and in which process.
public struct SpikeStopIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Stop (spike)"

    @Parameter(title: "Alarm ID") public var alarmID: String

    public init() {}
    public init(alarmID: UUID) { self.alarmID = alarmID.uuidString }

    public func perform() async throws -> some IntentResult {
        SpikeLog.write("STOP intent ran for \(alarmID.prefix(8))")
        return .result()
    }
}

private func spikeStop(alarmID: String, if shouldStop: Bool) async {
    guard shouldStop, let id = UUID(uuidString: alarmID) else { return }
    do {
        try AlarmManager.shared.stop(id: id)
        SpikeLog.write("stop(id:) inside intent succeeded for \(alarmID.prefix(8))")
    } catch {
        SpikeLog.write("stop(id:) inside intent threw \(error)")
    }
}
