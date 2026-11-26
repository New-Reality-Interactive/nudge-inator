import Foundation
import NudgeEngine

/// A page of one of Settings' tutorial sheets (#423, #467): every tutorial is a sheet of pages that
/// works as How Sharing Works does. A tutorial whose pages never change lists them as its cases, in
/// the order the sheet shows them; How It Nudges' pages carry the schedules at the Default Pace, so
/// they are built when the sheet opens (#470).
protocol TutorialPage: Equatable, Sendable {
    /// The sheet's title, and its row's in Settings' Tutorials section.
    static var title: LocalizedStringResource { get }
    var heading: LocalizedStringResource { get }
    /// Above the heading, decoration only.
    var art: [TutorialArtPiece] { get }
    var content: TutorialContent { get }
}

/// A piece of a page's picture: a pill, an SF Symbol and a word, an arrow between two, or a pill
/// of a strength's bars.
enum TutorialArtPiece: Sendable {
    case pill(symbol: String, text: LocalizedStringResource)
    case arrow
    case strength(Strength)
}

/// Under the heading: a lead and rows, each with its SF Symbol, or numbered steps under an optional
/// lead (#468); either can end with a footer. Or a strength's schedule, as How It Nudges draws it, under a lead and a note.
enum TutorialContent: Sendable {
    case points(lead: LocalizedStringResource?, [TutorialPoint], footnote: LocalizedStringResource? = nil)
    case steps(lead: LocalizedStringResource? = nil, [TutorialStep], footnote: LocalizedStringResource)
    case schedule(lead: LocalizedStringResource, note: LocalizedStringResource, HowItNudges)
}

struct TutorialPoint: Sendable {
    let symbol: String
    let title: LocalizedStringResource
    let text: LocalizedStringResource
    /// A second line under `text`, as How It Nudges' alarms point has (#459).
    var note: LocalizedStringResource? = nil
}

struct TutorialStep: Sendable {
    let title: LocalizedStringResource
    let text: LocalizedStringResource
}

/// Where a tutorial sheet is: Next moves forward, Back moves back, and a swipe lands on a page
/// directly (#430). On the last page Next is the confirm checkmark, which closes the sheet.
struct TutorialPaging<Page: TutorialPage> {
    /// The sheet's pages, as it opened with them.
    let pages: [Page]
    private var index = 0

    init(pages: [Page]) {
        self.pages = pages
    }

    /// The page on screen, by its place; the paged view sets it when a swipe settles.
    var pageIndex: Int {
        get { index }
        set { if pages.indices.contains(newValue) { index = newValue } }
    }

    var page: Page {
        get { pages[index] }
        set { index = pages.firstIndex(of: newValue) ?? index }
    }

    var canGoBack: Bool { index > 0 }
    var isLastPage: Bool { index == pages.count - 1 }

    /// What the page dots say to VoiceOver.
    var position: LocalizedStringResource {
        LocalizedStringResource("Page \(index + 1) of \(pages.count)", comment: "A tutorial sheet, such as How Sharing Works: VoiceOver's reading of the page dots. 1: this page's number. 2: how many pages there are.")
    }

    mutating func goForward() {
        if !isLastPage { index += 1 }
    }

    mutating func goBack() {
        if canGoBack { index -= 1 }
    }
}

extension TutorialPaging where Page: CaseIterable, Page.AllCases == [Page] {
    /// Over every case, for a tutorial whose pages never change.
    init() {
        self.init(pages: Page.allCases)
    }
}
