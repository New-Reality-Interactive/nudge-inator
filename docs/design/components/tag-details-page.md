# Tag details page

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

Pushed on the Tags tab from a tag's row, as a reminder's details page is from Reminders (#376). The
mockup is `docs/mockups/2026-11-23-tag-details/`.
- **Bar:** Back, and Edit at the trailing end, as on a reminder's details, with an empty inline title; the
  hero carries the name. Edit's VoiceOver label names the tag ("Edit #home") and it opens the Rename Tag
  sheet, unchanged; the page shows the new name when it closes.
- **Hero:** a card with the tag's tile (a round `{colors.tile-gray}` tile with `tag`, 56 pt at the default
  size and scaling with the text) beside the name in `{typography.title2}` bold and, under it, the counts line
  a row shows ("3 reminders · 2 today · 1 nudging", the nudging part in `{colors.negative}`), read from the
  same summary so the page and the list agree. At accessibility sizes the tile sits above the text.
- **Reminders row:** a row with `list.bullet.clipboard` before the word, both in `{colors.accent}` as Pause Reminder is on a reminder's details (at accessibility sizes the glyph sits above the word, so it doesn't break mid-word), and a gray chevron, which opens the tag's reminders page, which is unchanged
  (its sections, count header, + that starts a reminder with the tag chosen, and Tag Deleted state). The page has
  its own destination, so the row and, later, the row's swipe both open it; Back returns to whichever did.
- **Tag Deleted:** both of a tag's pages show `tag.slash`, "Tag Deleted" and "This tag was deleted. Its
  reminders are still there." when the tag goes while the page is open.
- **Delete Tag:** a destructive row with `trash` in a section of its own, below Reminders, as Delete Reminder
  is on a reminder's details. It asks the Tags row's question (the tag as its title, how many reminders use it
  and that they stay) and, once confirmed, deletes the tag and goes back to the list.
- **Read again** at every change and every minute.
