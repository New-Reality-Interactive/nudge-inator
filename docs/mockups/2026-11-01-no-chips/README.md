# Nudge-inator iOS mockup: Reminders with no chips

The change mockup for #113: the [header row mockup](../2026-11-01-header-row/README.md) with the
quick filter chips and Due Today gone (spec #104, Decision 36). It is copied from that change
mockup, not from 1.2.0, because 1.2.0 has no Reminders tab. Once Brian signs it off on #113, the
header row is checked against it. The release's `1.3.0` mockup takes it in and deletes it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed since the header row mockup

- **No chips:** Nudging, Due Today and Missed are gone. Nudging and Missed stay in the sheet's
  Status. A row always shows its own due time and status, since only Due Today showed today's.
- **The header row:** the count at the leading edge and the Sort button at the trailing edge, on
  one line, in portrait and landscape. At the accessibility sizes they stack, the Sort button on its
  own line, still at the trailing edge.
- **The Filter button:** every Status counts in the badge, and any sheet filter makes a tap show the
  menu. There is no lit chip to except.
- **The no-match empty state:** "No reminders with these filters." under No Matches, and "No
  reminders with these filters match this search." under No Results, with Clear Filters or Clear
  Search and Filters. Search alone reads as before.
- **A new reminder** shows only if it matches, as #112's device check changed it. The earlier
  mockups draw it pinned.
- **Mockup controls:** "Status of Nudging on, then show a row's swipe" replaces the chip's. "During
  a search, with filters on" shows the two choices below.
- `scripts/mockup-shots.py`: `reminders-status-nudging`, `reminders-status-missed` and
  `reminders-no-match-status` replace the chip screens, which only earlier mockups could draw.

Nothing else changed. The earlier mockups' choices, known differences and screens stand. The sheet
still draws Due Date, which #114 builds.

## The choice for sign-off

While a search is active the system hides the bar, so the Filter button and its badge aren't on
screen, and nothing else says filters are on (#112's Comments). Choose with the control:

- **A: the bar stays.** `searchPresentationToolbarBehavior(.avoidHidingContent)` asks the system not
  to hide the bar's content, so the Filter button and its badge stay, and New with them. This is
  what every Reminders mockup has drawn. Apple's docs confirm the modifier, not which items it keeps,
  so it is a simulator check on both simulators.
- **B: the bar goes, and a line says so.** The system's behaviour stays, and "2 filters on" shows
  under the count during a search with filters on. It adds a string and a line to the header row.
