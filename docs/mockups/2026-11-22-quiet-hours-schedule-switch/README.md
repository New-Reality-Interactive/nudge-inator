# Nudge-inator iOS mockup: Quiet Hours schedule switch (#371)

A change mockup for quiet-hours-and-shortcuts (spec #338): a copy of the
[Quiet Hours page mockup](../2026-11-21-quiet-hours-page/README.md) with a Schedule switch added to
Edit Schedule, and nothing else changed. It is deleted when the 1.6.0 version mockup takes the
change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**Quiet Hours page (#370, #371)** group's **A schedule's sheet (Schedule switch)** opens it.

## What changed since the Quiet Hours page mockup

- **Edit Schedule's first row is a Schedule switch**, on while the schedule is on. It sits in a
  section of its own above Starts and Ends, with no heading. Turning it is an edit like the
  rest of the sheet: it's kept on Save, Cancel asks before discarding it, and the page's row
  shows the new state after Save. The developer asked for it in #371's phone check (2026-11-22).
- **Add Schedule has no switch**: a new schedule is always saved on.
