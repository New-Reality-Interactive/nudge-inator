import NudgeEngine
import SwiftUI

/// Settings: the permission banners, what the app may send (notifications and alarms), a way to
/// open iOS Settings when something is off, Send a Test Nudge, the Default Pace, How It Nudges,
/// and Delete All Data.
struct SettingsTab: View {
    let state: ScreenState
    /// What previews show, since they have no app model: the permissions and how they leave
    /// each urgency reaching the person.
    var previewPermissions = PermissionStates()
    var previewReach = Reach(normal: .notification, high: .timeSensitiveNotification, urgent: .notification)

    @Environment(AppModel.self) private var model: AppModel?
    @State private var isConfirmingDelete = false
    @State private var deleteFailed = false
    /// When the latest test nudge was sent, so its row can say it is on its way.
    @State private var testNudgeSentAt: Date?
    /// The Default Pace previews show and change, since they have no app model.
    @State private var previewDefaultPace = DefaultPace.shipped

    var body: some View {
        NavigationStack {
            TabScreen(state: state) {
                List {
                    nudgesSection
                    dataSection
                }
            }
            .navigationTitle(Text(AppTab.settings.title))
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
                Text("This deletes every reminder, tag and all history from this iPhone, and cancels every nudge and alarm. It can't be undone.",
                     comment: "Settings: under the question asked before deleting everything.")
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
            if let openSettings = status.openSettings {
                Button {
                    openSettings.open()
                } label: {
                    SettingsRow(
                        tile: .tileGray,
                        symbol: "gearshape",
                        title: Text("Open iOS Settings", comment: "Settings: row that opens the app's page in the iOS Settings app, where notifications and alarms can be turned on."),
                        titleColor: .accentColor,
                        showsChevron: true
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
                HowItNudgesPage(previewPermissions: previewPermissions, previewDefaultPace: defaultPace.wrappedValue)
            } label: {
                SettingsRow(
                    tile: .tileGray,
                    symbol: "info.circle",
                    title: Text("How It Nudges", comment: "Settings: row that opens the page explaining how each strength nudges, and what onboarding said.")
                )
            }
        } header: {
            // The banners under the title, as the mockup's `viewSettings` puts them.
            VStack(alignment: .leading, spacing: Design.Spacing.s5) {
                PermissionBanners(reach: reach)
                Text("Nudges", comment: "Settings: header of the section with the permission rows, Send a Test Nudge, Default Pace and How It Nudges.")
            }
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
            Text("Your reminders stay on this iPhone. There's no account and no server, and nothing syncs to other devices.",
                 comment: "Settings: the privacy note under Your Data.")
        }
    }

    /// The model's Default Pace, read from its record each time. Without a model, the previews'.
    private var defaultPace: Binding<DefaultPace> {
        guard let model else { return $previewDefaultPace }
        return Binding { model.defaultPace } set: { model.defaultPace = $0 }
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

#Preview("Alarms allowed, Time Sensitive off") {
    SettingsTab(
        state: .ready,
        previewPermissions: PermissionStates(alarms: .allowed, timeSensitive: .off),
        previewReach: Reach(normal: .notification, high: .notification, urgent: .alarm)
    )
}
