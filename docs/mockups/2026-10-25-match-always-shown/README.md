# Nudge-inator iOS mockup: Match always shown

My Day's filter sheet with the Match choice always shown, as proposed in enhancement-pace
[ticket 23](../../../.scratch/enhancement-pace/issues/23-match-selector-doesnt-shift-the-tags.md).
It's a copy of the [filter badge mockup](../2026-10-24-filter-badge/README.md) as ticket 20 left it,
changed only for the filter sheet, so the two can be compared screen by screen. Everything this
README doesn't list is as that mockup draws it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed

- **Match is always shown,** first in the sheet, above Tags, as the filter badge mockup shows it
  once two tags are checked. Before, it appeared only from two tags on, and checking the second
  tag pushed every tag row down while the person was still tapping.
- **Disabled below two tags:** with none or one tag checked, or No Tags checked (which unchecks
  the tags), Match is dimmed and keeps showing its current choice. From two tags on it works as
  before. At the accessibility sizes it is a menu, dimmed the same way. Clear still resets it to
  All Tags.
- **The Tags footer says why:** below two tags it reads "Check one or more tags. Match needs two or
  more." From two tags on it reads, as before, "All Tags shows reminders with every checked tag.
  Any Tag shows those with at least one." The footer sits below the rows, so its length doesn't
  move them.
- **Accessibility:** VoiceOver reads Match, its value and that it's dimmed below two tags; the
  app's check is a device check.
- `scripts/mockup-shots.py` takes `myday-filter-1` (one tag checked, Match disabled) and
  `myday-filter-2` (two tags, Match working), beside `myday-filter` (none checked).
