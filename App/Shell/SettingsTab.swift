import SwiftUI

/// Settings has no empty state in the mockup: its rows show the permissions and actions, which
/// ticket 30 builds. Until then it shows only the mockup's privacy note. It doesn't read the
/// store, so it looks the same whatever the launch state.
struct SettingsTab: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                } footer: {
                    Text("Your reminders stay on this iPhone. There's no account and no server, and nothing syncs to other devices.",
                         comment: "Settings: the privacy note under Your Data.")
                }
            }
            .navigationTitle(Text(AppTab.settings.title))
        }
    }
}

#Preview("Light") {
    SettingsTab()
}

#Preview("Dark") {
    SettingsTab()
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    SettingsTab()
        .environment(\.dynamicTypeSize, .accessibility5)
}
