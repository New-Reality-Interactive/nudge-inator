// PROTOTYPE: ticket 02 AlarmKit spike. Throwaway; lives only on prototype/alarmkit-spike.
import AlarmKit
import AppIntents
import NudgeShared
import SwiftUI

struct SpikeIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [NudgeSharedIntents.self] }
}

enum SpikeOpenVariant: String, CaseIterable, Identifiable {
    case supportedModes, openAppWhenRun, appTarget, none
    var id: Self { self }
}

@MainActor
@Observable
final class SpikeModel {
    let label: String
    let tint: Color
    var alarms: [Alarm] = []
    var authorization = "?"
    var status = ""
    var log = ""
    var secondsAhead = 10
    var openVariant = SpikeOpenVariant.supportedModes
    var stopInsideOpen = true

    init(label: String, tint: Color) {
        self.label = label
        self.tint = tint
    }

    var osVersion: String {
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var build = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &build, &size, nil, 0)
        let buildString = String(decoding: build.prefix(while: { $0 != 0 }).map(UInt8.init), as: UTF8.self)
        return "iOS \(UIDevice.current.systemVersion) (\(buildString))"
    }

    func start() async {
        refreshLog()
        authorization = "\(AlarmManager.shared.authorizationState)"
        Task { [weak self] in
            for await state in AlarmManager.shared.authorizationUpdates {
                self?.authorization = "\(state)"
            }
        }
        Task { [weak self] in
            for await incoming in AlarmManager.shared.alarmUpdates {
                self?.alarms = incoming
            }
        }
        // Lets the simulator pass run unattended: `simctl launch … -spikeAuto`.
        if ProcessInfo.processInfo.arguments.contains("-spikeAuto") {
            SpikeLog.write("AUTO start \(osVersion)")
            await requestAuthorization()
            SpikeLog.write("AUTO authorization=\(authorization) \(status)")
            await fillToLimit()
            SpikeLog.write("AUTO fill: \(status)")
            secondsAhead = 15
            await scheduleSoon()
            SpikeLog.write("AUTO soon: \(status)")
        }
        if ProcessInfo.processInfo.arguments.contains("-spikeSoon") {
            secondsAhead = 15
            await scheduleSoon()
            SpikeLog.write("AUTO soon only: \(status)")
        }
        // The log is written by other processes too, so poll it.
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.refreshLog()
            }
        }
    }

    func refreshLog() {
        log = SpikeLog.read()
        alarms = (try? AlarmManager.shared.alarms) ?? alarms
    }

    func requestAuthorization() async {
        do {
            authorization = "\(try await AlarmManager.shared.requestAuthorization())"
        } catch {
            status = "requestAuthorization threw \(error)"
        }
    }

    func scheduleSoon() async {
        let date = Date.now.addingTimeInterval(TimeInterval(secondsAhead))
        if let id = await schedule(at: date, title: "\(label): ring in \(secondsAhead)s") {
            status = "Scheduled \(id.uuidString.prefix(8)) for \(date.formatted(date: .omitted, time: .standard)), open=\(openVariant.rawValue), stopInOpen=\(stopInsideOpen)"
            SpikeLog.write("scheduled soon \(id.uuidString.prefix(8)) open=\(openVariant.rawValue) stopInOpen=\(stopInsideOpen)")
        }
    }

    func scheduleOneFarFuture() async {
        let index = alarms.count + 1
        if let id = await schedule(at: farFutureDate(index: index), title: "\(label): far #\(index)") {
            status = "Scheduled far-future \(id.uuidString.prefix(8)); app now has \(alarms.count + 1)"
        }
    }

    /// Schedules far-future one-shots until AlarmKit refuses, to measure the limit.
    func fillToLimit(cap: Int = 1000) async {
        var added = 0
        status = "Filling…"
        while added < cap {
            let index = alarms.count + added + 1
            let id = UUID()
            do {
                try await Self.scheduleAlarm(id: id, date: farFutureDate(index: index), title: "\(label): far #\(index)", variant: openVariant, stopInsideOpen: stopInsideOpen, tint: tint)
                added += 1
            } catch let error as AlarmManager.AlarmError {
                let total = ((try? AlarmManager.shared.alarms) ?? []).count
                status = "Stopped after adding \(added): \(error). App now has \(total) alarms."
                SpikeLog.write("fillToLimit: added \(added), threw \(error), total \(total)")
                refreshLog()
                return
            } catch {
                status = "Stopped after adding \(added): unexpected \(error)"
                SpikeLog.write("fillToLimit: added \(added), unexpected \(error)")
                return
            }
        }
        let total = ((try? AlarmManager.shared.alarms) ?? []).count
        status = "No limit hit: added \(cap), app now has \(total). Press again to keep going."
        SpikeLog.write("fillToLimit: no limit after \(cap), total \(total)")
        refreshLog()
    }

    func cancelOne() {
        guard let alarm = alarms.first(where: { $0.state == .scheduled }) else { return }
        do {
            try AlarmManager.shared.cancel(id: alarm.id)
            status = "Cancelled \(alarm.id.uuidString.prefix(8))"
        } catch {
            status = "cancel threw \(error)"
        }
        refreshLog()
    }

    func stopOrCancelAll() async {
        status = "Stopping/cancelling all…"
        let failures = await Self.stopOrCancelAllOffMain()
        status = "Stopped/cancelled all, \(failures) failures"
        SpikeLog.write("stopOrCancelAll, failures \(failures)")
        refreshLog()
    }

    // cancel(id:) is synchronous; a thousand of them on the main actor hangs the UI.
    nonisolated private static func stopOrCancelAllOffMain() async -> Int {
        var failures = 0
        for alarm in (try? AlarmManager.shared.alarms) ?? [] {
            do {
                if alarm.state == .alerting {
                    try AlarmManager.shared.stop(id: alarm.id)
                } else {
                    try AlarmManager.shared.cancel(id: alarm.id)
                }
            } catch {
                failures += 1
            }
        }
        return failures
    }

    func clearLog() {
        SpikeLog.clear()
        refreshLog()
    }

    private func farFutureDate(index: Int) -> Date {
        Date.now.addingTimeInterval(60 * 60 * 24 * 300 + TimeInterval(index * 60))
    }

    private func schedule(at date: Date, title: String) async -> UUID? {
        let id = UUID()
        do {
            try await Self.scheduleAlarm(id: id, date: date, title: title, variant: openVariant, stopInsideOpen: stopInsideOpen, tint: tint)
            refreshLog()
            return id
        } catch {
            status = "schedule threw \(error)"
            SpikeLog.write("schedule threw \(error)")
            return nil
        }
    }

    // AlarmConfiguration isn't Sendable, so build and schedule it off the main actor in one place.
    nonisolated private static func scheduleAlarm(id: UUID, date: Date, title: String, variant openVariant: SpikeOpenVariant, stopInsideOpen: Bool, tint: Color) async throws {
        let openButton = AlarmButton(text: "Open", textColor: .white, systemImageName: "arrow.up.forward.app")
        let alert: AlarmPresentation.Alert
        let secondaryIntent: (any LiveActivityIntent)?
        switch openVariant {
        case .supportedModes:
            alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title), secondaryButton: openButton, secondaryButtonBehavior: .custom)
            secondaryIntent = SpikeOpenIntent(alarmID: id, stopsAlarm: stopInsideOpen)
        case .openAppWhenRun:
            alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title), secondaryButton: openButton, secondaryButtonBehavior: .custom)
            secondaryIntent = SpikeOpenLegacyIntent(alarmID: id, stopsAlarm: stopInsideOpen)
        case .appTarget:
            alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title), secondaryButton: openButton, secondaryButtonBehavior: .custom)
            secondaryIntent = SpikeAppOpenIntent(alarmID: id)
        case .none:
            alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title))
            secondaryIntent = nil
        }
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert), metadata: SpikeMetadata(), tintColor: tint)
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(date),
            attributes: attributes,
            stopIntent: SpikeStopIntent(alarmID: id),
            secondaryIntent: secondaryIntent
        )
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
    }
}
