// PROTOTYPE: ticket 02 AlarmKit spike. Throwaway; lives only on prototype/alarmkit-spike.
import AlarmKit
import NudgeShared
import SwiftUI

struct SpikeView: View {
    @State var model: SpikeModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section("Device") {
                    Text(model.osVersion)
                    Text(SpikeLog.processDescription).font(.caption)
                    LabeledContent("Authorization", value: model.authorization)
                    Button("Request authorization") { Task { await model.requestAuthorization() } }
                }
                Section("Ring soon (B, C, D, E, F)") {
                    Stepper("In \(model.secondsAhead) s", value: $model.secondsAhead, in: 5...600, step: 5)
                    Picker("Open button", selection: $model.openVariant) {
                        ForEach(SpikeOpenVariant.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Open also calls stop(id:)", isOn: $model.stopInsideOpen)
                    Button("Schedule one alert-only alarm") { Task { await model.scheduleSoon() } }
                }
                Section("Limit (A)") {
                    Button("Schedule far-future until maximumLimitReached") { Task { await model.fillToLimit() } }
                    Button("Schedule one far-future") { Task { await model.scheduleOneFarFuture() } }
                    Button("Cancel one scheduled") { model.cancelOne() }
                    Button("Stop or cancel all", role: .destructive) { Task { await model.stopOrCancelAll() } }
                }
                Section("Status") {
                    Text(model.status).font(.callout)
                }
                Section("Alarms (\(model.alarms.count))") {
                    ForEach(model.alarms.prefix(20)) { alarm in
                        VStack(alignment: .leading) {
                            Text("\(alarm.id.uuidString.prefix(8)) · \(String(describing: alarm.state))")
                            Text(String(describing: alarm.schedule)).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    if model.alarms.count > 20 { Text("…and \(model.alarms.count - 20) more") }
                }
                Section {
                    Text(model.log.isEmpty ? "(empty)" : model.log)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                } header: {
                    HStack {
                        Text("Log (all processes)")
                        Spacer()
                        Button("Clear") { model.clearLog() }
                    }
                }
            }
            .navigationTitle("\(model.label) spike")
        }
        .task { await model.start() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            SpikeLog.write("app scenePhase=\(phase)")
        }
    }
}

#Preview {
    SpikeView(model: SpikeModel(label: "Preview", tint: .orange))
}
