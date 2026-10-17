import SwiftUI

/// My Day, empty: today's date and the mockup's empty line. Ticket 28 adds the counts, the tag
/// filter and the rows.
struct MyDayTab: View {
    let state: ScreenState
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        // In compact height (landscape) the date moves into the bar as the title's subtitle, as in
        // the mockup, leaving the room to the list.
        let dateInBar = verticalSizeClass == .compact
        let date = Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
        NavigationStack {
            TabScreen(state: state) {
                List {
                    Section {
                        EmptyRow(text: Text("Nothing is due today.", comment: "My Day: the list when nothing is due today."))
                    } header: {
                        if !dateInBar {
                            date
                                .subheadStyle()
                                .textCase(nil)
                        }
                    }
                }
            }
            .navigationTitle(Text(AppTab.myDay.title))
            .navigationSubtitle(dateInBar ? date : Text(verbatim: ""))
            .toolbar {
                ToolbarItem(placement: .primaryAction) { NewReminderButton() }
            }
        }
    }
}

#Preview("Light") {
    MyDayTab(state: .ready)
}

#Preview("Dark") {
    MyDayTab(state: .ready)
        .preferredColorScheme(.dark)
}

#Preview("Largest text") {
    MyDayTab(state: .ready)
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Landscape") {
    MyDayTab(state: .ready)
        .previewInterfaceOrientation(.landscapeLeft)
}
