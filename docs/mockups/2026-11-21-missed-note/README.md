# Nudge-inator iOS mockup: Missed note (#369)

A change mockup for quiet-hours-and-shortcuts (spec #338): a copy of the [1.5.0 mockup](../1.5.0/README.md)
with the Missed note added, and nothing else changed. It is deleted when the 1.6.0 version mockup
takes the change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**Missed note (#369)** group jumps to each screen; everything also works by tapping.

## What changed since 1.5.0

- **The Missed note.** An occurrence that closed as Missed, and that quiet hours held a nudge of,
  gets a line under how it closed: "Quiet hours held 10 of its 20 nudges." The count is the
  occurrence's nudges that fell in quiet hours, each read under the schedules in force when it was
  due; the total is all of its nudges, held or sent. It shows wherever that Missed shows: Now's
  Last 24 Hours, its My Day row and the reminder's Last occurrence row. Done, Skipped, and Missed
  with nothing held have no note.
- **Made-up data:** quiet hours are 10 PM to 7 AM, every day. Feed the cat (Relentless, daily at
  6:30 AM) went Missed today at 7:22 AM after 20 nudges, the first 10 held. Stretch break's Missed
  yesterday held none, so it shows no note.
- `scripts/mockup-shots.py` has the screens this adds.
