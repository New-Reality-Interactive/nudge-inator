import NudgeEngine
import SwiftUI

/// Settings' How It Nudges page (ticket 31): the welcome's points, so they can be found again
/// after onboarding, then each strength's ladder with Break Through Focus on, from the engine.
/// It reads the model's engine itself, so it follows a permission changed while it is open.
struct HowItNudgesPage: View {
    /// What previews show, since they have no app model.
    var previewPermissions = PermissionStates(alarms: .allowed)

    @Environment(AppModel.self) private var model: AppModel?

    var body: some View {
        List {
            Section {
                WelcomeFeatures()
                    .padding(.vertical, Design.Spacing.s2)
            } footer: {
                Text("Below is how each strength nudges a reminder with Break Through Focus on.", comment: "How It Nudges page: under the points at the top, before the three strengths' schedules.")
            }
            ForEach(Strength.formOrder, id: \.self) { strength in
                HowItNudgesSection(howItNudges: engine.howItNudges(strength, breakThroughFocus: true)) {
                    Text(strength.title)
                }
            }
        }
        .centeredInReadableColumn()
        .navigationTitle(Text("How It Nudges", comment: "Title of the page in Settings that explains how each strength nudges."))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var engine: Engine {
        model?.engine ?? Engine(clock: SystemClock(), scheduler: PreviewScheduler(), permissions: previewPermissions)
    }
}

#Preview("Every permission") {
    NavigationStack {
        HowItNudgesPage()
    }
}

#Preview("Notifications off, largest text") {
    NavigationStack {
        HowItNudgesPage(previewPermissions: PermissionStates(notifications: .denied, alarms: .allowed))
    }
    .dynamicTypeSize(.accessibility5)
}
