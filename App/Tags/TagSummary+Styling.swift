import NudgeEngine
import SwiftUI

extension TagSummary {
    /// `counts` with the nudging part in the negative color, as a row and a tag's details page show
    /// it. Here, not in `TagsScreen.swift`, so the screen models stay free of SwiftUI.
    var styledCounts: AttributedString {
        // String needed: styled, its bold nudging count turned red.
        var text = AttributedString(localized: counts)
        for run in text.runs where run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
            text[run.range].foregroundColor = Color.negative
        }
        return text
    }
}
