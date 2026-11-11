import SwiftUI

/// A gray circle with a white glyph: a tag's picture on the list and in the sheet (`tag`), and a
/// person's on Connections (`person`). Decoration, so VoiceOver skips it.
struct RoundTile: View {
    let symbol: String
    let size: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.white)
            .padding(size * 0.27)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.tileGray))
            .accessibilityHidden(true)
    }
}
