# Nudge-inator iOS mockup: Reminders tab

The change mockup for the `reminders-tab` feature (spec #104, ticket #107): the [1.2.0
mockup](../1.2.0/README.md) with a fifth tab, **Reminders**, that lists every reminder in any
state. Once Brian signs it off on #107, the feature's UI tickets are checked against it. The
release's `1.3.0` mockup takes it in and deletes it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed since 1.2.0

- **A fifth tab, Reminders** (`list.bullet.clipboard`), between My Day and Tags. The Now badge
  stays on Now. Landscape fits all five tabs, with their titles beside their symbols.
- **The Reminders list:** every reminder once, sorted by creation date (oldest first). Each row
  shows its due time, title, tags and status label, and no notes. A row's status is the details
  page's hero status: Nudging, Coming up, Paused, Done, Missed or Skipped. Its due time is the open
  occurrence's while Nudging, otherwise the next one, otherwise the latest occurrence's. A Paused
  row shows the due time it would be Skipped at.
- **Search** under the navigation bar: titles and notes, ignoring case and diacritics, the trimmed
  text as one phrase. Cancel shows while the field is focused or has text, and Clear
  (`xmark.circle.fill`) once there's text, as the system draws them.
- **The header row**, above the rows: the count, always the reminders shown out of every reminder
  ("3 reminders out of 14", and "14 reminders out of 14" with nothing narrowing the list, so it
  never reads as all of them; Brian's call at sign-off), then the sort toggle and the
  Nudging, Due Today and Missed chips. It wraps at the default sizes and stacks at the
  accessibility sizes.
- **The sort toggle:** the custom symbols `calendar.arrow.up` (oldest first) and
  `calendar.arrow.down` (newest first), each made from `calendar` with an arrow in a cutout at the
  lower right, as `tag.filter` is made from `tag`. VoiceOver reads "Sort by Created" and the direction.
- **The chips:** a 44 pt capsule each, accent text on the tertiary fill when off, and the accent fill
  with a `checkmark` when on. Only one is on at a time; a second tap turns it off. Applying a
  Status that lights Nudging or Missed turns Due Today off, as one chip at a time requires.
- **The Filter button** (`line.3.horizontal.decrease`) beside New. Its badge counts the filter
  sheet's sections in use (Tags, Status, Strength, Due Date). A Status that a lit chip already shows
  doesn't count, and neither do search or Due Today. While any sheet filter is on, a lit chip's
  Status included, a tap shows a menu: **Filter** (`line.3.horizontal.decrease`) and **Clear All
  Filters** (`xmark`). With none, a tap opens the sheet. There's no badge at the accessibility
  sizes.
- **The filter sheet, "Filter Reminders":** Match and Tags with No Tags (as My Day's), Status (six,
  several allowed), Strength (three, several allowed) and Due Date (From and To, each a switch and
  a date pill that can't pass the other end). Its footer says how many reminders Apply shows,
  with the search and chip as they are. **Reset**
  clears the draft, **Apply** applies it and closes, and tapping above the sheet (swiping it down on
  the iPhone) closes it without applying.
- **Swipe left** on a row: Done (`swipe-done`) at the edge and Delete (red tile, `trash`) beside it
  on a Nudging row, Delete only on any other row. There's no full swipe and nothing on the right.
  Delete asks first, in the details page's words.
- **After Done** the row keeps its place and its status label changes. Under a status filter that
  now leaves it out (the Nudging chip, say), it fades and closes up, and the count drops.
- **Two empty states.** "No Reminders Yet", with New Reminder, only when there are none. "No
  Results for “…”" or "No Matches" when search or filters match nothing. That state names what's
  narrowing the list ("No Nudging reminders match this search.") and offers Clear Search, Clear
  Filters or Clear Search and Filters. The header row stays, so a chip can be turned off there.
  The app ships each of these sentences as one whole string, not built from pieces
  (CODING_STANDARDS.md); the mockup builds them only to draw every combination.
- **New** opens the New Reminder form. The new reminder shows where its creation date puts it,
  even if search or filters would hide it, until they next change.
- **Data:** every reminder has a creation date (`createdAt`). Two new reminders have nothing more
  coming: "Book the car service" (Missed) and "Physio exercises" (a repeat that ended on a Skipped
  occurrence).
- **Details:** the hero status is now worked out by the same function as the Reminders rows
  (`remStatus`). It looks as it did.
- **Menus with symbols:** an action sheet can be a menu whose items lead with a symbol. This was
  copied from the [template](../2026-10-26-mockup-template/README.md) (enhancement-pace ticket 20),
  which the 1.2.0 mockup lacks.
- **Mockup controls:** a "Reminders tab" group. It can show the swipe on a Nudging row and on a
  Coming up row, turn the Nudging chip on with a row's swipe showing (tap Done to see the row
  leave), and remove every reminder to show the first empty state.
- `scripts/mockup-shots.py` has the screens `reminders`, `reminders-newest`, the three
  `reminders-chip-*`, `reminders-search`, `reminders-filter`, `reminders-filter-chosen`,
  `reminders-filter-badge`, `reminders-filter-menu`, `reminders-swipe-nudging`,
  `reminders-swipe-other`, `reminders-delete`, `reminders-after-done`, `reminders-empty`, the three
  `reminders-no-match-*` and `reminders-new`.

Nothing on Now, My Day, Tags or Settings changed.

## Choices the spec left open

Brian decides these at sign-off. Each is drawn as described.

1. **Search under the navigation bar, not in the toolbar.** This departs from the spec's "A search
   field in the Reminders toolbar". The field always shows under the large title
   (`navigationBarDrawer(displayMode: .always)`). Apple's docs prefer search in a bottom toolbar,
   but under a five-tab bar this tab has no bottom toolbar, and the spec calls placement a
   preference to check on the simulators. If it's signed off, the spec's line changes to match.
2. **Done at the edge, Delete inside it,** as Done sits alone at the edge on Now and My Day.
3. **The header row sits above the rows,** like a section header, not inside the first row's
   white cell.
4. **The filter sheet's bar is Reset and Apply,** as My Day's sheet is Clear and Done. The
   sheet closes without applying when swiped down.
5. **New still opens the new reminder's details after Add,** as on Now and My Day; Back shows it in
   the list.

## Known differences

- **My Day's Filter menu, "+N more" token and summary line** (enhancement-pace ticket 20) are in
  the app and the template, but not in the 1.2.0 mockup. This mockup changes only the Reminders tab,
  so My Day is drawn as in 1.2.0, and `scripts/mockup-shots.py`'s `myday-filter-menu` screen still
  fails here as it does on 1.2.0.
- **The search prompt at AX5** is cut off. The system draws the field, so how far its text scales
  is a simulator check.
- **Date pickers** open the browser's own picker; on the iPhone the pill opens iOS's.
- **VoiceOver actions:** the rows' Done and Delete are VoiceOver actions in the app. Here they are
  visually hidden buttons after each row.
- **Scroll position** isn't kept when going back from a reminder's details, as elsewhere in the
  mockup; the app keeps it.
- **Largest text:** a checked row's checkmark wraps under its title, as in the 1.2.0 mockup.
