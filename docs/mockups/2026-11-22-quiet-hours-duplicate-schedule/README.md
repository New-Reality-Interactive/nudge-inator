# Nudge-inator iOS mockup: Quiet Hours duplicate schedule (#371)

A change mockup for quiet-hours-and-shortcuts (spec #338): a copy of the
[Quiet Hours schedule switch mockup](../2026-11-22-quiet-hours-schedule-switch/README.md) with a
schedule that copies another refused, and nothing else changed. It is deleted when the 1.6.0
version mockup takes the change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**Quiet Hours page (#370, #371)** group's **Same as another schedule: can't save** opens it, and so
does **Add Schedule**, since a new schedule starts as the made-up data's one.

## What changed since the Quiet Hours schedule switch mockup

- **A schedule can't copy another.** When the start, end and days are those of another schedule,
  whether either is on or off, Add or Save stays off and a red line under Starts and Ends, in
  place of the "Ends at" line, says "You already have a schedule with these times and days." It
  sits there, near the top, so it shows without scrolling in landscape and at large text; it's
  text on the sheet, not an alert, as the sheet's other reasons are. Editing a schedule never
  compares it with itself. The developer asked for it in #371's phone check (2026-11-22); copies a
  phone already holds are left as they are.
