import Foundation
import NudgeEngine

/// What the Filter Sent sheet shows (ticket 329), read from the sharing store and the engine at one
/// moment: the people to check, how many reminders Apply would show, and whether the draft differs
/// from what's applied. A value, so the tests read it with no view.
struct SentFilterSheet: FilterSheetSummary {
    /// Everyone connected, in the groups' order, as the mockup's `sentFilterSheet` lists them.
    let people: [Person]
    /// How many reminders Apply would show, with the search as it is, each once however many people
    /// it went to.
    let result: LocalizedStringResource
    let hasChanges: Bool
    let canReset: Bool

    struct Person: Identifiable {
        let id: UUID
        /// The person's whole name, as Connections lists them.
        let name: String
        let isChosen: Bool
    }

    init(engine: Engine, sharing: SharingData, draft: SentFilterChoices, applied: SentFilterChoices, search: String) {
        let draft = draft.keepingConnectedPeople(in: sharing)
        people = sharing.sentConnections.map {
            Person(id: $0.id, name: $0.name, isChosen: draft.isChosen(person: $0.id))
        }
        hasChanges = draft != applied.keepingConnectedPeople(in: sharing)
        canReset = !draft.isEmpty
        let shown = SentScreen(engine: engine, sharing: sharing, tools: SentTools(search: search, filter: draft)).shownCount
        result = LocalizedStringResource("Apply shows \(shown) reminders.", comment: "Sent's filter sheet: above Reset. The placeholder is how many reminders Sent would show with these filters and the search as it is, one sent to two people counting once. VoiceOver also speaks it when a choice changes it.")
    }
}
