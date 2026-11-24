# Nudge-inator iOS mockup: the Tags swipe's List tile (#378)

A change mockup for quiet-hours-and-shortcuts (spec #338): a copy of the
[Tag details mockup](../2026-11-23-tag-details/README.md) with three changes: the word under the
swipe's teal tile, a glyph on the details page's Reminders row, and where that glyph sits at the
accessibility text sizes. It is deleted when the 1.6.0 version mockup takes the change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The Tags tab
is the fourth tab; swipe a tag row right to left.

## What changed

- **The teal tile's word is "List", not "Reminders".** On the iPhone the system widened all three
  tiles into ovals to fit "Reminders" (#378's phone check, 2026-11-23), where the other tiles are
  circles. "List" fits a circle, as Delete and Edit do. The tile is still teal (#04666B) with the
  white `list.bullet.clipboard`, still at the edge, and still opens the tag's reminders page.
- **VoiceOver's action is still "Reminders"**, since the spoken name has room for the full word.
- **The details page's Reminders row has the same `list.bullet.clipboard` glyph before the word**, and
  the glyph and the word are both in the accent teal, as Pause Reminder is on a reminder's details
  (the chevron stays gray). The row and the swipe's tile show the same picture for the same place.
- **At the accessibility text sizes the glyph sits on a line above the word**, as the tag's tile does
  above its name, so "Reminders" keeps the row's width instead of breaking mid-word (#378's phone
  check, at the largest size). Use the text size control (AX1 to AX5) to see it.
- Everything else is the Tag details mockup, unchanged.
