# Nudge-inator iOS mockup: Reminders with no chips

The change mockup for #113: the [header row mockup](../2026-11-01-header-row/README.md) with the
quick filter chips and Due Today gone (spec #104, Decision 36). It is copied from that change
mockup, not from 1.2.0, because 1.2.0 has no Reminders tab. Once Brian signs it off on #113, the
header row is checked against it. The release's `1.3.0` mockup takes it in and deletes it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed since the header row mockup

- **No chips:** Nudging, Due Today and Missed are gone. Nudging and Missed stay in the sheet's
  Status. A row always shows its own due time and status, since only Due Today showed today's.
- **The header row** holds only the count, on its own line in every size and orientation.
- **The Sort button is in the bar:** Filter, Sort, New, in that order, monochrome like New. Its menu
  is unchanged. It isn't there with no reminders, where the bar has only New. Brian's call at
  sign-off.
- **The Filter button:** every Status counts in the badge, and any sheet filter makes a tap show the
  menu. There is no lit chip to except.
- **The no-match empty state:** "No reminders with these filters." under No Matches, and "No
  reminders with these filters match this search." under No Results, with Clear Filters or Clear
  Search and Filters. Search alone reads as before.
- **A new reminder** shows only if it matches, as #112's device check changed it. The earlier
  mockups draw it pinned.
- **During a search the bar stays,** with Filter, its badge, Sort and New, as every Reminders mockup
  has drawn it: the app asks for it with `searchPresentationToolbarBehavior(.avoidHidingContent)`.
  Apple's docs confirm the modifier, not which items it keeps, so it is a simulator check on both
  simulators. Brian's call at sign-off.
- **Mockup controls:** "Status of Nudging on, then show a row's swipe" replaces the chip's.
- `scripts/mockup-shots.py`: `reminders-status-nudging`, `reminders-status-missed` and
  `reminders-no-match-status` replace the chip screens, which only earlier mockups could draw.

Nothing else changed. The earlier mockups' choices, known differences and screens stand. The sheet
still draws Due Date, which #114 builds.
