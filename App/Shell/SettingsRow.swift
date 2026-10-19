import SwiftUI

/// DESIGN.md's Settings row: an icon tile, the label in body, and a trailing status or chevron.
/// The tile is decoration, so VoiceOver reads the label and the status as one element. Stacked at
/// accessibility sizes, where beside each other the pieces would leave a few letters of width.
struct SettingsRow: View {
    let tile: Color
    let symbol: String
    let title: Text
    var titleColor: Color = Color(uiColor: .label)
    var status: Text?
    var statusIsNegative = false
    var showsChevron = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = Design.Size.settingsTile

    /// Not past the least tap height: stacked above the text, a tile scaled with it only costs room.
    private var scaledTile: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? min(tileSize, Design.Spacing.rowMin) : tileSize
    }

    var body: some View {
        SizeAdaptiveStack(rowSpacing: Design.Spacing.s3, stackedSpacing: Design.Spacing.s2) {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.white)
                .padding(scaledTile * 0.2)
                .frame(width: scaledTile, height: scaledTile)
                .background(RoundedRectangle(cornerRadius: Design.Radius.token).fill(tile))
                .accessibilityHidden(true)
            title
                .font(.body)
                .foregroundStyle(titleColor)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: Design.Spacing.s3) }
            if let status {
                status
                    .font(.body)
                    .foregroundStyle(statusIsNegative ? Color.negative : Color(uiColor: .secondaryLabel))
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .accessibilityHidden(true)
            }
        }
        // Separators start at the text, past the tile: 60 pt at the default size (DESIGN.md).
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
            dynamicTypeSize.isAccessibilitySize ? dimensions[.leading] : dimensions[.leading] + scaledTile + Design.Spacing.s3
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Rows") {
    List {
        SettingsRow(tile: .tileRed, symbol: "bell", title: Text(verbatim: "Notifications"), status: Text(verbatim: "Off"), statusIsNegative: true)
        SettingsRow(tile: .tileOrange, symbol: "alarm", title: Text(verbatim: "Alarms"), status: Text(verbatim: "On"))
        SettingsRow(tile: .tileGray, symbol: "gearshape", title: Text(verbatim: "Open iOS Settings"), titleColor: .accentColor, showsChevron: true)
    }
}

#Preview("Rows, largest text") {
    List {
        SettingsRow(tile: .tileRed, symbol: "bell", title: Text(verbatim: "Notifications"), status: Text(verbatim: "Off"), statusIsNegative: true)
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
