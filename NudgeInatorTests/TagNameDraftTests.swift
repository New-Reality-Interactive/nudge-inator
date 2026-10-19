import Foundation
import NudgeEngine
import Testing
@testable import NudgeInator

/// What the New Tag and Rename Tag sheet says about the name typed so far. The words and the
/// disabled Done are screenshot and device checks.
struct TagNameDraftTests {
    let engine = Engine.myDayPreview()
    var home: Tag { engine.tags.first { $0.name == "home" }! }
    var work: Tag { engine.tags.first { $0.name == "work" }! }

    @Test func aNameAnotherTagHasIsTakenIgnoringCase() {
        let draft = TagNameDraft(text: "Home", renaming: nil, in: engine)

        #expect(draft.problem == .taken(home))
        #expect(draft.shownProblem == .taken(home))
    }

    @Test func renamingToAnotherTagsNameIsTakenButToItsOwnInOtherCasingIsFine() {
        #expect(TagNameDraft(text: "#HOME", renaming: work.id, in: engine).problem == .taken(home))
        #expect(TagNameDraft(text: "Work", renaming: work.id, in: engine).problem == nil)
    }

    @Test func nothingTypedBlocksDoneWithoutScoldingAndOnlyAHashIsScolded() {
        let blank = TagNameDraft(text: "  ", renaming: nil, in: engine)
        let hash = TagNameDraft(text: " # ", renaming: nil, in: engine)

        #expect(blank.problem == .empty)
        #expect(blank.shownProblem == nil)
        #expect(hash.shownProblem == .empty)
    }

    @Test func anEngineRefusalShowsAsTheSameProblemTheDraftWould() {
        #expect(TagNameDraft.Problem(.empty) == .empty)
        #expect(TagNameDraft.Problem(.taken(by: home)) == .taken(home))
    }
}
