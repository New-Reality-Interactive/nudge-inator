import SwiftUI

/// How Sharing Works (#423; #430, the mockup `2026-11-16-tutorial-swipe-top-bar`): four pages on
/// what sharing is, connecting, sending and who sees what. A swipe moves between them, and so do Back
/// and Next, together top right, which the HIG's Gestures page asks for: a gesture is a shortcut,
/// not the only way. On the last page Next becomes the system's confirm checkmark, which closes the
/// sheet, and Close is top left on every page. It takes no model, so opening and closing it changes
/// nothing.
struct SharingTutorialSheet: View {
    @State private var paging = SharingTutorialPaging()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // A paged TabView: the pages sit side by side and settle one at a time, and it mirrors
                // for right to left. Its own dots are off: the page's dots stay under it, pinned.
                TabView(selection: $paging.page) {
                    ForEach(SharingTutorialPage.allCases, id: \.self) { page in
                        TutorialPage(page: page)
                            .tag(page)
                            // Only the page on screen is reachable with VoiceOver.
                            .accessibilityHidden(page != paging.page)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                PageDots(paging: paging)
                    .padding(.vertical, Design.Spacing.s3)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            // The new page's heading is spoken, as an announcement: VoiceOver's focus is never moved
            // by hand (#276, #221).
            .onChange(of: paging.page) { _, page in
                VoiceOverAnnouncement.post(page.heading)
            }
            .navigationTitle(Text("How Sharing Works", comment: "How Sharing Works: the sheet's title, and the Settings row under Sharing that opens it."))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // The system draws it (`xmark`) and names it Close, as Apple's docs show.
                    Button(role: .close) {
                        dismiss()
                    }
                }
                // Image buttons share one glass capsule (WWDC25, "Build a UIKit app with the new
                // design"); the confirm checkmark gets its own.
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        withAnimation { paging.goBack() }
                    } label: {
                        Label {
                            Text("Back", comment: "How Sharing Works: the top bar's button (a back arrow) that goes back a page. Dimmed on the first page.")
                        } icon: {
                            Image(systemName: "chevron.backward")
                        }
                    }
                    .disabled(!paging.canGoBack)
                    if !paging.isLastPage {
                        Button {
                            // Animated, so the page slides as a swipe moves it.
                            withAnimation { paging.goForward() }
                        } label: {
                            Label {
                                Text("Next", comment: "How Sharing Works: the top bar's button (a forward arrow) that goes on to the next page.")
                            } icon: {
                                Image(systemName: "chevron.forward")
                            }
                        }
                    }
                }
                if paging.isLastPage {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .confirm) {
                            dismiss()
                        } label: {
                            Label {
                                Text("Done", comment: "How Sharing Works: the last page's confirm button (a checkmark), in place of Next, which closes the sheet.")
                            } icon: {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
    }
}

/// One page: its picture, heading and rows, in an inset grouped list that scrolls on its own.
private struct TutorialPage: View {
    let page: SharingTutorialPage

    var body: some View {
        List {
            Section {
                PageTop(page: page)
            }
            .listRowBackground(Color.clear)
            content
        }
    }

    @ViewBuilder private var content: some View {
        switch page.content {
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
}

/// The page's picture, its heading and, on a page of points, the lead under it.
private struct PageTop: View {
    let page: SharingTutorialPage

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
