import SwiftUI

/// DESIGN.md's rounded icon tile with a white glyph: a Settings row's, and a How Sharing Works
/// row's. Decoration, so VoiceOver skips it.
struct SquareTile: View {
    let symbol: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.white)
            .padding(size * 0.2)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: Design.Radius.token).fill(color))
            .accessibilityHidden(true)
    }
}
