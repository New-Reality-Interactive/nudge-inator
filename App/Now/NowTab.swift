import NudgeEngine
import SwiftUI

/// Now: the nudge cards with Done, Coming Up (the next 7 days) and the Last 24 Hours, from the
/// engine's read-outs. They change as time passes with no change to the engine (a nudge fires,
/// an occurrence falls due or gives up), so the list is read again at the start of every minute.
struct NowTab: View {
    let state: ScreenState
    /// The reminders whose details are pushed, which the shell sets for the alarm's Open and a
    /// tap appends to.
    @Binding var path: [OpenedReminder]
    /// What previews show, since they have no app model.
    var preview: NowScreen?

    @Environment(AppModel.self) private var model: AppModel?

    var body: some View {
        NavigationStack(path: $path) {
            TabScreen(state: state) {
                TimelineView(.everyMinute) { context in
                    NowList(screen: screen, reach: model?.engine.reach, now: context.date) { reminderID in
                        model?.markDone(reminderID)
                    } openDetails: { reminderID in
                        path.append(OpenedReminder(id: reminderID))
                    }
                }
            }
            .navigationTitle(Text(AppTab.now.title))
            .reminderDetailsDestination()
            .toolbar {
                ToolbarItem(placement: .primaryAction) { NewReminderButton() }
            }
        }
    }

    private var screen: NowScreen {
        model.map { NowScreen(engine: $0.engine) } ?? preview ?? NowScreen()
    }
}

/// The three sections, in the mockup's `viewNow` order.
private struct NowList: View {
    let screen: NowScreen
    /// What can still reach the person, for the permission banners under the subhead.
    let reach: Reach?
    let now: Date
    let markDone: (Reminder.ID) -> Void
    let openDetails: (Reminder.ID) -> Void

    /// A card Done was chosen on with VoiceOver, kept until VoiceOver moves on.
    @State private var held: HeldCard?

    var body: some View {
        let cards = screen.nudging(holding: held)
        List {
            Section {
                if cards.isEmpty {
                    EmptyRow(text: Text("**All clear.** Nothing needs you right now.", comment: "Now: the Nudging section when nothing is nudging."))
                } else {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        NudgeCardRow(card: card, now: now, markDone: { markDone(card.id) }, openDetails: { openDetails(card.id) }, isDoneHeld: heldBinding(for: card, at: index))
                    }
                }
            } header: {
                NowHeader(subhead: screen.subhead(on: now), reach: reach)
            }
            Section {
                if screen.comingUp.isEmpty {
                    EmptyRow(text: Text("Nothing scheduled this week.", comment: "Now: the Coming Up section when nothing is due in the next 7 days."))
                } else {
                    ForEach(screen.comingUp) { row in ComingUpRowView(row: row) { openDetails(row.reminder.id) } }
                }
            } header: {
                ComingUpHeader()
            }
            Section {
                if screen.lastDay.isEmpty {
                    EmptyRow(text: Text("Nothing closed yet today.", comment: "Now: the Last 24 Hours section when no occurrence closed in that time."))
                } else {
                    ForEach(screen.lastDay) { row in ClosedRowView(row: row) { openDetails(row.reminder.id) } }
                }
            } header: {
                Text("Last 24 Hours", comment: "Now: section header for occurrences closed in the last 24 hours.")
            }
        }
    }

    private func heldBinding(for card: NudgeCard, at index: Int) -> Binding<Bool> {
        Binding {
            held?.card.id == card.id
        } set: { isHeld in
            if isHeld {
                held = HeldCard(card: card, index: index)
            } else if held?.card.id == card.id {
                held = nil
            }
        }
    }
}

/// A nudge card as a list row: drawn on its own background, with the mockup's 12 pt between
/// cards, and the trailing Done swipe action.
private struct NudgeCardRow: View {
    let card: NudgeCard
    let now: Date
    let markDone: () -> Void
    let openDetails: () -> Void
    let isDoneHeld: Binding<Bool>

    var body: some View {
        NudgeCardView(card: card, now: now, markDone: markDone, openDetails: openDetails, isDoneHeld: isDoneHeld)
            .listRowInsets(EdgeInsets(top: Design.Spacing.s3 / 2, leading: 0, bottom: Design.Spacing.s3 / 2, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            // No full swipe, so a stray swipe can't mark it Done. Hidden from VoiceOver, which
            // has the card's own Done button (the mockup's `swipeable`).
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(action: markDone) {
                    Label {
                        Text("Done", comment: "Nudge card's swipe action: marks the reminder Done and stops its nudges.")
                    } icon: {
                        Image(systemName: "checkmark")
                    }
                }
                .tint(Color.tileGreen)
                .accessibilityHidden(true)
            }
    }
}

/// Today's date and what's nudging, then the Nudging heading, as the mockup's subhead and title-3
/// section header.
private struct NowHeader: View {
    let subhead: LocalizedStringResource
    let reach: Reach?

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s3) {
            Text(Self.styled(subhead))
                .subheadStyle()
            // Between the subhead and Nudging, as the mockup's `viewNow` puts it.
            if let reach {
                PermissionBanners(reach: reach)
            }
            Text("Nudging", comment: "Now: section header for the reminders nudging you now.")
                .font(.title3.bold())
                // The label color, as the mockup's big section header: a list header's own
                // style would turn `.primary` gray.
                .foregroundStyle(Color(uiColor: .label))
        }
        .textCase(nil)
    }

    /// The subhead's bold count in red, "needs you now", as the mockup's `<strong>`.
    private static func styled(_ subhead: LocalizedStringResource) -> AttributedString {
        var text = AttributedString(localized: subhead)
        for run in text.runs where run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
            text[run.range].foregroundColor = .negative
        }
        return text
    }
}

/// "Coming Up" with "Next 7 days" at the trailing edge, stacked at accessibility sizes.
private struct ComingUpHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())
        layout {
            Text("Coming Up", comment: "Now: section header for reminders due soon.")
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            Text("Next 7 days", comment: "Now: how far ahead the Coming Up section looks.")
        }
    }
}

#Preview("Light") {
    NowTab(state: .ready, path: .constant([]), preview: .preview())
}

#Preview("Dark") {
    NowTab(state: .ready, path: .constant([]), preview: .preview())
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    NowTab(state: .ready, path: .constant([]), preview: .preview())
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Landscape", traits: .landscapeLeft) {
    NowTab(state: .ready, path: .constant([]), preview: .preview())
}

#Preview("Empty") {
    NowTab(state: .ready, path: .constant([]))
}
