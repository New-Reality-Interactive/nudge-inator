import Foundation
@testable import NudgeInator

extension TutorialArtPiece {
    /// A piece of a tutorial page's picture as the tests compare it: a pill's symbol and word, an
    /// arrow as "→", and a pill of a strength's bars as "bars" and the strength.
    var described: String {
        switch self {
        case .pill(let symbol, let text): "\(symbol) \(String(localized: text))"
        case .arrow: "→"
        case .strength(let strength): "bars \(String(localized: strength.title))"
        }
    }
}
