---
name: Nudge-inator
description: Design system for the first version of Nudge-inator, an iPhone reminders app that keeps nudging until you tap Done. Native iOS 26, calm and plain, with one teal accent and status colors that each mean exactly one thing.
status: draft
inherits: Apple Human Interface Guidelines (iOS 26); SwiftUI system components
derived-from: DESIGN.md of 2026-10-03 (fuller product), pruned to the first-version spec
colors:
  # Variants: X (light), X-dark, X-ic (Increased Contrast light), X-dark-ic. Each custom color is one
  # asset-catalog color set with all four appearances. Only alarm-tint pins a variant.
  # Accent means "you can tap this", nothing else.
  accent: '#04666B'
  accent-dark: '#07DDE6'
  accent-ic: '#04474A'
  accent-dark-ic: '#A5FAFE'
  on-accent: '#FFFFFF'
  on-accent-dark: '#000000'
  on-accent-ic: '#FFFFFF'
  on-accent-dark-ic: '#000000'
  # Status colors: text-legible variants of the system hues. One color, one meaning.
  negative: '#D70015'
  negative-dark: '#FF6961'
  negative-ic: '#9E0010'
  negative-dark-ic: '#FFA39C'
  warning: '#C93400'
  warning-dark: '#FF9F0A'
  warning-ic: '#8F2800'
  warning-dark-ic: '#FFB340'
  positive: '#1E7B34'
  positive-dark: '#30D158'
  positive-ic: '#145A22'
  positive-dark-ic: '#5DE07B'
  neutral: '#6C6C70'
  neutral-dark: '#AEAEB2'
  neutral-ic: '#3C3C43'
  neutral-dark-ic: '#D1D1D6'
  # Badge: the same value in light and dark.
  badge: '#E9152D'
  badge-ic: '#B00012'
  # System semantic colors. Use the SwiftUI/UIKit color by name; values are for reference only.
  grouped-background: '#F2F2F7'
  grouped-background-dark: '#000000'
  grouped-background-dark-elevated: '#1C1C1E'
  cell: '#FFFFFF'
  cell-dark: '#1C1C1E'
  cell-dark-elevated: '#2C2C2E'
  label: '#000000'
  label-dark: '#FFFFFF'
  secondary-label: '#6C6C70'
  secondary-label-dark: '#AEAEB2'
  secondary-label-ic: '#3C3C43'
  secondary-label-dark-ic: '#D1D1D6'
  tertiary-label: '#3C3C434D'
  tertiary-label-dark: '#EBEBF54D'
  separator: '#C6C6C8'
  separator-dark: '#38383A'
  tertiary-fill: '#EBEBF0'
  tertiary-fill-ic: '#E9E9EE'
  tertiary-fill-dark: '#2C2C2E'
  tertiary-fill-dark-elevated: '#3A3A3C'
  token-fill: '#FFFFFF'
  token-fill-dark: '#1C1C1E'
  # Settings icon tiles: the same value in every mode, with white glyphs.
  tile-red: '#E9152D'
  tile-orange: '#C55300'
  tile-gray: '#6C6C70'
  tile-blue: '#1E6EF4'
  # Swipe action tile.
  tile-green: '#008932'
typography:
  # Platform text styles only. Sizes are at the default (Large) size and scale with Dynamic Type.
  family:
    note: 'System font only (SF Pro). Weights Regular, Medium, Semibold, Bold.'
  large-title:
    note: 'Bold (34 pt). Screen titles.'
  title-2:
    note: 'Bold (22 pt). Reminder title in details, My Day count numbers.'
  title-3:
    note: '(20 pt). Section headers on Now, such as Nudging.'
  headline:
    note: 'Semibold (17 pt). Nudge card titles, nav titles, alert titles, and section headers in the secondary label color (iOS 26 inset grouped lists).'
  body:
    note: '(17 pt). Row titles, buttons.'
  subhead:
    note: '(15 pt). Row details, status labels, tokens, small buttons.'
  footnote:
    note: '(13 pt). Section footers, timestamps, How It Nudges rows.'
  caption-1:
    note: 'Semibold (12 pt). Strength badge, urgency word, count labels.'
rounded:
  # Points.
  control: 10
  card: 12
  token: 7
  sheet: 38
  full: 9999
spacing:
  '1': 4
  '2': 8
  '3': 12
  '4': 16
  '5': 24
  margin: 16
  control-gap: 12
  row-min: 44
  readable-width: 672
  wide-card: 540
