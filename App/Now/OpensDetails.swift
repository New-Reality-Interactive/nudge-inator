import SwiftUI

extension View {
    /// Makes the view a plain button that opens a reminder's details, or leaves it as it is when
    /// `openDetails` is `nil`. Plain, so it keeps its look. The whole frame takes the tap, not
    /// only what is drawn: a card's top row has a gap.
    @ViewBuilder
    func opensDetails(_ openDetails: (() -> Void)?) -> some View {
        if let openDetails {
            Button(action: openDetails) { contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Opens the reminder's details.", comment: "VoiceOver hint on a nudge card's title and on a Now row: tapping it opens the reminder's details."))
        } else {
            self
        }
    }
}
