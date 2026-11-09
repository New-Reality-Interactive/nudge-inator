# Nudge-inator iOS mockup: 1.3.0

The app as built at 1.3.0 (`v1.3.0`): the [1.2.0 mockup](../1.2.0/README.md), then `reminders-tab`
(spec #104). Made in the release PR by merging two change mockups that both started from 1.2.0: the
Tags tab tools mockup (#138), which carries the Reminders tab and everything built on it, and the Custom
sheet mockup (#284), which carries the Repeat menu and End Repeat under it. It takes in and replaces
all eight change mockups of the feature. Frozen.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies.

## What changed since 1.2.0

- **A fifth tab, Reminders** (`list.bullet.clipboard`), between My Day and Tags: every reminder once,
  sorted by creation date, each row with its due time, title, tags and status (#107 to #116).
  - A header row with the count ("14 reminders out of 14").
  - **Search** under the title: titles and notes.
  - **Filter** (`line.3.horizontal.decrease`): a sheet for Tags, Status, Strength and a due date range,
    with a badge, a menu and Cancel, Apply and Reset.
  - **Sort** menu: Created (Oldest First, Newest First) and Due Date (Earliest First, Latest First).
  - **Swipe** a row: Done and Delete tiles on a Nudging row, Delete on the others. The tiles are circles with their word under them, as on the Tags tab, and the row is 78 pt tall. Delete asks first.
  - The bar holds Filter and Sort in one glass group, as on the Tags tab, and New apart from them. The quick filter chips the first mockup drew were removed (#113).
- **The New Tag and Rename Tag sheets ask before discarding** (#285): ✕ closes at once with nothing changed, and asks "Are you sure you want to discard these changes?" once a name is typed (New Tag) or changed (Rename Tag). Every discard question, here and on the reminder form and the filter sheets, shows its title (#278).
- **The Tags tab gets the same tools** (#138 to #142): a count header, search, Filter (Has no reminders),
  Sort (Name, Reminders), and a swipe to Edit or Delete a tag in place of Edit mode.
- **The Done swipe on Now's cards and My Day's Nudging rows is the same circle tile.**
- **The reminder form's Repeat is a menu** (#283): the presets, a divider, then Custom. Choosing Custom adds
  a row that reads the repeat out and opens the Custom repeat page, now **a sheet** with Apply only (#284).
- **End Repeat** is its own row under Repeat for every repeat: Never, After (a count) or On Date (#287).
- `scripts/mockup-shots.py` has the screens these add.

Nothing else changed. The 1.2.0 mockup's choices, known differences and screens stand, and the change
mockups' READMEs (deleted with this release) said the same of each step.

## How it was made, and what wasn't checked

Each change mockup was signed off on its ticket. This one is a three-way merge of two of them against the
1.2.0 mockup, with two lines resolved by hand (the title, and the sheet overlay, which takes the Custom
sheet's layering and the filter sheets' scrim marker). It was rendered in headless Chrome for the Reminders
tab and the End Repeat menu, and looked right.

It was **not** checked against the app with the screenshot walk: the developer dropped that step from the
release on 2026-11-08 (`docs/agents/release.md`). Where it and the app differ, the app is right.
