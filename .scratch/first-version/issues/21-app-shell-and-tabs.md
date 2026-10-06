Status: ready-for-agent

# App shell: tab bar, theme, empty states

Visual spec: `docs/mockups/2026-10-04-first-version/` (open `index.html`; the README describes the screens).

Design spec: `docs/design/DESIGN.md` (Colors, Typography, Layout & Spacing, Mapping to code). Where it and the mockup disagree, see its Precedence note.

## What to build

Tab bar (SwiftUI `TabView` with `Tab(_:systemImage:)`, as in Apple's `tabBarMinimizeBehavior` example) with Now, My Day, Tags and Settings in the mockup's order, placeholder content with empty states, the app tint, and the shared styles (Light, Dark, Dynamic Type, Bold Text). The + button entry point on Now and My Day is present but may be disabled until ticket 23.

Also create the shared design constants once (asset-catalog color sets with Increased Contrast variants, `Color` statics, the radii and spacing `enum`), as described in DESIGN.md › Mapping to code.

## Acceptance criteria

- [ ] Every custom color in DESIGN.md's frontmatter exists as a color set with light, dark and Increased Contrast values.
- [ ] Four tabs with the mockup's titles and SF Symbols (verify symbol names against the mockup `index.html`).
- [ ] Each empty tab shows a sensible empty state.
- [ ] Previews exist for Light and Dark and the largest Dynamic Type size; no truncated tab titles.
- [ ] A screenshot (simulator) of each tab is attached or described in the ticket's Comments, compared with the mockup.

Blocked by: 01
