import SwiftUI

/// Settings' Default Pace page (spec story 38): the form's Pace and Every controls, for every new
/// reminder. A change applies as soon as it is made.
struct DefaultPacePage: View {
    @Binding var defaultPace: DefaultPace

    var body: some View {
        List {
            PaceControlsSection(choice: $defaultPace.choice, wait: $defaultPace.consistentWait) {
                Text("New reminders start with this pace. Changing it doesn't change the reminders you already have.",
                     comment: "Default Pace page: under the Pace and Every controls.")
            }
        }
        .centeredInReadableColumn()
        .navigationTitle(Text("Default Pace", comment: "Title of the page in Settings that sets the pace every new reminder starts with."))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Consistent") {
    @Previewable @State var defaultPace = DefaultPace.shipped
    NavigationStack {
        DefaultPacePage(defaultPace: $defaultPace)
    }
}

#Preview("Escalating, largest text") {
    @Previewable @State var defaultPace = DefaultPace(choice: .escalating, consistentWait: 10 * 60)
    NavigationStack {
        DefaultPacePage(defaultPace: $defaultPace)
    }
    .dynamicTypeSize(.accessibility5)
}
