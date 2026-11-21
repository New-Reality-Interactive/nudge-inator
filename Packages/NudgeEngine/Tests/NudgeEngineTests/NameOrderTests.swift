import Foundation
import Testing
@testable import NudgeEngine

/// The order names are listed in: the person's locale's, with numbers in natural order. Every test
/// names its locale, so none depends on the Mac's or the simulator's language.
struct NameOrderTests {
    let swedish = NameOrder(locale: Locale(identifier: "sv_SE"))
    let spanish = NameOrder(locale: Locale(identifier: "es_ES"))
    let english = NameOrder(locale: Locale(identifier: "en_US"))

    func sorted(_ names: [String], _ order: NameOrder) -> [String] {
        names.sorted { order.compare($0, $1) == .orderedAscending }
    }

    @Test func aLetterTheLocaleSortsAfterZSitsThereInThatLocale() {
        #expect(sorted(["Östen", "Zed", "Anna"], swedish) == ["Anna", "Zed", "Östen"])
        #expect(sorted(["Östen", "Zed", "Anna"], english) == ["Anna", "Östen", "Zed"])
    }

    @Test func nTildeIsItsOwnLetterInSpanishAndAnAccentedNElsewhere() {
        #expect(sorted(["Ñu", "Nz", "Oso"], spanish) == ["Nz", "Ñu", "Oso"])
        #expect(sorted(["Ñu", "Nz", "Oso"], english) == ["Ñu", "Nz", "Oso"])
    }

    @Test func nonLatinNamesFollowTheLatinOnes() {
        #expect(sorted(["Ωmega", "Beta", "Дима", "Alpha"], english) == ["Alpha", "Beta", "Ωmega", "Дима"])
    }

    @Test func numbersReadInNaturalOrder() {
        #expect(sorted(["Tag 10", "Tag 2", "Tag 1"], english) == ["Tag 1", "Tag 2", "Tag 10"])
    }

    @Test func casePlaysNoPartInTheOrder() {
        #expect(sorted(["beta", "Alpha", "Beta", "alpha"], english).map { $0.lowercased() } == ["alpha", "alpha", "beta", "beta"])
        #expect(english.compare("Ana", "ana") == .orderedSame)
    }
}
