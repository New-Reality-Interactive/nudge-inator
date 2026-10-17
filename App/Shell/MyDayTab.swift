import SwiftUI

/// My Day, empty: today's date and the mockup's empty line. Ticket 28 adds the counts, the tag
/// filter and the rows.
struct MyDayTab: View {
    let state: ScreenState

    var body: some View {
        NavigationStack {
            TabScreen(state: state) {
                List {
                    Section {
                        EmptyRow(text: Text("Nothing is due today.", comment: "My Day: the list when nothing is due today."))
                    } header: {
                        Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                            .subheadStyle()
                            .textCase(nil)
                    }
                }
            }
            .navigationTitle(Text(AppTab.myDay.title))
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
