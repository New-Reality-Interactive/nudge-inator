import SwiftUI

/// DESIGN.md's Settings row: an icon tile, the label in body, and a trailing status or accessory. A
/// row that opens a page to set a value, as Default Pace does, shows the value under the label
/// instead, so it never shares the line with it. The tile is decoration, so VoiceOver reads the
/// label, the value and the status as one element. Stacked at accessibility sizes, where beside
/// each other the pieces would leave a few letters of width.
struct SettingsRow: View {
    let tile: Color
    let symbol: String
    let title: Text
    var titleColor: Color = Color(uiColor: .label)
    /// Under the label, such as "Consistent · 10 min".
    var value: Text?
    var status: Text?
    var statusIsNegative = false
    var accessory: Accessory?

    /// What ends the row: a chevron, or for a row that leaves the app, as About's links do,
    /// `arrow.up.forward`.
    enum Accessory {
        case chevron, link

        var symbol: String {
            switch self {
            case .chevron: "chevron.right"
            case .link: "arrow.up.forward"
            }
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = Design.Size.settingsTile

    /// Not past the least tap height: stacked above the text, a tile scaled with it only costs room.
    private var scaledTile: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? min(tileSize, Design.Spacing.rowMin) : tileSize
    }

    /// Read in `body` and captured: the iOS 27 SDK's `alignmentGuide` closure is `Sendable`, so it
    /// can't read the view's main-actor properties itself.
    private var separatorInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 0 : scaledTile + Design.Spacing.s3
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
            VStack(alignment: .leading, spacing: Design.Spacing.s1) {
                title
                    .font(.body)
                    .foregroundStyle(titleColor)
                if let value {
                    value
                        .font(.body)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: Design.Spacing.s3) }
            if let status {
                status
                    .font(.body)
                    .foregroundStyle(statusIsNegative ? Color.negative : Color(uiColor: .secondaryLabel))
            }
            if let accessory {
                Image(systemName: accessory.symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .accessibilityHidden(true)
            }
        }
        // Separators start at the text, past the tile: 60 pt at the default size (DESIGN.md).
        .alignmentGuide(.listRowSeparatorLeading) { [separatorInset] dimensions in
            dimensions[.leading] + separatorInset
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Rows") {
    List {
        SettingsRow(tile: .tileRed, symbol: "bell", title: Text(verbatim: "Notifications"), status: Text(verbatim: "Off"), statusIsNegative: true)
        SettingsRow(tile: .tileOrange, symbol: "alarm", title: Text(verbatim: "Alarms"), status: Text(verbatim: "On"))
        SettingsRow(tile: .tileGray, symbol: "gearshape", title: Text(verbatim: "Open iOS Settings"), titleColor: .accentColor, accessory: .chevron)
    }
}

#Preview("Rows, largest text") {
    List {
        SettingsRow(tile: .tileRed, symbol: "bell", title: Text(verbatim: "Notifications"), status: Text(verbatim: "Off"), statusIsNegative: true)
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
