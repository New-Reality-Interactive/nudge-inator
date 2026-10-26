import NudgeEngine
import SwiftUI

/// Settings' How It Nudges page (ticket 31): the welcome's points, so they can be found again
/// after onboarding, then each strength's ladder at the Default Pace with Break Through Focus on,
/// from the engine (enhancement-pace ticket 10). It reads the model's engine and Default Pace
/// itself, so it follows a permission changed while it is open, and a Default Pace changed since.
struct HowItNudgesPage: View {
    /// What previews show, since they have no app model.
    var previewPermissions = PermissionStates(alarms: .allowed)
    var previewDefaultPace = DefaultPace.shipped

    @Environment(AppModel.self) private var model: AppModel?

    var body: some View {
        // Built once, so the intro and the sections read the same Default Pace.
        let content = pageContent
        List {
            Section {
                WelcomeFeatures()
                    .padding(.vertical, Design.Spacing.s2)
            } footer: {
                Text(content.intro)
            }
            ForEach(content.sections, id: \.strength) { section in
                HowItNudgesSection(howItNudges: section.howItNudges) {
                    Text(section.strength.title)
                }
            }
        }
        .centeredInReadableColumn()
        .navigationTitle(Text("How It Nudges", comment: "Title of the page in Settings that explains how each strength nudges."))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var pageContent: HowItNudgesPageContent {
        if let model { return HowItNudgesPageContent(model: model) }
        return HowItNudgesPageContent(pace: previewDefaultPace.pace, engine: Engine(clock: SystemClock(), scheduler: NoOpScheduler(), permissions: previewPermissions))
    }
}

#Preview("Every permission") {
    NavigationStack {
        HowItNudgesPage()
    }
}

#Preview("Escalating") {
    NavigationStack {
        HowItNudgesPage(previewDefaultPace: DefaultPace(choice: .escalating, consistentWait: 10 * 60))
    }
}

#Preview("Notifications off, largest text") {
    NavigationStack {
        HowItNudgesPage(previewPermissions: PermissionStates(notifications: .denied, alarms: .allowed))
    }
    .dynamicTypeSize(.accessibility5)
}
