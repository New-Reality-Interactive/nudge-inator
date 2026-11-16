import SwiftUI

/// An empty state's title and picture, for `ContentUnavailableView`'s label: the title read as a
/// heading, so the headings rotor finds it, and the picture hidden, so VoiceOver never reads a
/// symbol's name. Set here rather than left to the view, as Apple's docs don't say how
/// `ContentUnavailableView` reads them (#221).
struct EmptyStateLabel<Title: View>: View {
    let systemImage: String
    let title: Title

    init(systemImage: String, @ViewBuilder title: () -> Title) {
        self.systemImage = systemImage
        self.title = title()
    }

    var body: some View {
        Label {
            title
        } icon: {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
        }
        .accessibilityAddTraits(.isHeader)
    }
}
