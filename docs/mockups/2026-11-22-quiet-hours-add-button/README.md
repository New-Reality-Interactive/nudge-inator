# Nudge-inator iOS mockup: Quiet Hours Add Schedule button (#498)

A change mockup for quiet-hours-and-shortcuts (spec #338): a copy of the
[Quiet Hours schedule switch mockup](../2026-11-22-quiet-hours-schedule-switch/README.md) with
Add Schedule moved to the bar, and nothing else changed. It is deleted when the 1.6.0 version
mockup takes the change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**Quiet Hours page (#370, #371)** group jumps to each state; **Add Schedule** opens the sheet.

## What changed since the schedule switch mockup

- **Add Schedule is a + in the navigation bar's top right**, labeled Add Schedule for VoiceOver, as
  the Tags tab's New Tag. It opens the same sheet as before. The page has no Add Schedule row.
- **The empty state has no button.** "No Schedules" reads "Tap + to add a schedule, and no nudge
  arrives while it runs.", as the Tags tab's empty state points at its +. The developer asked for
  it in #498's phone check (2026-11-22), after the in-list button drew as a tall pill.
- **What quiet hours do moves into the Schedules footer**, after "Turn a schedule off to keep it
  for later.", since the section it sat under is gone.
