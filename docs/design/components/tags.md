# Tags

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

- **Tag token field / tag token:** `tag-token`, system-drawn. **Tag tile:** a round gray tile with `tag`,
  decorative.
- **Filter token:** `filter-token`, a 44 pt capsule with `xmark`. On My Day the tokens wrap to at
  most three rows; the rest go into a **+N more** token in the same capsule, which opens the filter
  sheet. If it doesn't fit beside the third row's only token, it takes a row of its own, so three
  tags still show. Under them a summary line says how the tags combine without naming them: "Due
  today with the selected tag" for one, "…all selected tags" or "…any selected tags" from two on,
  "Due today with no tags" for No Tags. A **From others** token follows on a row of its own after the
  tags', so it never goes into +N more, and shares the row after No Tags, as the mockup's (ticket
  209). The summary line says nothing of it. **Filter button:** `line.3.horizontal.decrease` in the bar, as on Reminders and Tags now that it filters by more than tags (ticket 209), a glass circle of its own with New
  Reminder apart from it (a fixed toolbar spacer, as on Reminders and Tags). It shows only while a
  reminder is due today and at least one tag exists or someone has sent a reminder: with neither the
  sheet would offer only No Tags, which matches every row. When it goes, the tag filter clears (the chosen count stays), so a
  filter nobody can see doesn't narrow the list when reminders or tags come back (spec #104,
  Decision 56). While any tag (or No Tags, or From others) is chosen a tap
  shows a menu, in the Reminders tab's words: Filter (`line.3.horizontal.decrease`) opens the filter sheet, Clear
  All Filters (`xmark`) removes every tag, No Tags and From others at once. The button's
  VoiceOver label is Filter. With none chosen a tap opens the sheet. No long press: at the
  accessibility sizes the bar uses it for the Large Content Viewer.
  **Match control:** system segmented `Picker`, a menu at accessibility sizes. Always shown, first
  in the filter sheet above Tags, so checking a tag never moves the rows. Disabled below two
  checked tags and with No Tags, keeping its current choice; the Tags footer then says "Check one
  or more tags. Match needs two or more." Under No Tags, once someone has sent this person a
  reminder (or while it's on), a **From** section holds **From others**, "Only reminders someone
  sent you", which shows only received reminders. A person with no received reminders sees the
  sheet without it. **The sheet** is the Reminders and Tags tabs' filter sheet (ticket 209, the
  2026-11-12-history-nothing-due mockup): it chooses a draft, and My Day doesn't change until
  Apply, the checkmark, which applies it and closes. Above **Reset**, at the bottom, "Apply shows N
  reminders due today."; Reset clears the draft. The X discards the draft, asking first once it
  differs from what's applied, and a swipe down then springs back. While the sheet is open its list
  never gets shorter: blank space under Reset makes up for text that shortens, so a list scrolled to
  its end doesn't scroll back and move the rows.
