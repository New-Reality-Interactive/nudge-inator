import NudgeEngine
import SwiftUI

/// Settings: the permission banners, About, what the app may send (notifications, alarms and
/// badges), a way to open iOS Settings when something is off, Send a Test Nudge, the Default Pace,
/// the Default Alarm Sound, How It Nudges, and Delete All Data.
struct SettingsTab: View {
    let state: ScreenState
    /// What previews show, since they have no app model: the permissions and how they leave
    /// each urgency reaching the person.
    var previewPermissions = PermissionStates()
    var previewReach = Reach(normal: .notification, high: .timeSensitiveNotification, urgent: .notification)
    /// The sharing pages pushed (ticket 196), which Change These on the "Connected" sheet sets.
    var path: Binding<[SharingPage]> = .constant([])

    @Environment(AppModel.self) private var model: AppModel?
    @State private var isConfirmingDelete = false
    @State private var deleteFailed = false
    /// When the latest test nudge was sent, so its row can say it is on its way.
    @State private var testNudgeSentAt: Date?
    /// The Default Pace previews show and change, since they have no app model.
    @State private var previewDefaultPace = DefaultPace.shipped
    /// The Default Alarm Sound previews show and change, since they have no app model.
    @State private var previewDefaultAlarmSound = AlarmSound.default
    /// The Sharing switch previews show and change, since they have no app model.
    @State private var previewSharingOn = false
    /// Whether the Turn Off Sharing sheet (#388) is up.
    @State private var isTurningSharingOff = false
    @State private var turnOffFailed = false
    /// Whether How Sharing Works (#423) is up. Local, so opening it changes no setting.
    @State private var isShowingSharingTutorial = false

