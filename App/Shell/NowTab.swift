import SwiftUI

/// Now, empty: the mockup's three sections with their empty lines. Ticket 26 fills them from the
/// engine's read-outs.
struct NowTab: View {
    let state: ScreenState

    var body: some View {
        NavigationStack {
            TabScreen(state: state) {
                List {
                    Section {
                        EmptyRow(text: Text("**All clear.** Nothing needs you right now.", comment: "Now: the Nudging section when nothing is nudging."))
                    } header: {
                        NowHeader()
                    }
                    Section {
                        EmptyRow(text: Text("Nothing scheduled this week.", comment: "Now: the Coming Up section when nothing is due in the next 7 days."))
                    } header: {
                        ComingUpHeader()
                    }
                    Section {
                        EmptyRow(text: Text("Nothing closed yet today.", comment: "Now: the Last 24 Hours section when no occurrence closed in that time."))
                    } header: {
                        Text("Last 24 Hours", comment: "Now: section header for occurrences closed in the last 24 hours.")
                    }
                }
            }
            .navigationTitle(Text(AppTab.now.title))
            .toolbar {
                ToolbarItem(placement: .primaryAction) { NewReminderButton() }
            }
        }
    }
}

/// Today's date and what's nudging, then the Nudging heading, as the mockup's subhead and title-3
/// section header.
private struct NowHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s3) {
            Text("\(Date.now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated)) · Nothing is nudging you",
                 comment: "Now: under the title. The placeholder is today's short date, such as \"Sat 17 Oct\".")
                .subheadStyle()
            Text("Nudging", comment: "Now: section header for the reminders nudging you now.")
                .font(.title3.bold())
                // The label color, as the mockup's big section header: a list header's own
                // style would turn `.primary` gray.
                .foregroundStyle(Color(uiColor: .label))
        }
        .textCase(nil)
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
    NowTab(state: .ready)
}

#Preview("Dark") {
    NowTab(state: .ready)
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    NowTab(state: .ready)
        .environment(\.dynamicTypeSize, .accessibility5)
}
