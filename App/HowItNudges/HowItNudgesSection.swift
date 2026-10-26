import NudgeEngine
import SwiftUI

/// DESIGN.md's How It Nudges: an inset grouped section of footnote rows, each leading with a small
/// urgency dot, then which nudges, when, the urgency word and the Via label, with the summary in
/// the footer. Reminder details, the form and the Settings page all draw it from the engine.
struct HowItNudgesSection<Header: View>: View {
    let howItNudges: HowItNudges
    @ViewBuilder var header: Header

    var body: some View {
        Section {
            ForEach(howItNudges.rows, id: \.nudges) { HowItNudgesRowView(row: $0) }
        } header: {
            header
        } footer: {
            VStack(alignment: .leading, spacing: Design.Spacing.s2) {
                ForEach(HowItNudgesSentence.summary(of: howItNudges), id: \.self) { $0.text }
            }
        }
    }
}

extension HowItNudgesSection where Header == Text {
    /// Headed "How It Nudges", as on reminder details and the form.
    init(howItNudges: HowItNudges) {
        self.howItNudges = howItNudges
        header = Text("How It Nudges", comment: "Section header on reminder details and the reminder form: the nudges a reminder sends, when, and how they arrive.")
    }
}

/// One row: "Nudges 4–20 at +52 min, 30 sec / every 5 min", and "Urgent" over the Via label. At
/// accessibility sizes the urgency and Via label go under the times. One VoiceOver element.
private struct HowItNudgesRowView: View {
    let row: HowItNudges.Row

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Design.Spacing.s3) {
            Circle()
                .fill(row.urgency.color)
                .frame(width: Design.Spacing.s2, height: Design.Spacing.s2)
                .accessibilityHidden(true)
            SizeAdaptiveStack(rowAlignment: .firstTextBaseline, stackedSpacing: Design.Spacing.s1) {
                VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                    row.whichText
                    row.gapText
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: Design.Spacing.s1) {
                    Text(verbatim: row.urgency.name)
                        .fontWeight(.semibold)
                        .foregroundStyle(row.urgency.color)
                    ViaLabel(delivery: row.delivery).text
                        .accessibilityLabel(ViaLabel(delivery: row.delivery).spokenText)
                }
            }
        }
        .font(.footnote)
        .frame(minHeight: Design.Spacing.rowMin)
        .accessibilityElement(children: .combine)
    }
}

extension HowItNudges.Row {
    /// "Nudge 1 when due", "Nudges 1–2 when due", "Nudge 3 at +45 min" or "Nudges 4–20 at
    /// +52 min, 30 sec". A Consistent pace's equal waits fold the first nudges into a run.
    fileprivate var whichText: Text {
        let start = HowItNudgesDuration.text(startsAfter)
        if nudges.lowerBound == 1, nudges.count > 1 {
            return Text("**Nudges \(nudges.lowerBound)–\(nudges.upperBound)** when due", comment: "How It Nudges row: a run of nudges from the first, which comes at the due time, each one wait after the last. 1: the first nudge's number, 1. 2: the last's.")
        }
        if nudges.lowerBound == 1 {
            return Text("**Nudge \(nudges.lowerBound)** when due", comment: "How It Nudges row: the first nudge, which comes at the due time. The placeholder is its number, 1.")
        }
        if nudges.count == 1 {
            return Text("**Nudge \(nudges.lowerBound)** at +\(start)", comment: "How It Nudges row: one nudge and how long after the due time it comes. 1: the nudge's number. 2: a duration, such as \"45 min\".")
        }
        return Text("**Nudges \(nudges.lowerBound)–\(nudges.upperBound)** at +\(start)", comment: "How It Nudges row: a run of nudges and how long after the due time the first comes. 1: the first nudge's number. 2: the last's. 3: a duration, such as \"52 min, 30 sec\".")
    }

    /// "then waits 30 min" for one nudge, "every 5 min" for a run.
    fileprivate var gapText: Text {
        let wait = HowItNudgesDuration.text(self.wait)
        if nudges.count == 1 {
            return Text("then waits \(wait)", comment: "How It Nudges row: the wait after one nudge before the next. The placeholder is a duration, such as \"30 min\".")
        }
        return Text("every \(wait)", comment: "How It Nudges row: the wait between each of a run of nudges. The placeholder is a duration, such as \"5 min\".")
    }
}

/// The ladder's times in the locale's words, at most two units: "7 min, 30 sec", "2 hr, 18 min".
enum HowItNudgesDuration {
    static func text(_ interval: TimeInterval) -> String {
        Duration.seconds(interval).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }
}

