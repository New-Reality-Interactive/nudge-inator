# Nudge-inator iOS mockup: Reminders with a Search button

The change mockup for #113: the [no chips mockup](../2026-11-01-no-chips/README.md) with search moved
from a field always under the title to a button in the bar, because on iOS 27 the first visit to the
tab drew a collapsed title beside that field (an 11-line test app does the same). It is copied from
that change mockup, not from 1.2.0, because 1.2.0 has no Reminders tab. Once Brian signs it off on
#113, the bar and search are checked against it. The release's `1.3.0` mockup takes it in and deletes
it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed since the no chips mockup

- **The bar:** Filter, Sort and Search share one glass group, and New stands apart. That's iOS 27;
  iOS 26 pins iOS's own Search button to the end, so there it's Filter and Sort, then New, then
  Search. Brian's call: a known difference rather than a custom button, which couldn't open iOS's
  search. With no reminders the bar has only New, as before.
- **At rest** there's no search field, and the large title shows on every visit.
- **Search** opens the field in place of the whole button row, with the keyboard. The large title
  stays where it is. In landscape, where there's no large title, the mockup draws the field alone.
- **During a search the button row is gone:** Filter, its badge, Sort and New come back when search
  closes. This replaces the no chips mockup's bar that stays.
- **Close** (the field's `xmark`) ends the search and clears its text. The `xmark.circle.fill` inside
  the field clears only the text, and Clear Search and Filters also ends the search.
- `scripts/mockup-shots.py`: `reminders-search-open` is new.

Nothing else changed. The earlier mockups' choices, known differences and screens stand. The sheet
still draws Due Date, which #114 builds.
