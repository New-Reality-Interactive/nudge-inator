# Nudge-inator iOS mockup: Quiet Hours page (#370, #371)

A change mockup for quiet-hours-and-shortcuts (spec #338): a copy of the
[Missed note mockup](../2026-11-21-missed-note/README.md) with the Quiet Hours page added, and
nothing else changed. It is deleted when the 1.6.0 version mockup takes the change in. Approved by
the developer on 2026-11-22.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**Quiet Hours page (#370, #371)** group jumps to each state; everything also works by tapping.

## What changed since the Missed note mockup

- **Settings › Nudges › Quiet Hours**, after Default Pace, on a gray `bell.slash` tile. It says
  whether nudges are held now and until when: **On** while Quiet Now is on; **Until 7:00 AM** while
  a schedule that's on covers this moment (the latest end when several do); **Starts 10:00 PM** for
  the next start of a schedule that's on, with its weekday when it isn't today (**Starts Fri
  11:00 PM**); **Off** with no schedule on (#370).
- **The Quiet Hours page.** Quiet Now, one switch that holds every nudge until it's turned off
  (built in #498, engine in #497). Then Schedules: each row a gray `clock` tile, the range
  ("10:00 PM–7:00 AM"), the days under it in smaller secondary text ("Every Sun, Mon, Tue, Wed, and
  Thu", "Every Fri and Sat", "Every day"), and a switch. A schedule that's off keeps its row, its
  words dimmed. While Quiet Now is on, a line under the schedules says they apply again when it's
  off; they aren't dimmed. Add Schedule follows, then a footer on what quiet hours do. With no
  schedules, an empty state, "No Schedules", under Quiet Now (#370).
- **Add Schedule and Edit Schedule** (#371): a sheet with Cancel and Add or Save. Starts and Ends are
  compact time pills, as the reminder form's Starts row; a line says when it ends ("Ends at
  7:00 AM the next day"). Days are a checklist, Sunday first as the list words them. A new schedule
  starts at 10:00 PM to 7:00 AM, every day, on. Save stays off while the start equals the end, or
  while no day is chosen, and a red line says why. Edit adds Delete Schedule, which asks first.
  Cancel with changes asks before discarding, as the other sheets do.
- **Made-up data:** one schedule, 10:00 PM to 7:00 AM every day, on, as the Missed note's data
  has it. The clock is fixed at Mon 8:20 AM, so the row reads Starts 10:00 PM.
- `scripts/mockup-shots.py` has the screens this adds.