components:
  button-prominent:
    background: '{colors.accent}'
    text: '{colors.on-accent}'
    rounded: '{rounded.control}'
    minHeight: '{spacing.row-min}'
  button-bordered:
    background: '{colors.tertiary-fill}'
    text: '{colors.accent}'
    rounded: '{rounded.control}'
    minHeight: '{spacing.row-min}'
  nudge-card:
    background: '{colors.cell}'
    rounded: '{rounded.card}'
    stripe-width: 5
    stripe-normal: '{colors.neutral}'
    stripe-high: '{colors.warning}'
    stripe-urgent: '{colors.negative}'
  nudge-meter:
    height: 6
    track: '{colors.tertiary-fill}'
    fill-normal: '{colors.neutral}'
    fill-high: '{colors.warning}'
    fill-urgent: '{colors.negative}'
    rounded: '{rounded.full}'
  urgency-word:
    typography: '{typography.caption-1}'
    high: '{colors.warning}'
    urgent: '{colors.negative}'
  strength-badge:
    border: '{colors.neutral}'
    text: '{colors.label}'
    rounded: '{rounded.full}'
    typography: '{typography.caption-1}'
  status-label:
    typography: '{typography.subhead}'
    done: '{colors.positive}'
    nudging: '{colors.negative}'
    missed: '{colors.negative}'
    other: '{colors.secondary-label}'
  count-chosen:
    background: '{colors.tertiary-fill}'
    ring: '{colors.accent}'
    ring-width: 2
    label: '{colors.label}'
  tag-token:
    background: '{colors.token-fill}'
    text: '{colors.accent}'
    selected-background: '{colors.accent}'
    selected-text: '{colors.on-accent}'
    rounded: '{rounded.token}'
  filter-token:
    background: '{colors.tertiary-fill}'
    text: '{colors.accent}'
    rounded: '{rounded.full}'
    minHeight: '{spacing.row-min}'
  permission-banner:
    background: '{colors.cell}'
    border-notifications-off: '{colors.negative}'
    border-other: '{colors.warning}'
    border-width: 2
    rounded: '{rounded.card}'
  how-it-nudges:
    typography: '{typography.footnote}'
    urgency-normal: '{colors.neutral}'
    urgency-high: '{colors.warning}'
    urgency-urgent: '{colors.negative}'
  swipe-done:
    background: '{colors.tile-green}'
  alarm-tint:
    stop-open-tint: '{colors.accent-dark}'
---

# Nudge-inator design

This is the design contract for implementation stories. A story that draws UI cites a section here
and meets it. It was extracted from the 2026-10-03 design doc and pruned to the
[first-version spec](../../.scratch/first-version/spec.md). Vocabulary comes from
[GLOSSARY.md](../../GLOSSARY.md): say Done, Nudging, Missed, Strength and Urgency, not synonyms.

**Precedence.** This doc owns tokens and rules: colors, type, spacing, shapes, and "one color, one
meaning". The [as-built mockup](../mockups/2026-10-21-as-built/index.html) owns how each screen
is composed (the [first-version mockup](../mockups/archive/2026-10-04-first-version/index.html) it
replaced is archived). The [proposed pace mockup](../mockups/2026-10-21-proposed-pace/index.html)
is the as-built one changed for pace; the enhancement-pace tickets build to it. If they disagree
on a token value, this doc wins and the mockup gets fixed.
If they disagree on a screen's layout, the mockup wins: the proposed one, for what it changes. The mockup's HTML still carries code from
the 2026-10-02 mockup (Snooze, quiet hours, Live Activity); anything the
[spec](../../.scratch/first-version/spec.md) puts out of scope is not a requirement.

## Brand & Style

Nudge-inator is a **native iPhone utility with a mischievous name**. The name promises a contraption
that won't leave you alone; the app keeps that promise with behavior, not decoration. On screen it is
calm and plain: Apple's components, the system font, inset grouped lists, and Liquid Glass where
iOS 26 puts it. People open it when something is nudging them, often stressed or distracted, so
every screen must read at a glance.

Personality lives in two places only: **the name** and **the app icon**. Everything else is
restraint: one accent, status colors with one meaning each, no illustrations, no celebration. Done
is relief, not a reward.

App icon constraints (the artwork is a separate design task and blocks no story; use a placeholder):
- A character mark, a small friendly contraption or face, as an iOS 26 layered icon (Icon Composer)
  with light, dark, clear and tinted variants. It must read at 29 pt.
- Its main color is the accent teal (Lagoon). It never uses red or orange, which mean "needs you".

## Colors

**One color, one meaning.** Nothing else may use a color that has a job. Use system semantic colors
by name wherever iOS provides one. Custom colors are asset-catalog color sets with light, dark,
Increased Contrast and dark Increased Contrast values (frontmatter suffixes).

