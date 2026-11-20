import Foundation

/// A page of one of Settings' tutorial sheets (#423, #467): every tutorial is a sheet of pages that
/// works as How Sharing Works does. The cases are the pages, in the order the sheet shows them.
protocol TutorialPage: CaseIterable, Hashable, Sendable where AllCases == [Self] {
    /// The sheet's title, and its row's in Settings' Tutorials section.
    static var title: LocalizedStringResource { get }
    var heading: LocalizedStringResource { get }
    /// Above the heading, decoration only.
    var art: [TutorialArtPiece] { get }
    var content: TutorialContent { get }
    /// Whether the art's text stops growing at the largest standard size. Art that would otherwise
    /// wrap inside its pills does, since VoiceOver skips it.
    var artStopsGrowingAtLargestStandardSize: Bool { get }
}

extension TutorialPage {
    var artStopsGrowingAtLargestStandardSize: Bool { false }
}

/// A piece of a page's picture: a pill, an SF Symbol and a word, or an arrow between two.
enum TutorialArtPiece: Sendable {
    case pill(symbol: String, text: LocalizedStringResource)
    case arrow
}

/// Under the heading: a lead and rows, each with its SF Symbol, or numbered steps; either can end
/// with a footer.
enum TutorialContent: Sendable {
    case points(lead: LocalizedStringResource?, [TutorialPoint], footnote: LocalizedStringResource? = nil)
    case steps([TutorialStep], footnote: LocalizedStringResource)
}

struct TutorialPoint: Sendable {
    let symbol: String
    let title: LocalizedStringResource
    let text: LocalizedStringResource
}

struct TutorialStep: Sendable {
    let title: LocalizedStringResource
    let text: LocalizedStringResource
}

/// Where a tutorial sheet is: Next moves forward, Back moves back, and a swipe lands on a page
/// directly (#430). On the last page Next is the confirm checkmark, which closes the sheet.
struct TutorialPaging<Page: TutorialPage> {
    private static var pages: [Page] { Page.allCases }
    private var index = 0

    /// The page on screen; the paged view sets it when a swipe settles.
    var page: Page {
        get { Self.pages[index] }
        set { index = Self.pages.firstIndex(of: newValue) ?? index }
    }

    var canGoBack: Bool { index > 0 }
    var isLastPage: Bool { index == Self.pages.count - 1 }

    /// What the page dots say to VoiceOver.
    var position: LocalizedStringResource {
        LocalizedStringResource("Page \(index + 1) of \(Self.pages.count)", comment: "A tutorial sheet, such as How Sharing Works: VoiceOver's reading of the page dots. 1: this page's number. 2: how many pages there are.")
    }

    mutating func goForward() {
        if !isLastPage { index += 1 }
    }

    mutating func goBack() {
        if canGoBack { index -= 1 }
    }
}
