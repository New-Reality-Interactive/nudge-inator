import SwiftUI

/// First launch (the mockup's `onboardSheet`): how nudges reach you, then one Continue that raises
/// the notification prompt and then the alarm prompt. No close or cancel: the HIG's pre-alert
/// screen has one button and always leads to the system prompt. Presented as a full-screen cover,
/// which scrolls, so it works in landscape and at the largest text size.
struct OnboardingView: View {
    let step: AppModel.Onboarding
    /// While the prompts are up, so a second tap does nothing.
    let isAsking: Bool
    let continueToPrompts: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.Spacing.s5) {
                title
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
                switch step {
                case .welcome: WelcomeFeatures()
                case .alarmsOnly: WelcomeFeature.ringsAsAlarms.view
                }
                Button(action: continueToPrompts) {
                    Text("Continue", comment: "Onboarding: the only button, which goes on to the system's permission prompts.")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: Design.Spacing.rowMin)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAsking)
            }
            .padding(.horizontal, Design.Spacing.s5)
            .padding(.vertical, Design.Spacing.s5)
        }
        .centeredInReadableColumn()
        .background(Color(uiColor: .systemBackground))
        // Belt and braces: a full-screen cover has no swipe to dismiss, and Apple's docs don't
        // say it can't gain one.
        .interactiveDismissDisabled()
    }

    private var title: Text {
        switch step {
        case .welcome:
            Text("Welcome to \(Bundle.appDisplayName)", comment: "Onboarding: the title of the first-launch screen. The placeholder is the app's name.")
        case .alarmsOnly:
            Text("Alarms for Urgent Nudges", comment: "Onboarding: the title of the screen before the alarm prompt, when only alarms are still to be asked for.")
        }
    }
}

/// The welcome's four points, also at the top of Settings' How It Nudges, so they can be found
/// again (HIG, Onboarding).
struct WelcomeFeatures: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s5) {
            ForEach(WelcomeFeature.allCases, id: \.self) { $0.view }
        }
    }
}

enum WelcomeFeature: CaseIterable {
    case nudgesUntilDone
    case ringsAsAlarms
    case chooseWhatBreaksThrough
    case staysOnYourIPhone

    var view: some View {
        HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.s4) {
            Image(systemName: systemImage)
                .font(.title2)
                // Not the accent, which the mockup uses: DESIGN.md keeps it for things you can tap.
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .frame(minWidth: Design.Spacing.s5 + Design.Spacing.s4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                title.font(.headline)
                text
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var systemImage: String {
        switch self {
        case .nudgesUntilDone: "bell"
        case .ringsAsAlarms: "alarm"
        case .chooseWhatBreaksThrough: "moon.fill"
        case .staysOnYourIPhone: "lock"
        }
    }

    private var title: Text {
        switch self {
        case .nudgesUntilDone: Text("Nudges until you're done", comment: "Onboarding and How It Nudges: the title of the first point.")
        case .ringsAsAlarms: Text("Urgent nudges ring as alarms", comment: "Onboarding and How It Nudges: the title of the point about alarms.")
        case .chooseWhatBreaksThrough: Text("You choose what breaks through", comment: "Onboarding and How It Nudges: the title of the point about Break Through Focus.")
        case .staysOnYourIPhone: Text("Stays on your iPhone", comment: "Onboarding and How It Nudges: the title of the point about privacy.")
        }
    }

    private var text: Text {
        switch self {
        case .nudgesUntilDone:
            Text("Reminders keep coming back until you tap Done: at a steady pace, or more often and more insistently.", comment: "Onboarding and How It Nudges: under \"Nudges until you're done\".")
        case .ringsAsAlarms:
            Text("When it really matters, your iPhone rings and vibrates like an alarm, even on silent and in a Focus. Stopping the alarm only quiets it: the next nudge still comes, and only Done ends the reminder.", comment: "Onboarding and How It Nudges: under \"Urgent nudges ring as alarms\".")
        case .chooseWhatBreaksThrough:
            Text("Each Gentle or Firm reminder has a Break Through Focus switch. Turn it off and a Focus can hold its nudges, and nothing rings. Relentless always breaks through.", comment: "Onboarding and How It Nudges: under \"You choose what breaks through\".")
        case .staysOnYourIPhone:
            Text("No account and no server. Your reminders stay on this iPhone and in your own backups.", comment: "Onboarding and How It Nudges: under \"Stays on your iPhone\".")
        }
    }
}

#Preview("Welcome") {
    OnboardingView(step: .welcome, isAsking: false) {}
}

#Preview("Welcome, largest text, dark") {
    OnboardingView(step: .welcome, isAsking: false) {}
        .dynamicTypeSize(.accessibility5)
        .preferredColorScheme(.dark)
}

#Preview("Alarms only") {
    OnboardingView(step: .alarmsOnly, isAsking: false) {}
}
