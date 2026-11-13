# Nudge-inator iOS mockup: history, nothing due

The change mockup for a 7-day history day with nothing due (#207, spec #127, version 1.4.0), copied
from the [shared-reminders mockup](../2026-11-09-shared-reminders/README.md). It's deleted when the
1.4.0 version mockup takes the change in.

Open [`index.html`](index.html) in a browser, then Reminders › Sent.

## What changed since the shared-reminders mockup

- **A day with nothing due** (a weekly or weekday repeat's off day) shows a circle with a slash
  (`circle.slash`, "not applicable") in the secondary label color under its initial, instead of an
  empty cell, which read as a missing glyph on the phone.
- **Missed** is a red ✕ in a filled circle (`xmark.circle.fill`), matching Done's filled circle,
  instead of a bare ✕. Take your vitamins, sent to Maya, has one on Saturday: the
  mockup has no weekly sent reminder, so its daily one stands in.
- **Skipped** is a dashed circle (`circle.dashed`) in the secondary label color, instead of a
  minus.
- **Walk the dog**, a new daily reminder sent to Maya at 6:00 PM, shows today before its due time:
  today's cell is Coming up, a clock in the label color on the tertiary fill.
- **The details' "Maya, Last 7 Days"** give every day its strip glyph beside the word, as Done's
  check already was: Missed's ✕ in a circle, Skipped's dashed circle, Paused's pause, Coming up's clock,
  Nudging's bell, and "Nothing due" with the slashed circle, in the secondary label color. The Sent
  To rows' labels are unchanged.
