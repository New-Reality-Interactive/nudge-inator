import Foundation
@testable import NudgeInator

extension TutorialArtPiece {
    /// A piece of a tutorial page's picture as the tests compare it: a pill's symbol and word, an
    /// arrow as "→", and a strength badge as its name.
    var described: String {
        switch self {
        case .pill(let symbol, let text): "\(symbol) \(String(localized: text))"
        case .arrow: "→"
        case .strength(let strength): "badge \(String(localized: strength.title))"
        }
    }
}
