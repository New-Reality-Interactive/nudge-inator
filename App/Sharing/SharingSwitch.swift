import Foundation
import Observation

/// Settings' Sharing switch (#387, #388): makes the sharing model when it turns on and lets it go
/// when it turns off, and keeps the choice in its record. Off with disconnects or revoked invites
/// still to reach iCloud, the model winds down out of sight: nothing shows it and it takes in
/// nothing, but its adapter keeps sending until they have gone, through relaunches, and only then
/// stops (`SharingModel.windDown`). Turning on meanwhile carries on with that model, which is
/// empty, so it still starts fresh.
@MainActor
@Observable
final class SharingSwitch {
    /// Exactly one of these at a time, and the record follows it.
    enum State {
        case off
        /// Sharing shows on the screens.
        case on(SharingModel)
        /// Switched off, the model still sending what it holds, out of sight.
        case windingDown(SharingModel)
    }

    /// The record is written on every change, so it can never disagree with this.
    private(set) var state: State {
        didSet { persist() }
    }

    /// The sharing the screens show, or `nil` while the switch is off.
    var model: SharingModel? {
        if case .on(let model) = state { model } else { nil }
    }

    @ObservationIgnored private let record: SharingSwitchRecord
    /// Makes the sharing model, or `nil` where the app has none to make.
    @ObservationIgnored private let make: () -> SharingModel?
    /// What a model on show reports to: the app model.
    @ObservationIgnored private weak var host: (any ReceivedReminders & SenderNoticePosting)?

    /// `model` is on for this launch whatever the record says (the Debug stand-in, and tests). The
    /// record isn't written until the switch changes.
    init(model: SharingModel?, record: SharingSwitchRecord, make: @escaping () -> SharingModel?) {
        state = model.map(State.on) ?? .off
        self.record = record
        self.make = make
    }

    /// Hands the model on show, if any, what it reports to, then makes sharing as the record says.
    func start(reportingTo host: any ReceivedReminders & SenderNoticePosting) {
        self.host = host
        if case .on(let model) = state { adopt(model) }
        makeAsRecorded()
    }

    /// Makes the model the record asks for, if none is made yet: at start, and again once the
    /// reminder store opens, since the record reads off before the first unlock. On lets the app ask
    /// iCloud (#387), and launch's account read follows. Winding down carries on where the last
    /// launch left off.
    func makeAsRecorded() {
        guard case .off = state else { return }
        if record.isOn {
            turnOn(asking: false)
        } else if record.isWindingDown, let made = make() {
            windDown(made)
        }
    }

    /// Turns the switch on, asking iCloud at once so without it the paused messages (#210) say why.
    func turnOn() {
        turnOn(asking: true)
    }

    private func turnOn(asking: Bool) {
        switch state {
        case .on:
            return
        case .windingDown(let model):
            // Carries on with the same model, empty, so there's never a second sync for one database.
            model.stopWindingDown()
            adopt(model)
            state = .on(model)
            model.allowICloud(refreshing: asking)
        case .off:
            guard let made = make() else { return }
            adopt(made)
            state = .on(made)
            made.allowICloud(refreshing: asking)
        }
    }

    /// Turns the switch off: the model leaves the screens at once, and winds down until what it
    /// still has to send has gone. The caller has emptied it first.
    func turnOff() {
        guard case .on(let model) = state else { return }
        model.receivedReminders = nil
        model.noticePoster = nil
        windDown(model)
    }

    private func windDown(_ model: SharingModel) {
        state = .windingDown(model)
        model.windDown { [weak self, weak model] in
            guard let self, case .windingDown(let current) = state, current === model else { return }
            state = .off
        }
    }

    private func adopt(_ model: SharingModel) {
        model.receivedReminders = host
        model.noticePoster = host
    }

    private func persist() {
        switch state {
        case .off:
            record.isOn = false
            record.isWindingDown = false
        case .on:
            record.isOn = true
            record.isWindingDown = false
        case .windingDown:
            record.isOn = false
            record.isWindingDown = true
        }
    }
}