    var body: some View {
        NavigationStack(path: path) {
            TabScreen(state: state) {
                List {
                    generalSection
                    sharingSection
                    nudgesSection
                    dataSection
                }
            }
            .settingsPages(sharing: model?.sharing)
            .sheet(isPresented: $isTurningSharingOff) {
                // Read live, so the sheet always says what confirming does: someone accepting an
                // invite meanwhile is counted.
                if case .confirm(let summary) = model?.sharingOff {
                    TurnOffSharingSheet(summary: summary) { choice in
                        try model?.turnSharingOff(choosing: choice)
                        isTurningSharingOff = false
                    }
                }
            }
            .onChange(of: model?.sharingOff) { _, off in
                // Nothing left to ask about, or Sharing is off: no sheet.
                if case .confirm = off {} else { isTurningSharingOff = false }
            }
            .alert(
                Text("Couldn't Turn Off Sharing", comment: "Settings and Turn Off Sharing's sheet: title of the message shown when turning Sharing off couldn't be saved."),
                isPresented: $turnOffFailed
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Settings and Turn Off Sharing's sheet: dismisses Couldn't Turn Off Sharing.")
                }
            } message: {
                Text("Nothing has changed. Try again.", comment: "Settings and Turn Off Sharing's sheet: under Couldn't Turn Off Sharing.")
            }
            .sheet(isPresented: $isShowingSharingTutorial) {
                SharingTutorialSheet()
            }
            .navigationTitle(Text(AppTab.settings.title))
            #if DEBUG
            .standInInviteWhileSharingOff(model: model)
            #endif
            .alert(
                Text("Delete All Data?", comment: "Settings: title of the question that asks before deleting everything."),
                isPresented: $isConfirmingDelete
            ) {
                Button(role: .cancel) {
                } label: {
                    Text("Cancel", comment: "Settings: keeps your data instead of deleting it.")
                }
                Button(role: .destructive, action: deleteAllData) {
                    Text("Delete", comment: "Settings: confirms deleting every reminder, tag and all history.")
                }
            } message: {
                if model?.sharing?.hasLiveConnections == true {
                    Text("This deletes every reminder, tag and all history from this iPhone, and cancels every nudge and alarm. It also disconnects everyone and deletes the reminders you've sent and received, here and in iCloud. It can't be undone.",
                         comment: "Settings: under the question asked before deleting everything, for a person with connections or invites.")
                } else {
                    Text("This deletes every reminder, tag and all history from this iPhone, and cancels every nudge and alarm. It can't be undone.",
                         comment: "Settings: under the question asked before deleting everything.")
                }
            }
            .alert(
                Text("Couldn't Delete Your Data", comment: "Settings: title of the message shown when deleting everything failed."),
                isPresented: $deleteFailed
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Settings: dismisses the message that deleting failed.")
                }
            } message: {
                Text("Nothing was deleted. Your reminders and their nudges are as they were. Try again.",
                     comment: "Settings: under the message shown when deleting everything failed.")
            }
        }
    }

    private var permissions: PermissionStates {
        model?.permissions ?? previewPermissions
    }

    private var status: SettingsStatus {
        SettingsStatus(permissions)
    }

    /// Delete All Data and Send a Test Nudge need the model. A store that isn't read shows through
    /// `TabScreen` instead of these rows, so the state needn't be checked again.
    private var canAct: Bool {
        model != nil
    }

    private var generalSection: some View {
        Section {
            NavigationLink {
                AboutPage()
            } label: {
                SettingsRow(
                    tile: .tileGray,
                    symbol: "iphone",
                    title: Text("About", comment: "Settings: row that opens the page with the privacy policy, support and the app's version and build number.")
                )
            }
        } header: {
            // The banners under the title, as the mockup's `viewSettings` puts them.
            VStack(alignment: .leading, spacing: Design.Spacing.s5) {
                PermissionBanners(reach: reach)
                Text("General", comment: "Settings: header of the first section, with the About row.")
            }
        }
    }

    /// The Sharing switch (#387), Connections (ticket 194) and Share Activity (#397) only while it's
    /// on, and last, on or off, How Sharing Works (#423). Off, none of sharing exists (the
    /// Sharing-switch mockup), but how it works can still be read.
    private var sharingSection: some View {
        Section {
            Toggle(isOn: sharingOn) {
                SettingsRow(
                    tile: .tileBlue,
                    symbol: "square.and.arrow.up",
                    title: Text("Sharing", comment: "Settings: the switch that turns sharing reminders with other people on or off, and the header of its section.")
                )
            }
            // Until sharing's store has been read, or while it won't open, it may hold connections
            // the other people would never hear were ended, so it can't turn off (#387). It says
            // nothing, as that's a moment after launch, or rare (#388's review).
            .disabled(model.map { !$0.canTurnSharingOff } ?? false)
            if let sharing = model?.sharing {
                NavigationLink(value: SharingPage.connections) {
                    let count = sharing.data.connections.count { $0.state == .connected }
                    SettingsRow(
                        tile: .tileGray,
                        symbol: "person.2",
                        title: Text("Connections", comment: "Connections: the page's title, and the Settings row that opens it."),
                        status: count == 0 ? nil : Text(count, format: .number)
                    )
                }
                NavigationLink(value: SharingPage.activity) {
                    SettingsRow(
                        tile: .tileGray,
                        symbol: "list.bullet.rectangle",
                        title: Text("Share Activity", comment: "Share Activity: the page's title, and the Settings row that opens it.")
                    )
                }
            }
            // Always the section's last row, with Sharing on or off (the mockup, 2026-11-15).
            Button {
                isShowingSharingTutorial = true
            } label: {
                SettingsRow(
                    tile: .tileGray,
                    symbol: "info.circle",
                    title: Text("How Sharing Works", comment: "How Sharing Works: the sheet's title, and the Settings row under Sharing that opens it."),
                    // It opens a sheet, not a page, so no chevron (the HIG keeps that for drilling in):
                    // the accent says it can be tapped, as Send a Test Nudge's does (#423's phone check).
                    titleColor: .accentColor
                )
            }
        } header: {
            Text("Sharing", comment: "Settings: the switch that turns sharing reminders with other people on or off, and the header of its section.")
        } footer: {
            Text("Connect with people through iCloud to send each other reminders.",
                 comment: "Settings: under the Sharing switch.")
        }
    }

    /// The model's Sharing switch. Without a model, the previews'.
    private var sharingOn: Binding<Bool> {
        guard let model else { return $previewSharingOn }
        return Binding { model.isSharingOn } set: { on in
            guard !on else { return model.setSharing(on: true) }
            // Anything it would delete is asked about first, as every destructive action is, and the
            // switch stays on until the person confirms (#388).
            switch model.sharingOff {
            case .confirm:
                isTurningSharingOff = true
            case .atOnce:
                do { try model.turnSharingOff(choosing: .remove) } catch { turnOffFailed = true }
            case .notYet, nil:
                break
            }
        }
    }

    private var nudgesSection: some View {
        Section {
            SettingsRow(
                tile: .tileRed,
                symbol: "bell",
                title: Text("Notifications", comment: "Settings: row that shows whether notifications are allowed."),
                status: status.notifications.text,
                statusIsNegative: status.notifications.isOff
            )
            SettingsRow(
                tile: .tileOrange,
                symbol: "alarm",
                title: Text("Alarms", comment: "Settings: row that shows whether alarms are allowed."),
                status: status.alarms.text,
                statusIsNegative: status.alarms.isOff
            )
            // Gray even when Off: badges off isn't a problem to flag (DESIGN.md › Settings row).
            SettingsRow(
                tile: .tileRed,
                symbol: "app.badge",
                title: Text("Badges", comment: "Settings: row that shows whether the app icon may show a badge with how many reminders are nudging."),
                status: status.badges.text
            )
            if let openSettings = status.openSettings {
                Button {
                    openSettings.open()
                } label: {
                    SettingsRow(
                        tile: .tileGray,
                        symbol: "gearshape",
                        title: Text("Open iOS Settings", comment: "Settings: row that opens the app's page in the iOS Settings app, where notifications, alarms and badges can be turned on."),
                        titleColor: .accentColor,
                        accessory: .chevron
                    )
                }
            }
            Button(action: sendTestNudge) {
                SettingsRow(
                    tile: .tileBlue,
                    symbol: "bell",
                    title: Text("Send a Test Nudge", comment: "Settings: row that sends a notification in a few seconds, to see how a nudge looks."),
                    titleColor: status.canSendTestNudge && canAct ? .accentColor : Color(uiColor: .secondaryLabel),
                    status: testNudgeSentAt == nil ? nil : Text("Sent", comment: "Settings: shown beside Send a Test Nudge for a few seconds after it was tapped, while the test nudge is on its way.")
                )
            }
            .disabled(!status.canSendTestNudge || !canAct)
            NavigationLink {
                DefaultPacePage(defaultPace: defaultPace)
            } label: {
                SettingsRow(
                    tile: .tileGray,
                    symbol: "clock",
                    title: Text("Default Pace", comment: "Settings: row that opens the page setting the pace every new reminder starts with. Under it, that pace, such as \"Consistent · 10 min\"."),
                    value: Text(defaultPace.wrappedValue.pace.title)
                )
            }
            NavigationLink {
                DefaultAlarmSoundPage(sound: defaultAlarmSound)
            } label: {
                SettingsRow(
                    tile: .tileGray,
                    symbol: "speaker.wave.2",
                    title: DefaultAlarmSoundPage.title,
                    value: Text(defaultAlarmSound.wrappedValue.title)
                )
            }
            NavigationLink {
                HowItNudgesPage(previewPermissions: previewPermissions, previewDefaultPace: defaultPace.wrappedValue)
            } label: {
                SettingsRow(
                    tile: .tileGray,
                    symbol: "info.circle",
                    title: Text("How It Nudges", comment: "Settings: row that opens the page explaining how each strength nudges, and what onboarding said.")
                )
            }
        } header: {
            Text("Nudges", comment: "Settings: header of the section with the permission rows, Send a Test Nudge, Default Pace, Default Alarm Sound and How It Nudges.")
        } footer: {
            VStack(alignment: .leading, spacing: Design.Spacing.s2) {
                ForEach(SettingsStatus.footer(for: reach), id: \.self) { $0.text }
            }
        }
        .task(id: testNudgeSentAt) {
            guard testNudgeSentAt != nil else { return }
            // Until the test nudge has arrived, and a moment past it.
            try? await Task.sleep(for: .seconds(NotificationAdapter.testNudgeDelay + 1))
            testNudgeSentAt = nil
        }
    }

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                SettingsRow(
                    tile: .tileRed,
                    symbol: "trash",
                    title: Text("Delete All Data", comment: "Settings: row that opens the question that asks before deleting every reminder, tag and all history."),
                    titleColor: .negative
                )
            }
            .disabled(!canAct)
        } header: {
            Text("Your Data", comment: "Settings: header of the section with Delete All Data.")
        } footer: {
            Text("Your own reminders stay on this iPhone. Reminders you send or receive via an approved share, go through your iCloud. There's no account and no server of ours involved.",
                 comment: "Settings: the privacy note under Your Data.")
        }
    }

    /// The model's Default Pace, read from its record each time. Without a model, the previews'.
    private var defaultPace: Binding<DefaultPace> {
        guard let model else { return $previewDefaultPace }
        return Binding { model.defaultPace } set: { model.defaultPace = $0 }
    }

    /// The model's Default Alarm Sound, read from its record each time. Without a model, the previews'.
    private var defaultAlarmSound: Binding<AlarmSound> {
        guard let model else { return $previewDefaultAlarmSound }
        return Binding { model.defaultAlarmSound } set: { model.defaultAlarmSound = $0 }
    }

    /// How each urgency reaches the person, from the engine. Without a model, the previews' states.
    private var reach: Reach {
        model?.engine.reach ?? previewReach
    }

    private func sendTestNudge() {
        guard let model else { return }
        testNudgeSentAt = .now
        Task { await model.sendTestNudge() }
    }

    private func deleteAllData() {
        guard let model else { return }
        Task {
            do {
                try await model.deleteAllData()
            } catch {
                deleteFailed = true
            }
        }
    }
}

#Preview("Light") {
    SettingsTab(state: .ready)
}

#Preview("Dark") {
    SettingsTab(state: .ready)
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    SettingsTab(state: .ready)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Landscape", traits: .landscapeLeft) {
    SettingsTab(state: .ready)
}

#Preview("Notifications off, alarms off") {
    SettingsTab(
        state: .ready,
        previewPermissions: PermissionStates(notifications: .denied, alarms: .denied),
        previewReach: Reach(normal: nil, high: nil, urgent: nil)
    )
}

#Preview("Badges off") {
    SettingsTab(state: .ready, previewPermissions: PermissionStates(alarms: .allowed, badges: .denied))
}

#Preview("Alarms allowed, Time Sensitive off") {
    SettingsTab(
        state: .ready,
        previewPermissions: PermissionStates(alarms: .allowed, timeSensitive: .off),
        previewReach: Reach(normal: .notification, high: .notification, urgent: .alarm)
    )
}
