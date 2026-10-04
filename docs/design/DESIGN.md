---
name: Nudge-inator
description: An iPhone reminders app that keeps nudging until you tap Done. Native iOS, calm and plain on the surface, with one teal accent and status colors that each mean exactly one thing.
status: final
created: 2026-10-02
updated: 2026-10-03
inherits: Apple Human Interface Guidelines (iOS 18, 26, 27); SwiftUI system components
colors:
  # Suffixes: -dark, -ic (Increased Contrast light), -dark-ic. A component that references X uses
  # X, X-dark, X-ic or X-dark-ic for the current appearance. Only alarm-tint pins a variant.
  # Accent: the app's own color set (AccentColor). It means "you can tap this", nothing else.
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
  quiet: '#3634A3'
  quiet-dark: '#9290FF'
  quiet-ic: '#2B2A8C'
  quiet-dark-ic: '#B8B6FF'
  neutral: '#6C6C70'
  neutral-dark: '#AEAEB2'
  neutral-ic: '#3C3C43'
  neutral-dark-ic: '#D1D1D6'
  # Badge: the same value in light and dark.
  badge: '#E9152D'
  badge-ic: '#B00012'
  # System semantic colors. The app uses the UIKit/SwiftUI colors by name; values are for reference.
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
  # Tiles (swipe actions, Settings icons): Apple's Increased Contrast light values in every mode, with white glyphs.
  tile-green: '#008932'
  tile-teal: '#008198'
  tile-blue: '#1E6EF4'
  tile-red: '#E9152D'
  tile-orange: '#C55300'
  tile-gray: '#6C6C70'
  tile-purple: '#B02FC2'
typography:
  # Platform text styles. Sizes are at the default (Large) size and scale with Dynamic Type.
  family:
    note: 'System font only (SF Pro), Dynamic Type xSmall to AX5. Weights Regular, Medium, Semibold, Bold.'
  large-title:
    note: 'iOS Large Title, bold (34 pt). Screen titles, Welcome.'
  title-1:
    note: 'iOS Title 1, bold (28 pt). The alarm title (drawn by the system).'
  title-2:
    note: 'iOS Title 2, bold (22 pt). Reminder title in details, My Day count numbers.'
  title-3:
    note: 'iOS Title 3 (20 pt); semibold for the Nudging section header. Steppers.'
  headline:
    note: 'iOS Headline, semibold (17 pt). Nudge card titles, nav titles, alert titles.'
  body:
    note: 'iOS Body (17 pt). Row titles, buttons.'
  subhead:
    note: 'iOS Subheadline (15 pt). Row details, status labels, tokens, small buttons, status message.'
  footnote:
    note: 'iOS Footnote (13 pt). Section headers and footers, timestamps, chips, segmented controls, How It Nudges rows.'
  caption-1:
    note: 'iOS Caption 1, semibold (12 pt). Strength badge, urgency word, count labels.'
rounded:
  # Dimensions are in points (1px here = 1pt).
  control: 10px
  card: 12px
  token: 7px
  sheet: 38px
  full: 9999px
spacing:
  '1': 4px
  '2': 8px
  '3': 12px
  '4': 16px
  '5': 24px
  margin: 16px
  control-gap: 12px
  row-min: 44px
  readable-width: 672px
  wide-card: 540px
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
    stripe-width: 5px
    stripe-normal: '{colors.neutral}'
    stripe-high: '{colors.warning}'
    stripe-urgent: '{colors.negative}'
  nudge-meter:
    height: 6px
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
    ring-width: 2px
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
  quiet-chip:
    text: '{colors.quiet}'
    rounded: '{rounded.full}'
    typography: '{typography.footnote}'
  permission-banner:
    background: '{colors.cell}'
    border-notifications-off: '{colors.negative}'
    border-other: '{colors.warning}'
    border-width: 2px
    rounded: '{rounded.card}'
  status-message:
    background: '{colors.cell}'
    typography: '{typography.subhead}'
    rounded: '{rounded.full}'
  how-it-nudges:
    typography: '{typography.footnote}'
    urgency-normal: '{colors.neutral}'
    urgency-high: '{colors.warning}'
    urgency-urgent: '{colors.negative}'
  swipe-done:
    background: '{colors.tile-green}'
  swipe-snooze:
    background: '{colors.tile-teal}'
  alarm-tint:
    snooze-fill: '{colors.accent-dark}'
    snooze-text: '{colors.on-accent-dark}'
