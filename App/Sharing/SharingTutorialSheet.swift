import SwiftUI

/// How Sharing Works (#423, the mockup `2026-11-15-sharing-tutorial`'s `tutorialSheet`): four pages
/// on what sharing is, connecting, sending and who sees what. Continue moves forward and the last
/// page's button is Done; Back is top left from page 2, and Close is top right on every page. The
/// last page so shows Close, Back and Done together, which the HIG's Sheets page says to avoid: the
/// developer chose a Close on every page, for consistency. It takes no model, so opening and closing
/// it changes nothing.
struct SharingTutorialSheet: View {
    @State private var paging = SharingTutorialPaging()
    /// On the page's heading after Continue or Back, which give way to a new page: left to iOS,
    /// VoiceOver landed on Back (#423's phone check), above what the page says (#221).
    @AccessibilityFocusState private var isHeadingFocused: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PageTop(page: paging.page, isHeadingFocused: $isHeadingFocused)
                }
                .listRowBackground(Color.clear)
                pageContent
                Section {
                    PageDots(paging: paging)
                    Button(action: forward) {
                        (paging.isLastPage
                            ? Text("Done", comment: "How Sharing Works: the last page's button, which closes the sheet.")
                            : Text("Continue", comment: "How Sharing Works: the button that goes on to the next page."))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .listRowBackground(Color.clear)
                // No divider between the dots and the button, as the mockup has none (#423's phone check).
                .listRowSeparator(.hidden)
                .listSectionSpacing(Design.Spacing.s2)
            }
            // A new page starts at its top, not where the last one was scrolled to.
            .id(paging.page)
            .onChange(of: paging.page) { isHeadingFocused = true }
            .navigationTitle(Text("How Sharing Works", comment: "How Sharing Works: the sheet's title, and the Settings row under Sharing that opens it."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if paging.canGoBack {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            paging.goBack()
                        } label: {
                            Label {
                                Text("Back", comment: "How Sharing Works: the button, top left from the second page, that goes back a page.")
                            } icon: {
                                Image(systemName: "chevron.backward")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // The system draws it (`xmark`) and names it Close, as Apple's docs show.
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder private var pageContent: some View {
        switch paging.page.content {
        case .points(_, let points):
            Section {
                ForEach(points.indices, id: \.self) { PointRow(point: points[$0]) }
            }
        case .steps(let steps, let footnote):
            Section {
                ForEach(steps.indices, id: \.self) { StepRow(number: $0 + 1, step: steps[$0]) }
            } footer: {
                Text(footnote)
            }
        }
    }

    private func forward() {
        if paging.isLastPage { dismiss() } else { paging.goForward() }
    }
}

/// The page's picture, its heading and, on a page of points, the lead under it.
private struct PageTop: View {
    let page: SharingTutorialPage
    let isHeadingFocused: AccessibilityFocusState<Bool>.Binding

    /// A pill's gap between its icon and word: the mockup's 8 pt, growing with the text, or at the
    /// largest sizes `person.badge.plus`'s badge touches the word (#423's phone check).
    @ScaledMetric(relativeTo: .subheadline) private var pillGap: CGFloat = Design.Spacing.s2

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s3) {
            // Pills side by side where they fit on one line each, else stacked, with a down arrow,
            // as at the largest text sizes in portrait (#423's phone check).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Design.Spacing.s3) { art(arrow: "arrow.right") }
                VStack(spacing: Design.Spacing.s2) { art(arrow: "arrow.down") }
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
            Text(page.heading)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused(isHeadingFocused)
            if case .points(let lead?, _) = page.content {
                Text(lead)
                    .font(.body)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Drawn by hand, not as a `Label`: in a list a label tints its icon with the accent, and at
    /// the largest sizes stacks and clips inside the pill (#423's phone check). In the label color
    /// with an 8 pt gap, as the mockup's `.pill`.
    @ViewBuilder private func art(arrow: String) -> some View {
        ForEach(page.art.indices, id: \.self) { index in
            switch page.art[index] {
            case .pill(let symbol, let text):
                HStack(spacing: pillGap) {
                    Image(systemName: symbol)
                    Text(text)
                }
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .label))
                .padding(.horizontal, Design.Spacing.s4)
                .padding(.vertical, Design.Spacing.s2)
                .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
            case .arrow:
                Image(systemName: arrow)
                    .font(.title3)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
        }
    }
}

/// A row with the blue tile of its SF Symbol, the title and the line under it, read as one. Stacked
/// at accessibility sizes, as a Settings row is.
private struct PointRow: View {
    let point: SharingTutorialPage.Point

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = Design.Size.settingsTile

    /// Not past the least tap height: stacked above the text, a tile scaled with it only costs room.
    private var scaledTile: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? min(tileSize, Design.Spacing.rowMin) : tileSize
    }

    /// Read in `body` and captured, as `SettingsRow`'s: the `alignmentGuide` closure is `Sendable`.
    private var separatorInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 0 : scaledTile + Design.Spacing.s3
    }

    var body: some View {
        SizeAdaptiveStack(rowAlignment: .top, rowSpacing: Design.Spacing.s3, stackedSpacing: Design.Spacing.s2) {
            SquareTile(symbol: point.symbol, color: .tileBlue, size: scaledTile)
            RowText(title: point.title, text: point.text)
        }
        // Separators start at the text, past the tile, as in Settings.
        .alignmentGuide(.listRowSeparatorLeading) { [separatorInset] dimensions in
            dimensions[.leading] + separatorInset
        }
        .accessibilityElement(children: .combine)
    }
}

/// One of Connect's numbered steps: the number in an accent circle, the title and the line under it.
/// Stacked at accessibility sizes, as a point's row is.
private struct StepRow: View {
    let number: Int
    let step: SharingTutorialPage.Step

    @ScaledMetric(relativeTo: .footnote) private var circle: CGFloat = Design.Size.stepNumber

    /// Not past the least tap height, as a row's tile (#423's phone check: it grew to twice that).
    private var cappedCircle: CGFloat {
        min(circle, Design.Spacing.rowMin)
    }

    var body: some View {
        SizeAdaptiveStack(rowAlignment: .top, rowSpacing: Design.Spacing.s3, stackedSpacing: Design.Spacing.s2) {
            Text(number, format: .number)
                .font(.footnote.bold())
                // The number shrinks to stay inside the capped circle at the largest sizes.
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(Color.white)
                .frame(width: cappedCircle, height: cappedCircle)
                .background(Circle().fill(Color.accentColor))
            RowText(title: step.title, text: step.text)
        }
        // Dividers start at the circle's edge, as the mockup's step list draws them.
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
            dimensions[.leading]
        }
        .accessibilityElement(children: .combine)
    }
}

private struct RowText: View {
    let title: LocalizedStringResource
    let text: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s1) {
            Text(title)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Where the sheet is, as dots; VoiceOver reads "Page 2 of 4".
private struct PageDots: View {
    let paging: SharingTutorialPaging

    var body: some View {
        HStack(spacing: Design.Spacing.s2) {
            ForEach(SharingTutorialPage.allCases, id: \.self) { page in
                Circle()
                    .fill(page == paging.page ? Color.accentColor : Color(uiColor: .separator))
                    .frame(width: Design.Size.pageDot, height: Design.Size.pageDot)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(paging.position))
    }
}

#Preview("How Sharing Works") {
    Color.clear.sheet(isPresented: .constant(true)) { SharingTutorialSheet() }
}

#Preview("How Sharing Works, largest text, dark") {
    Color.clear.sheet(isPresented: .constant(true)) {
        SharingTutorialSheet()
            .environment(\.dynamicTypeSize, .accessibility5)
    }
    .preferredColorScheme(.dark)
}

#Preview("How Sharing Works, landscape", traits: .landscapeLeft) {
    Color.clear.sheet(isPresented: .constant(true)) { SharingTutorialSheet() }
}
