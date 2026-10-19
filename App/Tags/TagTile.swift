import SwiftUI

/// The gray circle with a white tag glyph, a tag's picture on the list and in the sheet.
struct TagTile: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "tag")
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.white)
            .padding(size * 0.27)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.tileGray))
            .accessibilityHidden(true)
    }
}