- **Accent (Lagoon, `{colors.accent}`)** is `AccentColor`. It means **you can tap this**: buttons,
  links, menus, checkmarks, the selected tab, tag and filter tokens, the chosen count's ring, the
  filled confirm button in each sheet, and **Done** on nudge cards.
  - **Never** a status, decoration or background wash.
  - **The alarm** sits on a dark Lock Screen, so its tint pins `{colors.accent-dark}`. This is the
    only place a component pins a variant.
- **Negative (red)** means **danger, or needs you now**: Nudging, Urgent, Missed, errors, "Off",
  destructive actions, the notifications-off banner.
- **Warning (orange)** means **escalating**: High urgency, and the alarms-off and Time Sensitive-off
  banners.
- **Positive (green)** means **done or on**: the Done status and switches that are on. No button
  uses it.
- **Neutral (gray)** marks **Normal urgency**, tags, strength badges and counts of 0.
- **Badge (`{colors.badge}`)** is the Now tab's nudging count and My Day's Filter button's count of
  tags chosen, both as the system draws them (red; SwiftUI can't recolor the Filter button's, and
  the app doesn't bridge to UIKit for it). A count of 0 shows no badge, so it is never red. At the
  accessibility text sizes the Filter button has no badge: on iOS 27 the system draws it at the text
  size, so it covers the icon. The chosen-tag tokens and the VoiceOver label carry the count there.
- **Tiles** are Apple's Increased Contrast light values in every mode with white glyphs. The swipe
  action is `{colors.tile-green}`. Settings rows: red (Notifications, Delete All Data), orange
  (Alarms), gray (Open iOS Settings, Default Pace, How It Nudges), blue (Send a Test Nudge). Tiles are icons for rows, not
  statuses, so "one color, one meaning" does not apply to them.

Rules:
- **Tags and strength have no color.** Tags are neutral, and chosen tags in a row are bold, not
  colored. Strength is its name plus a bars glyph.
- **A nudge card takes its color from urgency only:** neutral, warning or negative. The urgency word
  and glyph always come with the color.
- **Zero isn't a status.** A count of 0 uses `{colors.secondary-label}`, never red.
- **Fill sparingly.** Only primary actions get an accent fill: the sheet's confirm button and the
  nudge card's Done. My Day's per-row Done buttons are bordered, so a long list isn't a column of
  teal.
- **Status and secondary text never sit on `{colors.tertiary-fill}`, except as large text.** The
  chosen count's number (Title 2 bold) is large text; its caption uses `{colors.label}`.
- **Lagoon sits near green and gray.** Tappability never depends on hue alone: Done buttons have a
  shape, the Done status has a glyph, and plain text buttons honor Button Shapes.

**Contrast** (WCAG; inherited from the 2026-10-03 audit, **not re-measured for the first version**).
Targets are 4.5:1, or 7:1 with Increase Contrast; large text 3:1, or 4.5:1.

| Text color | Light | Dark (cell / elevated cell) | IC light | IC dark |
|---|---|---|---|---|
| Accent | 6.04 | 10.12 / 8.29 | 9.38 | 14.35 |
| Negative | 4.83 | 6.03 / 4.94 | 7.65 | 8.89 |
| Warning | 4.73 | 8.28 / 6.78 | 7.61 | 9.54 |
| Positive | 4.78 | 8.42 / 6.89 | 7.48 | 10.06 |
| Secondary label | 4.69 | 7.69 / 6.30 | 9.80 | 11.18 |
| On-accent on accent fill | 6.74 | 12.49 | 10.47 | 17.71 |

Device checks (not verifiable in a simulator): the selected tab's title on iOS 26's glass pill, in
all four appearances.

## Typography

SF Pro through the built-in text styles only, never an ad-hoc size, with Dynamic Type and Apple's
tracking. Roles are in the frontmatter. Nothing is smaller than 11 pt. Weights are Regular, Medium,
Semibold and Bold; Bold Text steps each up one level. The tab bar, inline navigation titles and bar
buttons keep their default size. Counts and times are numerals through the system formatters.

## Layout & Spacing

- **Scale:** 4 / 8 / 12 / 16 / 24 pt. `{spacing.margin}` (16) is the side margin of inset grouped
  sections; 24 separates sections; `{spacing.control-gap}` (12) separates any two controls with a
  visible shape (Done and Edit buttons, tokens).
- **Rows** are at least `{spacing.row-min}` (44 pt), padded 10 pt vertically and 16 pt horizontally,
  with separators inset 16 pt (60 pt in lists with icon tiles).
- **One column on every iPhone.** In landscape, content is centered at `{spacing.readable-width}`;
  backgrounds run to the edges and controls stay in the safe areas.
- **Width, not model.** A nudge card at least `{spacing.wide-card}` wide puts its actions in a side
  column. Landscape work: ticket 23.
- **Accessibility sizes stack** rows, form rows and nudge cards vertically and let text wrap. How-to
  rules: [AGENTS.md › Accessibility](../../AGENTS.md).

## Elevation & Depth

Depth comes from the system's layers, never custom shadows.
- **Liquid Glass only in the functional layer:** the tab bar, bar buttons, and the like, in the
  regular variant. The content layer uses ordinary fills.
- **Navigation bars have no background.** Content scrolls under the glass buttons behind the system's
  scroll edge effect.
- **Dark mode uses elevated backgrounds** for sheets and alerts: `{colors.grouped-background-dark-elevated}`
  behind, `{colors.cell-dark-elevated}` and `{colors.tertiary-fill-dark-elevated}` for cells.
- **System materials stay system:** alerts, notifications and the alarm keep standard materials.
- **Reduce Transparency** makes materials solid; **Increase Contrast** gives glass an edge. The
  system does both; don't override.
- **Cards** sit on `{colors.cell}` against `{colors.grouped-background}`, separated by tone, not shadow.

## Shapes

Corners are concentric and native. Nothing uses a shape the system wouldn't draw.
- `{rounded.control}` (10): buttons, inset lists.
- `{rounded.card}` (12): nudge cards and permission banners.
- `{rounded.full}`: bar buttons, filter tokens, the strength badge, the nudge meter, small buttons.
- `{rounded.token}` (7): tag tokens, drawn by the system.
- `{rounded.sheet}` (38): sheet tops, set by the system.

## Components

Each item gives, only where they apply: **Token** (frontmatter `components` key, or "system") ·
Container · Type · Color · Glyphs · Notes. System controls not listed (`Toggle`, `Picker`, `Stepper`,
text fields, confirmation dialogs, alerts) are used as the system draws them.

**Iconography.** SF Symbols in one weight matched to the adjacent text; they scale with Dynamic Type
except in the tab and navigation bars. Verify names against the mockup.

| Use | Symbols |
|---|---|
| Standard actions | `checkmark`, `xmark`, `trash`, `plus`, `tag.filter` (custom, in the asset catalog: the Tags tab's `tag` with a three-line filter badge at the lower right: Filter by Tags) |
| Tabs | `bell` (Now), `calendar` (My Day), `tag` (Tags), `gearshape` (Settings) |
| Urgency | `arrow.up` (High), `alarm` (Urgent) |
| Status | `checkmark.circle.fill` (Done), `bell.slash`, `clock`, `exclamationmark.triangle`, `lock` (a field locked while nudging, always beside its reason as text) |

### Nudge card
- **Token:** `nudge-card`. **Container:** `{colors.cell}`, `{rounded.card}`, 5 pt leading stripe in
  the urgency color. Top row: strength badge, urgency word ("High" with `arrow.up`, "Urgent" with
  `alarm`, nothing for Normal), and "Nudge 3 of 20". The nudge meter sits below the details. No chevron.
- **Type:** title `{typography.headline}`, details `{typography.subhead}` in `{colors.secondary-label}`,
  footer `{typography.footnote}`.
- **Notes:** **Done** is `button-prominent` with `checkmark`. At accessibility sizes it sits directly
  under the title.

### Nudge meter
- **Token:** `nudge-meter`. A 6 pt capsule track; fills from the leading edge in the urgency color;
  shows nudges sent out of the give-up limit.

### Reminder row
- Inset grouped row. Time and title in `{typography.body}`; tag and detail line in
  `{typography.subhead}` (chosen tags bold), wrapping. Trailing: the status label, or a small
  `button-bordered` **Done** on My Day. Chevron `chevron.right` in `{colors.tertiary-label}`.

### Status label
- **Token:** `status-label`. `{typography.subhead}` semibold. Done green with `checkmark.circle.fill`;
  Nudging and Missed red; Skipped, Paused and Coming up in secondary label. A glyph or word always
  accompanies the color.

### Strength badge
- **Token:** `strength-badge`. Outlined capsule, neutral border, a 1-, 2- or 3-bar glyph then the name.

### Via label
- `{typography.subhead}`; `alarm` or `bell`; "Notifications off" in `{colors.negative}` with `bell.slash`.

### Counts (My Day)
- **Token:** `count-chosen`. Four cells: Done, Nudging, Missed, Left. Number in `{typography.title-2}`
  with a caption. Done positive, Nudging and Missed negative, Left label, 0 secondary label. The
  chosen count gets a tertiary fill and a 2 pt inset accent ring.

### Tags
- **Tag token field / tag token:** `tag-token`, system-drawn. **Tag tile:** a round gray tile with `tag`,
  decorative.
- **Filter token:** `filter-token`, a 44 pt capsule with `xmark`. **Match control:** system segmented
  `Picker`, a menu at accessibility sizes.

### How It Nudges
- **Token:** `how-it-nudges`. Inset grouped list, summary in the section footer, `{typography.footnote}`
  rows. Each row leads with a small urgency dot, then urgency word, time range and Via label.

### Buttons
- Every button is at least 44 pt tall.
- `button-prominent` (accent fill, semibold) for one primary action per context; `button-bordered` for
  secondary; plain accent text for tertiary (honors Button Shapes); destructive text in `{colors.negative}`.
- Disabled uses `{colors.secondary-label}`; a disabled prominent button becomes a hairline outline.

### Sheet bar buttons
- iOS 26 system: cancel is a glass circle with `xmark`, confirm an accent-filled glass circle with
  `checkmark`.

### Permission banner
- **Token:** `permission-banner`. `{colors.cell}`, `{rounded.card}`, 2 pt border (negative for
  notifications off, warning otherwise), icon, bold lead sentence, **Open Settings** as a small
  bordered button. At accessibility text sizes the icon goes above the text and the button fills
  the banner's width with `{rounded.control}` corners, as a nudge card's Done does; its label
  wraps there rather than truncating.

### Settings row
- Icon tile, label in `{typography.body}`, trailing status in `{colors.secondary-label}` (or
  `{colors.negative}` when off) or a chevron. A row that opens a page to set a value shows the
  value under the label in `{typography.body}` `{colors.secondary-label}`, with the chevron
  (Default Pace: "Consistent · 10 min"), so it never shares the line with the label. Tile colors
  are listed under Colors.

### Swipe actions
- **Token:** `swipe-done`. Trailing swipe shows Done: green tile, white `checkmark` and the word
  "Done". There is no Snooze.

### Alarm
- **Token:** `alarm-tint`. iOS draws everything except the title, the secondary **Open** button and
  the tint. Tint is `{colors.accent-dark}`. Behavior: spec › Alarm presentation and ADR 0001.

## Mapping to code

- **Colors:** asset-catalog color sets named after the frontmatter keys without suffix (`Accent` is
  `AccentColor`, plus `Negative`, `Warning`, `Positive`, `Neutral`, `Badge`, `TileRed` etc.), each
  with Any/Dark and Increased Contrast appearances. Expose them as `Color` statics in the app target
  and, where the widget needs them, in `NudgeShared`. `NudgeEngine` never imports them.
- **Type:** `Font` text styles (`.headline`, `.subheadline`, ...) with `.weight(...)` where the role
  says so. No `.system(size:)`.
- **Constants:** radii, spacing and sizes from the frontmatter live in one shared `enum` in the app
  target. Don't repeat literals in views. Ticket 22 creates these once.
- **Reuse:** a component with a token is one reusable SwiftUI view or `ButtonStyle`, with a `#Preview`.

## Deferred to a later version

Dropped from the 2026-10-03 doc because the first version has no such feature: quiet hours (indigo
`quiet`, chip, markers), Snooze (teal tile, Snooze button, alarm Snooze fill), Not Done and Undo
(status message), History, Search, Export Data, Siri & Shortcuts, Version row, Live Activity,
Assistive Access, carry-over ("Starts higher"), the Skipped badge variants for iOS 18 and 27, and
every iOS 18 and 27 branch. Restore from git history (`DESIGN.md` of 2026-10-03) when a feature returns.

## Do's and Don'ts

| Do | Don't |
|---|---|
| Use Lagoon only for things you can tap | Use the accent for status, decoration, headers or backgrounds |
| Give every status a word, and urgency a word and glyph, as well as a color | Show a state by color, icon or position alone |
| Let urgency (neutral, orange, red) be the only color on a nudge card | Color tags, strengths or categories |
| Give Done buttons a shape, and the Done status a glyph | Draw two different "Done"s as bare text that differ only in hue |
| Fill one primary action per context | Fill every Done in a list |
| Use system components, materials and SF Symbols | Draw custom tab bars, bars, sheets or alerts |
| Keep personality in the name and icon | Put mascots, illustrations, confetti or jokes in screens |
| Use text styles and let them grow, stacking layouts | Use fixed font sizes, truncate with "…", or shrink text |
| Keep red for "needs you now" | Use red or orange in the app icon or decoration |
