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
  # Swipe action tiles: Done green, Delete red and Edit blue (tile-red and tile-blue above).
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
  swipe-delete:
    background: '{colors.tile-red}'
  swipe-edit:
    background: '{colors.tile-blue}'
  alarm-tint:
    stop-open-tint: '{colors.accent-dark}'
---

# Nudge-inator design

This is the design contract for implementation stories. A story that draws UI cites a section here
and meets it. It was extracted from the 2026-10-03 design doc and pruned to the
[first-version spec](https://github.com/New-Reality-Interactive/nudge-inator/blob/tickets-archive/.scratch/first-version/spec.md). Vocabulary comes from
[GLOSSARY.md](../../GLOSSARY.md): say Done, Nudging, Missed, Strength and Urgency, not synonyms.

**Precedence.** This doc owns tokens and rules: colors, type, spacing, shapes, and "one color, one
meaning". The latest version mockup, such as the [1.2.0 mockup](../mockups/1.2.0/index.html),
owns how each screen is composed; a change's mockup (`docs/mockups/<YYYY-MM-dd>-<change>/`) is it
changed for a feature, and that feature's tickets build to it. If they disagree on a token value,
this doc wins and the mockup gets fixed.
If they disagree on a screen's layout, the mockup wins: the change's, for what it changes. The mockup's HTML still carries code from
the 2026-10-02 mockup (Snooze, quiet hours, Live Activity); anything the
[spec](https://github.com/New-Reality-Interactive/nudge-inator/blob/tickets-archive/.scratch/first-version/spec.md) puts out of scope is not a requirement.

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
  links, menus, checkmarks, the selected tab, tag and filter tokens, the chosen count's ring, the filled confirm button in each
  sheet and the Custom repeat sheet's Apply, and **Done** on nudge cards.
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
- **Badge (`{colors.badge}`)** is the Now tab's nudging count, My Day's Filter button's count of
  tags chosen (and one for From others), the Reminders Filter button's count of filter sheet sections in use, and the Tags
  Filter button's 1 while its filter is on, all as the
  system draws them (red; SwiftUI can't recolor a Filter button's, and the app doesn't bridge to
  UIKit for it). A count of 0 shows no badge, so it is never red. At the accessibility text sizes
  no Filter button has a badge: on iOS 27 the system draws it at the text size, so it covers
  the icon. My Day's chosen-tag tokens and each button's VoiceOver label carry the count there.
- **Tiles** are Apple's Increased Contrast light values in every mode with white glyphs. The swipe
  actions are `{colors.tile-green}` (Done), `{colors.tile-red}` (Delete) and `{colors.tile-blue}` (Edit). Settings rows: red (Notifications, Badges, Delete All Data), orange
  (Alarms), gray (About, Open iOS Settings, Default Pace, How It Nudges, and About's Privacy Policy
  and Support), blue (Send a Test Nudge). Tiles are icons for rows, not
  statuses, so "one color, one meaning" does not apply to them.

Rules:
- **Tags and strength have no color.** Tags are neutral, and chosen tags in a row are bold, not
  colored. Strength is its name plus a bars glyph.
- **A nudge card takes its color from urgency only:** neutral, warning or negative. The urgency word
  and glyph always come with the color.
- **Zero isn't a status.** A count of 0 uses `{colors.secondary-label}`, never red.
- **Fill sparingly.** Only primary actions get an accent fill: the sheet's confirm button (and the
  Custom repeat sheet's Apply), and the nudge card's Done. My Day's per-row Done buttons are bordered, so a long list isn't a column of
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
  regular variant. The content layer uses ordinary fills. The search field, which the 2026-10-03
  doc listed here as "the Search circle and field", is the system's, as `searchable` draws it in
  the place it's given (under the navigation bar on the Reminders tab).
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
- `{rounded.full}`: bar buttons, filter tokens, the strength badge,
  the nudge meter, small buttons.
- The search field's shape is set by the system. The 2026-10-03 doc gave the search bar
  `{rounded.control}`; the mockup draws iOS 26's capsule, a simulator check.
- `{rounded.token}` (7): tag tokens, drawn by the system.
- `{rounded.sheet}` (38): sheet tops, set by the system.

## Components

Each item gives, only where they apply: **Token** (frontmatter `components` key, or "system") ·
Container · Type · Color · Glyphs · Notes. System controls not listed (`Toggle`, `Picker`, `Stepper`,
text fields, confirmation dialogs, alerts) are used as the system draws them.

A question that confirms an action the person just tapped (discarding changes, deleting) is the
system's confirmation dialog with its title showing, as Apple's own apps ask (Calendar, seen on an
iPhone 15 with iOS 27.0.1). That includes the delete questions (#286): Delete Reminder, asked in
the same words from the details page and a Reminders row, and a tag's (its button reads Delete Tag,
as Delete Reminder does). iOS draws it as a
popover with the destructive button alone and no Cancel button (from the details page's button,
and, on the iOS 27.0 simulator, from a swipe tile too, which has no button to point at); where it
draws an action sheet instead, the dialog's cancel-role Cancel shows. Every question has a way to
close it that changes nothing: a Cancel button, or, for a popover, the system's own dismissal (a
tap outside it, or VoiceOver's "Dismiss popup"). An alert that only informs has OK (developer,
2026-11-07, #278). Button titles have no ending punctuation; a question's title ends in "?".

**Iconography.** SF Symbols in one weight matched to the adjacent text; they scale with Dynamic Type
except in the tab and navigation bars. Verify names against the mockup.

| Use | Symbols |
|---|---|
| Standard actions | `checkmark`, `xmark`, `trash`, `plus`, `magnifyingglass` and `xmark.circle.fill` (Search, drawn by the system), `tag.filter` (custom, in the asset catalog: the Tags tab's `tag` with a three-line filter badge at the lower right: My Day's Filter, the button and its menu item), `tag.xmark` (custom, in the asset catalog: the same `tag` with a × badge at the lower right: My Day's Clear All Filters, in the Filter button's menu), `line.3.horizontal.decrease` (the Filter button of the Reminders and Tags tabs and its Filter menu item, and the no-match state's image when only the sheet's filters narrow the list; `xmark` is its Clear All Filters) |
| Sort | `arrow.up.arrow.down` (the Reminders and Tags tabs' Sort buttons, which open the Sort menu) |
| Swipe | `pencil` (the Tags tab's Edit tile) |
| Tabs | `bell` (Now), `calendar` (My Day), `list.bullet.clipboard` (Reminders), `tag` (Tags), `gearshape` (Settings) |
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
  `button-bordered` **Done** on My Day. Chevron `chevron.forward` in `{colors.tertiary-label}`.
- **On the Reminders tab:** the due time (time over its day, as on Now's Coming Up), the title,
  the tags under it, and the status label trailing. No notes and no strength badge. Rows are
  separated as in every grouped list.

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
- **Filter token:** `filter-token`, a 44 pt capsule with `xmark`. On My Day the tokens wrap to at
  most three rows; the rest go into a **+N more** token in the same capsule, which opens the filter
  sheet. If it doesn't fit beside the third row's only token, it takes a row of its own, so three
  tags still show. Under them a summary line says how the tags combine without naming them: "Due
  today with the selected tag" for one, "…all selected tags" or "…any selected tags" from two on,
  "Due today with no tags" for No Tags. A **From others** token follows on a row of its own after the
  tags', so it never goes into +N more, and shares the row after No Tags, as the mockup's (ticket
  209). The summary line says nothing of it. **Filter button:** `tag.filter` in the bar, a glass circle of its own with New
  Reminder apart from it (a fixed toolbar spacer, as on Reminders and Tags). It shows only while a
  reminder is due today and at least one tag exists or someone has sent a reminder: with neither the
  sheet would offer only No Tags, which matches every row. When it goes, the tag filter clears (the chosen count stays), so a
  filter nobody can see doesn't narrow the list when reminders or tags come back (spec #104,
  Decision 56). While any tag (or No Tags, or From others) is chosen a tap
  shows a menu, in the Reminders tab's words: Filter (`tag.filter`) opens the filter sheet, Clear
  All Filters (`tag.xmark`) removes every tag, No Tags and From others at once. The button's
  VoiceOver label is Filter. With none chosen a tap opens the sheet. No long press: at the
  accessibility sizes the bar uses it for the Large Content Viewer.
  **Match control:** system segmented `Picker`, a menu at accessibility sizes. Always shown, first
  in the filter sheet above Tags, so checking a tag never moves the rows. Disabled below two
  checked tags and with No Tags, keeping its current choice; the Tags footer then says "Check one
  or more tags. Match needs two or more." Under No Tags, once someone has sent this person a
  reminder (or while it's on), a **From** section holds **From others**, "Only reminders someone
  sent you", which shows only received reminders; the count goes under it. A person with no
  received reminders sees the sheet without it. While the sheet is open its list never gets shorter:
  blank space under the summary makes up for text that shortens, so a list scrolled to its end
  doesn't scroll back and move the rows.

### Reminders tab
- **Search:** the system's search field (`searchable`), always shown under the navigation bar while
  there are reminders (the no-reminders empty state has none), with the prompt "Search titles and
  notes". The system draws its `magnifyingglass`, its clear button, and Cancel while it's focused
  or has text. Known difference, accepted (Brian, #113): on iOS 27.0
  the tab's first visit after a launch draws the title in its small inline form, with the list a
  little higher; a later visit draws the large title. The system does it to any field always under
  the title (an 11-line app too), and `toolbarTitleDisplayMode(.large)`, `defaultScrollAnchor(.top)`
  and a scroll to the header on appear didn't change it. A Search button in the bar was tried and
  dropped: its X took three presses on iOS 27.0 (the simulator and the iPhone) and one on iOS 26.5.
  A field that shows only on a pull down was dropped for being hidden.
- **Header row:** the first row of the list, above the rows' group, not in a cell. On its own line,
  in every size and orientation: the count in `{typography.subhead}` `{colors.secondary-label}`: the
  reminders shown out of every reminder, in every case, so a filtered list never reads as all of
  them ("3 reminders out of 14", "14 reminders out of 14"). One string with both numbers, one
  VoiceOver element.
- **Bar:** Filter, Sort, New, in that order; Filter and Sort share one glass group and New stands
  apart, split by a fixed `ToolbarSpacer`. With no reminders, only New. The bar stays during a
  search (`searchPresentationToolbarBehavior(.avoidHidingContent)`), so the Filter button's badge
  still says the sheet's filters are on.
- **Sort button:** `arrow.up.arrow.down` in the bar, monochrome like New. It opens the Sort menu: a
  section headed Created (Oldest First, Newest First) and one headed Due Date (Earliest First, Latest
  First), one choice checked across both, each choice a `Toggle` in a `Section` of a SwiftUI `Menu`,
  since the system drops the header of a section with a `Picker`. One tap applies a choice and closes
  the menu. Its label is "Sort" and its value the choice ("Created, Oldest First"), and VoiceOver
  reads each header, then its choices. Sorted by Due Date, a row keeps its place while search,
  filters and sort stay as they are, so Done doesn't move it; changing any of them, or leaving the
  tab, sorts again.
- **Filter button:** `line.3.horizontal.decrease` in the bar. Its badge counts how many of the filter
  sheet's sections are in use (Tags, Status, Strength, Due Date). Search doesn't count. While the
  count is above 0 the button takes the accent color and a tap shows a menu: Filter
  (`line.3.horizontal.decrease`) opens the sheet, Clear All Filters (`xmark`) removes every sheet
  filter and leaves the search. With none on, a tap opens the sheet. No long press, as on My Day.
- **Filter sheet ("Filter Reminders"):** Cancel (`xmark`, the form's cancel button) leading,
  Apply (the filled confirm button, `checkmark`) trailing, and Reset, a bordered button, at the bottom under the footer.
  With the draft unchanged, Cancel or swiping down closes it. Once it differs from what's applied,
  a swipe springs back and Cancel asks first, as the reminder form does: the system's
  confirmation dialog, "Are you sure you want to discard these changes?", as Calendar asks (#278). From the ✕ iOS draws it as a
  popover with Discard Changes alone; a tap outside it keeps the changes. A tap above the sheet does nothing either way: iOS draws a sheet's dimming
  view as noninteractive (spec #104, Decision 57).
  Match and Tags with No Tags as on My Day, then Status, Strength, From (From others, as on My Day,
  shown on the same terms) and Due Date. Status and
  Strength are checkmark lists. Due Date has From and To, each a switch with a date pill beside it
  while on. The footer counts what Apply would show.
- **Empty states:** `ContentUnavailableView`. With no reminders: `list.bullet.clipboard`, "No
  Reminders" and the line "Tap + to make one. Every reminder you make shows here, whatever its
  state." There is no button: New is in the bar (spec #104, Decision 62). When search or filters match nothing:
  `magnifyingglass` or `line.3.horizontal.decrease`, a title, a line naming what's narrowing the
  list, and a bordered Clear button. The header row stays above it.

### Tags tab
The Reminders tab's tools, in its layout, so they're learned once.
- **Search:** the system's search field, always shown under the large title while a tag exists, with the
  prompt "Search tags". It finds the tag's name only and ignores a leading `#`. The Reminders tab's
  known difference on iOS 27.0 applies.
- **Header row:** as on Reminders, in place of a "Your Tags" header: "9 tags out of 9", "1 tag out of 9".
- **Bar:** Filter and Sort share one glass group and New Tag stands apart, as on Reminders. There's no
  Edit button and there are no quick filter chips. With no tags, only New Tag. The bar stays during
  a search.
- **Sort button:** as on Reminders. Its menu has a section headed Name (A to Z, Z to A) and one headed
  Reminders (Most First, Fewest First). Ties on the count sort by name, A to Z, either way round.
- **Filter button:** as on Reminders, with a badge of 1 or none. Its menu is Filter and Clear All Filters.
- **Filter sheet ("Filter Tags"):** as on Reminders: Cancel, the confirm `checkmark` (VoiceOver name
  Apply), Reset at the bottom and the Discard Changes prompt. One row, Has no reminders, with the
  footer "Shows only tags that no reminder uses." and what Apply would show.
- **Rows:** the tag tile, name and counts, with content at least 48 pt tall for the swipe (Swipe
  actions). A tap opens the tag's reminders. A row that leaves, after a delete or when the filter
  excludes it, fades as its height closes up, and the count follows.
- **Help text:** static, not a dismissible tip, for a person new to tags. The list's footer, in
  `{typography.footnote}` and wrapping at large text and in landscape: "Tags are labels you add to
  reminders. Choose one to see every reminder that has it." The no-tags description: "Tags are labels, like #home or #errands, that you add
  to reminders so you can find them together. Tap + to make one, or add one when you create or edit
  a reminder."
- **Empty states:** `ContentUnavailableView`. With no tags: `tag`, "No Tags", the help text and no
  button, since + is in the bar. When search or the filter match nothing: `magnifyingglass` or
  `line.3.horizontal.decrease`, a title, a line naming what's narrowing the list and a bordered
  Clear button (Clear Search, Clear Filter, Clear Search and Filter), with no help text. The header
  row stays above it.

### Reminder form's Repeat
- The Repeat row sits under Starts and shows the current choice. A tap opens a
  pop-up menu, as in Apple's Reminders on iOS 27 (mockup `1.3.0`, #283): Never and the six
  presets in their order, a divider, then Custom, with a checkmark on the current choice. A choice is the
  form's repeat at once, held until the form's own Save like every other field; there is no Repeat page.
- **Custom row:** choosing Custom adds a row below Repeat with no "Custom" label, which Repeat already
  says. It writes the repeat out ("Every Monday at 9:00 AM") with a chevron and opens the Custom repeat
  sheet. Choosing a preset again removes it. It writes the repeat without its end, which End Repeat says
  (#287).
- **Locked while nudging:** the Repeat row and the Custom row are plain text with the `lock`, without the
  menu's or the link's affordance (no chevron), beside the form's lock note, as the form's other locked
  rows are.
- **VoiceOver:** the Repeat row reads its choice, and the menu reads each item with the current one selected.
  The Custom row reads the repeat, with the hint "Opens the custom repeat."
- **End Repeat** (mockup `1.3.0`, #287): under Repeat, and under the Custom row when there
  is one, whenever Repeat isn't Never. A pop-up menu of Never, After and On Date, drawn as the Repeat
  menu, with a checkmark on the current choice. After adds a stepper row, "After 10 times" (2 to 30); On
  Date adds an End Date row with a date button that opens a calendar no earlier than the start. The choice
  is the form's at once and is kept when the repeat changes; it goes back to Never only with Repeat. A
  preset with an end still shows as that preset in the Repeat menu. The footer under the section always
  says the whole repeat, end included ("Every Monday at 9:00 AM, 10 times."), for Never, the presets and
  Custom, and while locked; the Custom row and the Custom page's summary leave the end out. An end date before the start
  disables Save, with "The repeat ends before it starts. Change its end date." under Starts. The Custom
  sheet has no Ends section. Locked while nudging, End Repeat and its rows are plain text with the `lock`.
  VoiceOver reads End Repeat's choice, the stepper's count and End Date's date.
- **Custom repeat sheet** (mockup `1.3.0`, #284): a sheet over the reminder form, as in
  Apple's Reminders on iOS 27, titled "Custom": the summary sentence, Frequency with its Every stepper,
  On, and Next Times. Each change is the form's repeat as it's made, held until the form's own Save.
  **Apply** (✓, the accent-filled confirm button) is its only button: it closes the sheet and is never
  disabled, so the sheet can always close. A swipe down closes it too and keeps the changes. Nothing on
  it asks a question; the form's Cancel asks before discarding. Locked while nudging, its controls are
  disabled with the `lock`, under the form's lock note, and Apply still closes it. This follows Apple's
  app over the HIG's Sheets page, which pairs Done with Cancel and avoids a sheet over a sheet (#284).

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
  `{colors.negative}` when off) or a chevron. The Badges row is the exception: its status is
  `{colors.secondary-label}` even when off, since badges being off isn't a problem to flag (it
  says On, Off or Not Set; icon-badge #85). A row that opens a page to set a value shows the
  value under the label in `{typography.body}` `{colors.secondary-label}`, with the chevron
  (Default Pace: "Consistent · 10 min"), so it never shares the line with the label. A row that
  opens a web page (About's Privacy Policy and Support) has its label in the accent color and
  `arrow.up.forward` in place of the chevron, and VoiceOver reads it as a link. Tile colors are
  listed under Colors.

### Swipe actions
- **Token:** `swipe-done`, `swipe-delete`, `swipe-edit`. Trailing swipe shows Done: green tile, white
  `checkmark` and the word "Done". On the Reminders tab, Delete sits beside it: red tile, white
  `trash` and the word "Delete". Done is offered only while Nudging, at the edge; a row that isn't
  Nudging shows Delete alone. On the Tags tab, Edit is at the edge with Delete beside it: blue tile,
  white `pencil` and the word "Edit", which opens the rename sheet. Delete asks first. Nothing is on
  the leading edge, there's no full swipe (ADR 0001), and each tile always shows its glyph and its
  word. There is no Snooze.
- **Shape:** a tile is the same 50 pt circle on every screen, holding the white glyph, with the word
  under it in `{colors.secondary-label}` and the swiped row gray with rounded ends, all as the system
  draws them. The system draws the tile from the row's
  height: a circle on a row of at least 78 pt, a wider oval on a shorter one. Apple doesn't document
  this; it was measured on iOS 26.5 and 27.0 (#126). So a list row with a swipe has content at
  least 48 pt tall (`Design.Size.swipeRowContentHeight`), which makes 78 pt with the list's padding.
  This is why Reminders rows are taller than the 44 pt `{spacing.row-min}`.
- **Where each swipe appears:** a Nudging row offers Done as a trailing swipe on every screen it
  appears on (Now, My Day and Reminders), and Done means the same on each. Delete's swipe is on
  the Reminders and Tags tabs, where reminders and tags are managed, and Edit's is on Tags. Now and
  My Day are for acting on the day, so a destructive swipe never sits beside Done there. On those
  two screens a row that isn't Nudging (Coming up, Last 24 Hours, closed) has no swipe.
- **A swipe is a shortcut,** never the only way: Done is also the Done button on Now and My Day and
  on the details page, Delete is also on the details page, and VoiceOver gets both as the row's own
  actions. A new screen that adds swipes follows this section. **The exception is a tag:** its Edit
  and Delete are reachable by the swipe and by VoiceOver actions only, since the Tags tab has no Edit
  mode (spec #104, Decision 50).
- **VoiceOver after a delete:** iOS decides where it lands, and the app doesn't move it. After a tag's
  Delete it landed on a nearby row, the heading, New Tag or a row further away, and after the last tag
  on the bar's title, an empty-looking box one swipe from the visible title. Moving focus from code
  was tried on the iPhone: iOS moves it first as the question closes, so VoiceOver starts reading
  something else and then jumps, which Brian found worse (#139's Comments).

### Alarm
- **Token:** `alarm-tint`. iOS draws everything except the title, the secondary **Open** button and
  the tint. Tint is `{colors.accent-dark}`. Behavior: spec › Alarm presentation and ADR 0001.

### Shared reminders
What the shared reminders mockup (`docs/mockups/2026-11-09-shared-reminders/`, #183) adds. It rewrites
nothing above. Two items are exceptions to rules above, and name them: Disconnect's choice, and the
sharing paused and offline banner.

- **"From <name>" label:** on a received reminder, `person` then "From Maya" in `{typography.subhead}`
  `{colors.secondary-label}`, under the title on Now's cards and every list row. It has no color of its
  own: who sent a reminder isn't a status. Where the row has no strength badge (My Day, Reminders,
  Last 24 Hours) the strength badge follows the label. Details add the strength in words, as How It
  Nudges says it ("Relentless: rings an alarm until you mark it done").
- **Mine | Sent:** the system's segmented `Picker` under the search field (iOS keeps the search field
  in the navigation bar; #201), or under the title where there's no search field, filling the content
  width. Two short words, so it stays segmented at the accessibility sizes.
- **Segmented choices' capitalization:** the spec's words as written ("Start right away", "Ask me
  first"), which are glossary terms. `All Tags | Any Tag` keeps its title style.
- **Connection rows:** a round `{colors.tile-gray}` tile with `person`, the name in `{typography.body}`,
  a detail line in `{typography.subhead}` `{colors.secondary-label}` ("Connected", "Invited · Waiting
  for them to accept") and a chevron, under Connected and Invited headers. Settings' Connections row
  is a `{colors.tile-gray}` tile with `person.2`, in a section headed Sharing.
- **Sync states:** "Waiting to sync" with `clock`, in `{colors.secondary-label}`, on a Sent row's
  trailing label and on a received reminder's "From" line. It's a state, so it's never accent, warning
  or negative.
- **Status labels Sent and received rows add:** Waiting, Canceled, Removed and Delivered, all in
  `{colors.secondary-label}`, as Skipped and Paused are.
- **Sent rows:** as Reminders tab rows, due time then title, with a detail line ("Delivered", "Not
  sharing status", "Not sharing this one", "Waiting for them to accept", "Not delivered yet") and the
  status label trailing. There's no swipe. Group headers name the person and, trailing, whether they
  share status.
- **Sent's tools:** the Reminders tab's search field, count header, Filter and Sort in the same places.
  The filter sheet ("Filter Sent") has People, Status, Strength and Due Date, and Sort orders the
  reminders inside each person's group. Sent has no tags, and no tools in its empty states. The count
  is of reminders, so one sent to two people counts once.
- **7-day history:** on a repeating Sent row, under its text: today and the 7 days before, eight cells,
  oldest first, today on a `{colors.tertiary-fill}` cell, each with the day's initial and a glyph
  (#207's change mockup): `checkmark.circle.fill` Done (positive), `xmark.circle.fill` Missed
  (negative), `bell` Nudging (negative), `circle.dashed` Skipped (and Removed, which a day's report
  never holds), `pause` Paused, `clock` Coming up and `circle.slash` for a day with nothing due (a
  weekly repeat's off day), in the secondary label color, or `{colors.label}` on today's cell with its
  initial. The fill's rule is about text, and these are glyphs, so the status colors stay on it. Every
  glyph takes the box Done's does, so the initials line up. At the accessibility sizes the cells run
  four to a line. VoiceOver reads it as one element naming each day and status (the row's value,
  after its label: "Thursday: Done, …, Today: Coming up"). Details list the days newest first under
  "<first name>, Last 7 Days", each with its glyph beside its status word, as Done's status label has
  its check, or "Nothing due". It's hidden with status sharing off, "Not sharing this one", Waiting to
  sync and Waiting for them to accept. The status labels on the row and on Sent To keep their own look.
- **Waiting for You:** a section on Now between Nudging and Coming Up, each row with bordered small
  Accept and Remove (destructive text) buttons. It doesn't count toward the Now badge.
- **Notes on a received reminder:** a `{colors.cell}` card with `{rounded.control}` corners, `info.circle`
  or `clock` in `{colors.secondary-label}`, a semibold line and a detail line, which for a sender's change is one line per changed field ("Due
  time changed from 8:00 AM to 9:00 AM"; a notes change reads "Notes changed", with no text). No color:
  a change or a cancellation isn't "needs you now".
- **Disconnect's choice is a sheet, an exception to confirmation dialogs (Components):** a dialog can
  only list buttons, so it can't show Remove as the default. A checked list of the two options, then a
  bordered Disconnect in destructive text, with the form's Cancel. When the other person ended the
  connection the sheet has a prominent Continue and no Cancel, because the connection is already over
  and the choice has to be made: the one question without a way to close it that changes nothing.
- **Sharing paused and offline, an exception to Warning's meaning (Colors):** the `permission-banner`
  with `{colors.warning}`, `icloud.slash` or `wifi.slash`, on Connections, Send To and Sent only. It
  extends Warning from the alarms-off and Time Sensitive-off banners to these two, as the same kind of
  "something can't reach you" message. Nothing else in the app changes.
- **Sender-owned fields:** a received reminder's form shows the `lock` beside its reason ("Maya owns this
  reminder"), as a locked row does, though these fields aren't Locked in the glossary's sense.
- **Symbols added:** `person`, `person.2`, `person.badge.plus` (invites), `person.slash` (Disconnect),
  `icloud.slash`, `wifi.slash`, `minus`. Also used here: `pause` and `info.circle`.

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
(status message), History, Export Data, Siri & Shortcuts, Version row, Live Activity,
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
