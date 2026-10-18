import CoreGraphics

/// DESIGN.md's radii, spacing and sizes (frontmatter `rounded`, `spacing` and `components`), in
/// points. Views use these instead of repeating literals. Colors are in `DesignColors.swift`.
enum Design {
    /// The 4 / 8 / 12 / 16 / 24 scale, and the named gaps on it.
    enum Spacing {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s5: CGFloat = 24
        /// The side margin of inset grouped sections.
        static let margin: CGFloat = 16
        /// Between any two controls with a visible shape (Done and Edit buttons, tokens).
        static let controlGap: CGFloat = 12
        /// The least height of a row, and of every button.
        static let rowMin: CGFloat = 44
        /// Landscape content is centered at this width (ticket 23).
        static let readableWidth: CGFloat = 672
        /// A nudge card at least this wide puts its actions in a side column.
        static let wideCard: CGFloat = 540
        /// Between lines of one block of text, such as a row's title and its detail (the mockup's
        /// 2 px margins).
        static let line: CGFloat = 2
        /// A nudge card's padding above and below its content (the mockup's `.nudgecard`).
        static let cardVertical: CGFloat = 14
        /// Between a wide nudge card's text and its side column (the mockup's `.nc` gap).
        static let sideColumnGap: CGFloat = 20
    }

    enum Radius {
        /// Buttons, inset lists.
        static let control: CGFloat = 10
        /// Nudge cards and permission banners.
        static let card: CGFloat = 12
        /// Tag tokens, drawn by the system.
        static let token: CGFloat = 7
        /// Sheet tops, set by the system.
        static let sheet: CGFloat = 38
        /// Capsules: bar buttons, filter tokens, the strength badge, the nudge meter.
        static let full: CGFloat = 9999
    }

    /// The fixed sizes components name.
    enum Size {
        /// The nudge card's leading urgency stripe.
        static let stripeWidth: CGFloat = 5
        /// The nudge meter's track.
        static let meterHeight: CGFloat = 6
        /// The chosen count's inset accent ring on My Day.
        static let ringWidth: CGFloat = 2
        /// The permission banner's border.
        static let bannerBorder: CGFloat = 2
        /// A wide nudge card's side column, at the default text size (the mockup's 13rem).
        static let sideColumn: CGFloat = 208
        /// A Now row's time column, at the default text size: wide enough for "12:30 PM".
        static let timeColumn: CGFloat = 72
        /// The strength badge's padding inside its outline (the mockup's `.cap`).
        static let badgeVerticalPadding: CGFloat = 1
        static let badgeLeadingPadding: CGFloat = 6
    }
}