extension HowItNudgesSentence {
    var text: Text {
        let app = Bundle.appDisplayName
        switch self {
        case .givesUp(let nudges, let after):
            return Text("\(nudges) nudges over \(HowItNudgesDuration.text(after)), then it gives up.", comment: "How It Nudges footer. 1: how many nudges a reminder sends before it gives up. 2: how long that takes from the due time, such as \"2 hr, 18 min\".")
        case .noneCanArrive:
            return Text("Notifications are off, so none of them can reach you.", comment: "How It Nudges footer, when notifications are off and none of the nudges rings as an alarm.")
        case .cannotArriveUntilAlarms(let alarms):
            return Text("Notifications are off, so only nudges \(alarms.lowerBound)–\(alarms.upperBound) can reach you, as alarms.", comment: "How It Nudges footer, when notifications are off. 1: the first nudge that rings as an alarm. 2: the last nudge.")
        // English says "Both" for two, which no plural category of the catalog's has, so two
        // is its own string. A long Consistent wait can send only two.
        case .allRing(2):
            return Text("Both nudges ring as alarms.", comment: "How It Nudges footer, when a reminder sends two nudges, as a long Consistent wait can, and both ring as alarms.")
        case .allRing(let nudges):
            return Text("All \(nudges) nudges ring as alarms.", comment: "How It Nudges footer. The placeholder is how many nudges the reminder sends.")
        case .allNotifications(2):
            return Text("Both nudges are notifications.", comment: "How It Nudges footer, when a reminder sends two nudges, as a long Consistent wait can, and neither rings as an alarm.")
        case .allNotifications(let nudges):
            return Text("All \(nudges) nudges are notifications.", comment: "How It Nudges footer, when no nudge rings as an alarm. The placeholder is how many nudges the reminder sends.")
        case .notificationsThenAlarms(let alarms):
            return Text("Nudges 1–\(alarms.lowerBound - 1) are notifications. Nudges \(alarms.lowerBound)–\(alarms.upperBound) ring as alarms.", comment: "How It Nudges footer. 1: the last nudge that is a notification. 2: the first nudge that rings as an alarm. 3: the last nudge.")
        case .urgentIsTimeSensitive:
            return Text("Alarms are off, so Urgent nudges come as Time Sensitive notifications.", comment: "How It Nudges footer, when alarms are off and Time Sensitive is on.")
        case .urgentIsOrdinary:
            return Text("Alarms and Time Sensitive are off, so Urgent nudges come as ordinary notifications.", comment: "How It Nudges footer, when alarms and Time Sensitive are both off.")
        case .focusHoldsNormal:
            return Text("During a Focus, Normal nudges wait until High, unless you allow \(app) in that Focus.", comment: "How It Nudges footer. The placeholder is the app's name.")
        case .focusHoldsAllNormal:
            return Text("During a Focus, every nudge waits, unless you allow \(app) in that Focus.", comment: "How It Nudges footer, when no nudge reaches High, as with a long Consistent wait. The placeholder is the app's name.")
        case .focusHoldsEveryNudge:
            return Text("Break Through Focus is off, so during a Focus every nudge waits, unless you allow \(app) in that Focus.", comment: "How It Nudges footer, for a reminder whose Break Through Focus switch is off. The placeholder is the app's name.")
        case .focusHoldsEveryNotification:
            return Text("Time Sensitive is off, so during a Focus every notification waits, unless you allow \(app) in that Focus.", comment: "How It Nudges footer, when the app's Time Sensitive notifications are off. The placeholder is the app's name.")
        }
    }
}

#Preview("Firm, every permission") {
    List {
        HowItNudgesSection(howItNudges: .preview(.firm))
    }
}

#Preview("Relentless, alarms off, largest text") {
    List {
        HowItNudgesSection(howItNudges: .preview(.relentless, PermissionStates(alarms: .denied)))
    }
    .dynamicTypeSize(.accessibility5)
}

extension HowItNudges {
    /// A strength's ladder from an engine with the given permissions, for previews.
    static func preview(_ strength: Strength, _ permissions: PermissionStates = PermissionStates(alarms: .allowed), breakThroughFocus: Bool = true) -> HowItNudges {
        Engine(clock: SystemClock(), scheduler: NoOpScheduler(), permissions: permissions)
            .howItNudges(strength, breakThroughFocus: breakThroughFocus)
    }
}
