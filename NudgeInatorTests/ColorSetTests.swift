import Foundation
import SwiftUI
import Testing
import UIKit
@testable import NudgeInator

/// Every custom color in DESIGN.md's frontmatter is a color set in the app's asset catalog, with
/// its light, dark, Increased Contrast and dark Increased Contrast values.
struct ColorSetTests {
    struct Expected: CustomTestStringConvertible, Sendable {
        let name: String
        /// Light, dark, Increased Contrast light, Increased Contrast dark: DESIGN.md's `x`, `x-dark`,
        /// `x-ic` and `x-dark-ic`. Where it gives one value for several, the value is repeated.
        let hex: [String]
        var testDescription: String { name }
    }

    static let expected = [
        Expected(name: "AccentColor", hex: ["04666B", "07DDE6", "04474A", "A5FAFE"]),
        Expected(name: "OnAccent", hex: ["FFFFFF", "000000", "FFFFFF", "000000"]),
        Expected(name: "Negative", hex: ["D70015", "FF6961", "9E0010", "FFA39C"]),
        Expected(name: "Warning", hex: ["C93400", "FF9F0A", "8F2800", "FFB340"]),
        Expected(name: "Positive", hex: ["1E7B34", "30D158", "145A22", "5DE07B"]),
        Expected(name: "Neutral", hex: ["6C6C70", "AEAEB2", "3C3C43", "D1D1D6"]),
        // "The same value in light and dark."
        Expected(name: "Badge", hex: ["E9152D", "E9152D", "B00012", "B00012"]),
        // Tiles: "the same value in every mode".
        Expected(name: "TileRed", hex: ["E9152D", "E9152D", "E9152D", "E9152D"]),
        Expected(name: "TileOrange", hex: ["C55300", "C55300", "C55300", "C55300"]),
        Expected(name: "TileGray", hex: ["6C6C70", "6C6C70", "6C6C70", "6C6C70"]),
        Expected(name: "TileBlue", hex: ["1E6EF4", "1E6EF4", "1E6EF4", "1E6EF4"]),
        Expected(name: "TileGreen", hex: ["008932", "008932", "008932", "008932"]),
    ]

    static let appearances: [(UIUserInterfaceStyle, UIAccessibilityContrast)] = [
        (.light, .normal), (.dark, .normal), (.light, .high), (.dark, .high),
    ]

    /// Main actor: `UIMutableTraits`' setters are isolated to it, and the mutations closure runs
    /// in this function's isolation.
    @Test(arguments: expected) @MainActor
    func theColorSetHasDesignsValueInEveryAppearance(_ color: Expected) throws {
        let set = try #require(UIColor(named: color.name, in: Bundle(for: AppDelegate.self), compatibleWith: nil))

        let resolved = Self.appearances.map { style, contrast in
            Self.hex(set.resolvedColor(with: UITraitCollection {
                $0.userInterfaceStyle = style
                $0.accessibilityContrast = contrast
            }))
        }

        #expect(resolved == color.hex)
    }

    /// The views use the sets through these statics, so each must name its set. SwiftUI can set
    /// only the color scheme here (`colorSchemeContrast` is read-only), so the contrast variants
    /// are left to the test above. Accent isn't here: `Color.accentColor` reaches views as the tint
    /// Xcode sets from `NSAccentColorName` (below), so a bare environment resolves it to system blue.
    @Test(arguments: [
        (Color.onAccent, "OnAccent"), (.negative, "Negative"),
        (.warning, "Warning"), (.positive, "Positive"), (.neutral, "Neutral"), (.badge, "Badge"),
        (.tileRed, "TileRed"), (.tileOrange, "TileOrange"), (.tileGray, "TileGray"),
        (.tileBlue, "TileBlue"), (.tileGreen, "TileGreen"),
    ])
    func theColorStaticIsItsSet(_ color: Color, named name: String) throws {
        let expected = try #require(Self.expected.first { $0.name == name })

        let resolved = [ColorScheme.light, .dark].map { (scheme: ColorScheme) -> String in
            var environment = EnvironmentValues()
            environment.colorScheme = scheme
            let color = color.resolve(in: environment)
            return Self.hex(UIColor(red: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue), alpha: 1))
        }

        #expect(resolved == Array(expected.hex.prefix(2)))
    }

    /// Xcode applies the accent set as the app's tint through this key.
    @Test func theAccentSetIsTheAppsAccentColor() {
        #expect(Bundle(for: AppDelegate.self).object(forInfoDictionaryKey: "NSAccentColorName") as? String == "AccentColor")
    }

    static func hex(_ color: UIColor) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue].map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }
}
