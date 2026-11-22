# Nudge-inator iOS mockup: How Quiet Hours Work tutorial (#468)

A change mockup for quiet-hours-and-shortcuts (spec #338): a copy of the
[Quiet Hours Add Schedule button mockup](../2026-11-22-quiet-hours-add-button/README.md) with the
How Quiet Hours Work tutorial added, and nothing else changed. It is deleted when the 1.6.0 version
mockup takes the change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**How Quiet Hours Work (#468)** group opens the tutorial, jumps to its last page, and resets it so
the next tap on Settings › Quiet Hours opens it by itself.

## What changed since the Add Schedule button mockup

- **Settings › Tutorials gains How Quiet Hours Work** as its last row, after How Alarm Sounds Work,
  with the Quiet Hours row's `bell.slash` symbol. It presents a paged sheet that works as How
  Sharing Works does.
- **Four pages**: Rest Without Nudges (what a schedule is), Quiet Now (the switch above the
  schedules), Your Schedules (tap +, tap a schedule, its switch), and Held Nudges (a held nudge
  counts as one you didn't answer, nothing arrives late, and the Missed note's wording).
- **It opens by itself once**, over the Quiet Hours page, the first time that page opens. Close or
  the last page's Done ends that for good.
