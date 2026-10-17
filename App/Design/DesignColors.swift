import SwiftUI

/// DESIGN.md's custom colors, from the asset catalog's color sets (scripts/generate-color-sets.sh),
/// each with its light, dark and Increased Contrast values. Accent is `Color.accentColor`, the
/// `AccentColor` set. System semantic colors (grouped background, labels, separators) are used by
/// their system names, not from here. One color, one meaning: see DESIGN.md › Colors.
extension Color {
    /// Text and glyphs on an accent fill.
    static let onAccent = Color("OnAccent")
    /// Danger, or needs you now: Nudging, Urgent, Missed, errors, Off, destructive actions.
    static let negative = Color("Negative")
    /// Escalating: High urgency, the alarms-off and Time Sensitive-off banners.
    static let warning = Color("Warning")
    /// Done or on. No button uses it.
    static let positive = Color("Positive")
    /// Normal urgency, tags, strength badges.
    static let neutral = Color("Neutral")
    /// The Now tab's nudging count.
    static let badge = Color("Badge")
    /// Settings row icon tiles and the swipe action: icons, not statuses.
    static let tileRed = Color("TileRed")
    static let tileOrange = Color("TileOrange")
    static let tileGray = Color("TileGray")
    static let tileBlue = Color("TileBlue")
    static let tileGreen = Color("TileGreen")
}
