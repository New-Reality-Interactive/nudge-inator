import NudgeEngine
import SwiftUI

/// Settings › Share Activity (#397): what happened to the person's sharing that they would
/// otherwise never see (GLOSSARY.md, Share Activity), newest first, or with nothing recorded an
/// empty state saying nothing has gone wrong. The mockup's `viewActivity`. Nothing here is tapped.
struct ShareActivityPage: View {
    let sharing: SharingModel

    @Environment(AppModel.self) private var model: AppModel?
    @Environment(\.locale) private var locale

    var body: some View {
        let list = ShareActivityList(sharing.data, locale: locale)
        Group {
            if list.isEmpty {
                ScrollView {
                    ContentUnavailableView {
                        Label {
                            Text("No Share Activity", comment: "Share Activity: title of the empty state, with nothing recorded.")
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    } description: {
                        Text("Nothing has gone wrong with sharing. If iCloud refuses a change or a connection ends, it shows here.", comment: "Share Activity: under \"No Share Activity\".")
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
            } else {
                List {
                    Section {
                        ForEach(list.rows) { row in
                            ShareActivityRow(row: row, when: when(row.at))
                        }
                    } footer: {
                        Text("Kept on this iPhone only. Turning off Sharing clears it.", comment: "Share Activity: under the list of entries.")
                    }
                }
            }
        }
        .navigationTitle(Text("Share Activity", comment: "Share Activity: the page's title, and the Settings row that opens it."))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// "Today at 7:58 AM", "Yesterday at 4:12 PM" or a short date and the time, from the engine as
    /// an invited person's page has it.
    private func when(_ date: Date) -> Text {
        let day = model?.engine.dayLabel(of: date) ?? date.formatted(date: .abbreviated, time: .omitted)
        let time = model?.engine.timeOfDay(of: date) ?? date.formatted(date: .omitted, time: .shortened)
        return Text("\(day) at \(time)", comment: "Share Activity: when an entry happened. 1: \"Today\", \"Yesterday\" or a short date. 2: the time, such as \"7:58 AM\".")
    }
}

/// One entry: who it concerns, what happened and when, as three lines read as one by VoiceOver.
private struct ShareActivityRow: View {
    let row: ShareActivityList.Row
    let when: Text

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.line) {
            if let who = row.who {
                Text(verbatim: who)
                    .font(.body)
            }
            Group {
                Text(row.event.text)
                when
            }
            .font(.subheadline)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Entries") {
    NavigationStack { ShareActivityPage(sharing: StandInSharing.previewModel()) }
}

#Preview("Nothing recorded") {
    NavigationStack { ShareActivityPage(sharing: StandInSharing.previewModel(seeded: false)) }
}

#Preview("Entries, largest text") {
    NavigationStack { ShareActivityPage(sharing: StandInSharing.previewModel()) }
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Landscape", traits: .landscapeLeft) {
    NavigationStack { ShareActivityPage(sharing: StandInSharing.previewModel()) }
}
#endif