---

## Brand & Style

Nudge-inator is a **native iPhone utility with a mischievous name**. The name promises a
contraption that won't leave you alone, and the app keeps that promise with its behavior, not its
decoration. On screen it's calm and plain:
- Apple's own components and the system font
- inset grouped lists
- Liquid Glass where iOS 26 and later put it

People open it when something is nudging them, often while stressed or distracted, so every screen
has to be read at a glance.

The personality lives in two places only:
- **The name.**
- **The app icon:** a character mark, a small friendly contraption or face, that leans into the
  "-inator" humor.
  - Build it in Icon Composer as an iOS 26 layered icon, with light, dark, clear and tinted
    variants. It must read at 29 pt.
  - Its main color is Lagoon. It never uses red or orange, which mean "needs you" inside the app.
  - The mockup's Lagoon gradient is a placeholder. The artwork is designed separately; this spine
    sets only its direction and constraints.

Everything else is restraint: one accent, status colors with one meaning each, no illustrations, no
celebration. Done is relief, not a reward.

The [mockup](../mockups/2026-10-02-ux-review-changes/index.html) is the visual reference for every
iPhone screen. Precedence is set once, in the [brief's introduction](../product/brief.md).

## Colors

**One color, one meaning.** Every color has a job, and nothing else uses it.
- Each color has light, dark and Increased Contrast values, named by suffix as described in the
  frontmatter.
- The app uses the system colors by their semantic names wherever iOS provides one.

- **Lagoon** (`{colors.accent}` #04666B light, `{colors.accent-dark}` #07DDE6 dark) is the app's
  `AccentColor`. It means **you can tap this**.
  - **Used for:** buttons, links, menus, checkmarks, the selected tab, tag and filter tokens, the
    chosen count's ring, the filled confirm button in each sheet, and **Done** on nudge cards.
  - **The alarm:** Lagoon tints the AlarmKit alarm, which always sits on a dark Lock Screen, so the
    alarm uses `{colors.accent-dark}` with `{colors.on-accent-dark}` text. This is the one place a
    component pins a variant.
  - **Never** a status, decoration or background wash.
  - **Rationale:** [color study](.working/color-themes-1.html) and the [decision log](.memlog.md).
- **Negative** (red, `{colors.negative}`) means **danger, or needs you now**: nudging, Urgent,
  Missed, errors, "Off", destructive actions, and the notifications-off banner.
- **Warning** (orange, `{colors.warning}`) means **escalating**: High urgency, "↑ Starts higher",
  and the alarms-off and Time Sensitive-off banners.
- **Positive** (green, `{colors.positive}`) means **done or on**: the Done status and switches that
  are on. No button uses it.
- **Quiet** (indigo, `{colors.quiet}`) means **quiet hours**: the chip, notes and My Day markers.
  The dark values (`{colors.quiet-dark}` #9290FF and `{colors.quiet-dark-ic}` #B8B6FF) are lighter
  than the mockup's, so quiet text meets its contrast target inside sheets too.
- **Neutral** (gray, `{colors.neutral}`) marks **Normal urgency**, tags, strength badges and counts
  of 0.
- **Badge** (`{colors.badge}`) is the Now tab's nudging count, as the system draws it.
- **Tiles** use Apple's Increased Contrast light values in every mode, so white glyphs keep at least
  4.5:1 contrast:
  - swipe actions: green `{colors.tile-green}` for Done, and teal `{colors.tile-teal}` for Snooze,
    the tile nearest Lagoon
  - Settings icons: red `{colors.tile-red}`, orange `{colors.tile-orange}`, gray
    `{colors.tile-gray}`, blue `{colors.tile-blue}` and purple `{colors.tile-purple}`, assigned by
    row in [Components › Settings row](#settings-row)

  Settings tiles are icons for their rows, not statuses. "One color, one meaning" applies to text,
  fills and strokes in content, not to Settings tiles.

Rules:
- **Tags and strength have no color.** Tags are neutral, and chosen tags in a row are bold, not
  colored. Strength is its name and a bars glyph.
- **Nudge cards take their color from urgency only:** neutral, warning or negative. The urgency word
  and its glyph always come with the color.
- **Zero isn't a status.** A count of 0 uses `{colors.secondary-label}`, never red.
- **The "Now" marker on My Day is label text,** not the accent, which would mean tappable.
- **Fill sparingly.** Only primary actions get an accent fill: the sheet's confirm button and the
  nudge card's Done. My Day's per-row Done buttons are bordered, so a long list isn't a column of
  teal.
- **Status and secondary text never sit on `{colors.tertiary-fill}`, except as large text.** The
  chosen count's number (Title 2 bold) is large text. Its caption uses `{colors.label}`.
- **Lagoon sits near green and gray.** Its nearest neighbors are neutral gray (ΔE 21.9) and green
  Done (ΔE 25.2) in light mode. Done buttons have a shape, the Done status has a glyph, and tertiary
  text buttons honor Button Shapes, so tappability never depends on hue alone.

**Contrast** (WCAG; computed 2026-10-03). Targets are 4.5:1, or 7:1 with Increase Contrast. Large
text needs 3:1, or 4.5:1 with Increase Contrast.

| Text color | Light, on background / cell | Dark: background and cell / elevated cell | IC light | IC dark |
|---|---|---|---|---|
| Accent | 6.04 | 10.12 / 8.29 | 9.38 | 14.35 |
| Negative | 4.83 | 6.03 / 4.94 | 7.65 | 8.89 |
| Warning | 4.73 | 8.28 / 6.78 | 7.61 | 9.54 |
| Positive | 4.78 | 8.42 / 6.89 | 7.48 | 10.06 |
| Quiet | 8.64 | 6.20 / 5.08 | 10.38 | 9.05 |
| Secondary label | 4.69 | 7.69 / 6.30 | 9.80 | 11.18 |
| On-accent on accent fill | 6.74 | 12.49 | 10.47 | 17.71 |

Each value is the lowest across the surfaces in its column.
- **Measured on a device before release** (release gate:
  [EXPERIENCE.md › Accessibility Floor](EXPERIENCE.md#accessibility-floor)): the selected tab's
  title on the system's glass pill. It passes on the mockup's approximation (lowest: 5.42 light,
  6.54 dark, 7.42 IC light, 7.15 IC dark).
- **Still to do:** re-run the mockup's full audit with Lagoon
  ([README › Color](../mockups/2026-10-02-ux-review-changes/README.md#color) and
  [How it was checked](../mockups/2026-10-02-ux-review-changes/README.md#how-it-was-checked)).

## Typography

The platform's conventions are the spec. **SF Pro, through the built-in text styles only**, never an
ad-hoc size, with Dynamic Type from xSmall to AX5 and Apple's tracking. The roles are in the
frontmatter: `{typography.headline}` for nudge card titles, `{typography.subhead}` for row details,
and so on.

- Nothing is smaller than 11 pt. The weights are Regular, Medium, Semibold and Bold, and Bold Text
  steps each weight up one level.
- The tab bar, inline navigation titles and subtitles, and bar buttons stay at their default size
  and use the Large Content Viewer. Large titles scale.
- Counts and times are numerals, through the system formatters.

## Layout & Spacing

- **Scale:** 4 / 8 / 12 / 16 / 24 pt.
  - `{spacing.margin}` (16 pt) is the side margin of inset grouped sections.
  - 24 pt separates sections.
  - `{spacing.control-gap}` (12 pt) separates any two controls with a visible shape: Done and
    Snooze, tokens, Rename and Delete.
- **Rows** are at least `{spacing.row-min}` (44 pt) tall, padded 10 pt vertically and 16 pt
  horizontally, with separators inset 16 pt (60 pt in lists with icon tiles).
- **One column on every iPhone.** In landscape and wide windows, content is centered at
  `{spacing.readable-width}` (about 672 pt at Large). Backgrounds run to the edges, and controls
  stay inside the safe areas.
- **Width, not model.** A nudge card at least `{spacing.wide-card}` (540 pt) wide puts Done and
  Snooze in a side column. Sheets become a centered card at 700 pt or wider. Reflow rules:
  [EXPERIENCE.md › Responsive & Platform](EXPERIENCE.md#responsive--platform) and
  [Accessibility Floor](EXPERIENCE.md#accessibility-floor).
- **Accessibility sizes stack** rows, form rows and nudge cards vertically. Reflow rules:
  [EXPERIENCE.md › Responsive & Platform](EXPERIENCE.md#responsive--platform) and
  [Accessibility Floor](EXPERIENCE.md#accessibility-floor).

## Elevation & Depth

Depth comes from the system's layers, never from custom shadows.

- **Liquid Glass only in the functional layer** (iOS 26+): the tab bar, the Search circle and field,
  and bar buttons, in the regular variant. The content layer uses ordinary fills.
- **Navigation bars have no background** on iOS 26+. Content scrolls under the glass buttons, behind
  the system's scroll edge effect, which appears only once content is under the bar. iOS 18 uses its
  bar material with a hairline.
- **Dark mode uses elevated backgrounds** for sheets and alerts, so they stand out from the black
  screen: `{colors.grouped-background-dark-elevated}` behind, and `{colors.cell-dark-elevated}` and
  `{colors.tertiary-fill-dark-elevated}` for cells.
- **System materials stay system:** alerts, action sheets, notifications, the alarm and the Live
  Activity keep their standard materials.
- **Reduce Transparency** makes every material solid. **Increase Contrast** gives glass a visible
  edge.
- **Cards** sit on `{colors.cell}` against `{colors.grouped-background}`, separated by tone, not
  shadow. The status message sits in the content flow, not over it.

## Shapes

Corners are concentric and native to the system. Nothing uses a shape the system wouldn't draw.

- `{rounded.control}` (10 pt): buttons, inset lists, the search bar.
- `{rounded.card}` (12 pt): nudge cards and permission banners.
- `{rounded.full}`: bar buttons, chips, filter tokens, the strength badge, the status message, the
  nudge meter and small buttons (capsules).
- `{rounded.token}` (7 pt): tag tokens, drawn by the system.
- `{rounded.sheet}` (38 pt): sheet tops on iOS 26, set by the system. Bar buttons inside sheets are
  concentric with it.

## Components

Behavior is in [EXPERIENCE.md › Component Patterns](EXPERIENCE.md#component-patterns), under the
same names and in the same order. Each item gives, in this order and only where they apply:
**Token** (the frontmatter `components` key, or "system") · **Container** · **Type** · **Color** ·
**Glyphs** · **States/Notes**. System controls not listed here, such as `Toggle`, are used as the
system draws them.

**Iconography.** Icons are SF Symbols, in one weight matched to the text beside them. They scale
with Dynamic Type, except in the tab and navigation bars.

| Use | Symbols |
|---|---|
| Standard actions | `checkmark`, `xmark`, `trash`, `plus`, `magnifyingglass`, `line.3.horizontal.decrease`, `square.and.arrow.up` |
| Tabs | `bell`, `calendar`, `tag`, `gearshape` |
| Urgency | `arrow.up` (High), `alarm` (Urgent) |
| Status | `checkmark.circle.fill` (Done), `moon.fill` (quiet hours), `arrow.up` (starts higher), `bell.slash`, `clock`, `arrow.uturn.backward` (Not Done, Undo) |

### Nudge card
- **Token:** `nudge-card`.
- **Container:** `{colors.cell}`, `{rounded.card}`, with a 5 pt leading stripe in the urgency color
  (neutral, warning or negative). The top row holds the strength badge, the urgency word ("High"
  with `arrow.up`, or "Urgent" with `alarm`, in `urgency-word`; nothing for Normal) and
  "Nudge 3 of 20". The nudge meter sits below the details. No chevron.
- **Type:** title in `{typography.headline}`, detail lines in `{typography.subhead}`, footer in
  `{typography.footnote}`.
- **Color:** detail lines in `{colors.secondary-label}`.
- **Glyphs:** `checkmark` on Done.
- **States/Notes:** **Done** as `button-prominent` and **Snooze 15 min** as `button-bordered`,
  12 pt apart. At accessibility sizes they sit directly under the title.

### Nudge meter
- **Token:** `nudge-meter`.
- **Container:** a 6 pt capsule track in `{colors.tertiary-fill}`.
- **Color:** fills from the leading edge in the urgency color.
- **States/Notes:** shows nudges sent out of the nudge limit.

### Reminder row
- **Token:** none. Uses the color and type tokens below.
- **Container:** an inset grouped row. Trailing: the status label, or a bordered **Done**
  (`button-bordered`, small), or **Not Done** (plain accent text) for a row closed by an alarm.
- **Type:** the time and the title in `{typography.body}`. A tag and detail line in
  `{typography.subhead}`, with chosen tags bold. The line wraps.
- **Color:** the chevron in `{colors.tertiary-label}`.
- **Glyphs:** `checkmark` on Done, `arrow.uturn.backward` on Not Done, `chevron.right`.

### History
- **Token:** none. Uses the color and type tokens below.
- **Container:** occurrence disclosures in an inset grouped list. Each occurrence's header has its
  due time and status label.
- **Type:** the due time in `{typography.body}`. Events are `{typography.footnote}` rows with their
  time leading. The footer is in `{typography.footnote}`.
- **Color:** events in `{colors.secondary-label}`.

### Via label
- **Token:** none. Uses the color and type tokens below.
- **Type:** `{typography.subhead}`.
- **Color:** "Notifications off" in `{colors.negative}`.
- **Glyphs:** `alarm` or `bell`; `bell.slash` for "Notifications off".

### Strength badge
- **Token:** `strength-badge`.
- **Container:** an outlined capsule with a `{colors.neutral}` border.
- **Type:** `{typography.caption-1}`.
- **Glyphs:** a 1-, 2- or 3-bar glyph, followed by the name.

### Status label
- **Token:** `status-label`.
- **Type:** `{typography.subhead}` semibold.
- **Color:** Done is green; Nudging and Missed are red; Skipped, Paused and Coming up are secondary
  label.
- **Glyphs:** a glyph leads the word (Done: `checkmark.circle.fill`).

### Counts
- **Token:** `count-chosen` (the chosen count).
- **Container:** four cells. The chosen count gets a tertiary fill and a 2 pt inset accent ring.
- **Type:** the number in `{typography.title-2}`, with a caption label.
- **Color:** Done in positive, Nudging and Missed in negative, Left in label, and 0 in secondary
  label. The chosen count's caption is `{colors.label}`.

### Tag token field
- **Token:** `tag-token`. The system draws the tokens.

### Match control
- **Token:** system. Drawn by the system as-is: a segmented `Picker`, or a menu at accessibility
  sizes.

### Filter token
- **Token:** `filter-token`.
- **Container:** a 44 pt capsule.
- **Glyphs:** `xmark`.

### Strength picker
- **Token:** system. Drawn by the system as-is.

### Snooze length
- **Token:** system. Drawn by the system as-is: a menu `Picker`.

### Give-up limit
- **Token:** system. Drawn by the system as-is: a `Stepper` and a menu.

### How It Nudges
- **Token:** `how-it-nudges`.
- **Container:** an inset grouped list. The summary line sits in the section footer.
- **Type:** `{typography.footnote}` rows.
- **Color:** each row leads with a small urgency dot in the urgency color, followed by the urgency
  word, the time range and the Via label. The **Next one due** row is secondary label.
- **Glyphs:** `arrow.uturn.backward` on **Next one due**.

### Title field
- **Token:** system. Drawn by the system as-is: a system text field.

### Buttons
- **Token:** `button-prominent`, `button-bordered`.
- **Container:** every button is at least 44 pt tall.
- **Type:** `button-prominent` is semibold.
- **Color:**
  - `button-prominent` (accent fill, on-accent text) for one primary action per context
  - `button-bordered` (tertiary fill, accent text) for secondary actions
  - plain accent text for tertiary actions, which honors Button Shapes
  - destructive text in `{colors.negative}`
- **States/Notes:** a disabled button uses `{colors.secondary-label}`; a disabled prominent button
  becomes a hairline outline.

### Sheet bar buttons
- **Token:** system.
- **Container:** on iOS 26+, cancel sits in a glass circle and confirm in an accent-filled glass
  circle. iOS 18 uses the words **Cancel**, **Add**, **Save** and **Done**.
- **Glyphs:** `xmark` (cancel) and `checkmark` (confirm) on iOS 26+.

### Permission banner
- **Token:** `permission-banner`.
- **Container:** the full form is `{colors.cell}`, `{rounded.card}`, with a 2 pt border, an icon, a
  bold lead sentence, and **Open Settings** and **Got It**. The collapsed form is a one-line row
  with the icon and the lead sentence.
- **Color:** the border is negative for notifications off, warning otherwise.

### Quiet-hours chip
- **Token:** `quiet-chip`.
- **Container:** a capsule.
- **Type:** `{typography.footnote}`.
- **Color:** `{colors.quiet}`.
- **Glyphs:** `moon.fill`, and a trailing `chevron.right` because it's a button.

### Status message
- **Token:** `status-message`.
- **Container:** a capsule in the content flow at the top of the screen.
- **Type:** `{typography.subhead}`.
- **States/Notes:** an optional plain **Undo** in accent.

### Markers
- **Token:** none. Uses the color and type tokens below.
- **Container:** a label followed by a hairline.
- **Type:** `{typography.footnote}` semibold.
- **Color:** "Now, 8:20 AM" in `{colors.label}`; quiet hours in `{colors.quiet}`.

### Settings row
- **Token:** none. Uses the color and type tokens below.
- **Container:** an icon tile, a label, and a trailing status in `{colors.secondary-label}` or a
  chevron.
- **Type:** the label in `{typography.body}`.
- **Color:** icon tiles by row:

  | Tile | Settings rows |
  |---|---|
  | `{colors.tile-red}` | Notifications, Delete All Data |
  | `{colors.tile-orange}` | Alarms |
  | `{colors.tile-gray}` | Open iOS Settings, Version |
  | `{colors.tile-blue}` | Send a Test Nudge, Export Data, Accessibility, How Nudges Work |
  | `{colors.tile-purple}` | Siri & Shortcuts |

### Tag tile
- **Token:** none. Uses the color and type tokens below.
- **Container:** a round gray tile.
- **Glyphs:** `tag`.
- **States/Notes:** decorative.

### Confirmation
- **Token:** system. Drawn by the system as-is.

### Alert
- **Token:** system. Drawn by the system as-is.

### Swipe actions
- **Token:** `swipe-done`, `swipe-snooze`.
- **Color:** green for Done, teal for Snooze, with white glyphs and words.
- **Glyphs:** `checkmark` (Done), `clock` (Snooze).
- **States/Notes:** Done is trailing and Snooze leading. Each always shows both its glyph and its
  word.

### Alarm
- **Token:** `alarm-tint`.
- **Container:** iOS draws everything except the title, the **Snooze N min** button and the tint,
  which the app supplies.
- **Color:** the Snooze button is filled with `alarm-tint.snooze-fill`.
- **Glyphs:** `clock` on Snooze.
- **States/Notes:** behavior: [EXPERIENCE.md › Nudge Surfaces](EXPERIENCE.md#nudge-surfaces).

### Live Activity
- **Token:** none. Uses the color and type tokens below.
- **Container:** Lock Screen material.
- **Type:** the title in `{typography.headline}`, up to 2 lines. The countdown in large monospaced
  digits. The "Snoozed. Rings again at…" line in `{typography.subhead}`.
- **States/Notes:** **Done** as a prominent button. Behavior:
  [EXPERIENCE.md › Nudge Surfaces](EXPERIENCE.md#nudge-surfaces).

### Assistive Access
- **Token:** system.
- **Container:** large cards with 64 pt **Done**, **Snooze** and **Not done yet** buttons, in the
  system's Assistive Access style on iOS 26+.
- **States/Notes:** behavior: [EXPERIENCE.md › Assistive Access](EXPERIENCE.md#assistive-access).

## Do's and Don'ts

| Do | Don't |
|---|---|
| Use Lagoon only for things you can tap | Use the accent for status, decoration, headers or backgrounds |
| Give every status a word, and urgency a word and a glyph, as well as a color | Show a state by color, icon or position alone |
| Let urgency (neutral → orange → red) be the only color on a nudge card | Color tags, strengths or categories |
| Give Done buttons a shape, and the Done status a glyph | Draw two different "Done"s as bare text that differ only in hue |
| Honor Button Shapes for plain text buttons | Rely on teal versus gray to show that something can be tapped |
| Use system components, materials and SF Symbols, and let each iOS version draw its own chrome | Draw custom tab bars, bars, sheets or alerts, or force Liquid Glass onto iOS 18 |
| Fill one primary action per context | Fill every Done in a list |
| Keep the personality in the name and the character icon | Put mascots, illustrations, confetti or jokes in the app's screens |
| Use text styles and let them grow to AX5, stacking layouts | Use fixed font sizes, truncate with "…", or shrink text to fit |
| Keep red for "needs you now" | Use red or orange in the app icon, onboarding or decoration |
