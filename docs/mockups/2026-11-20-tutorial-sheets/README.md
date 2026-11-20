# Nudge-inator iOS mockup: tutorial sheets

A change mockup for `enhancement-alarm-sound` (spec #129): every tutorial in Settings › Tutorials is a
paged sheet that works as How Sharing Works does. Copied from the
[Tutorials mockup](../2026-11-20-tutorials/README.md), with only this changed, so the two can be
compared screen by screen. It replaces that mockup's pushed How It Nudges and How Alarm Sounds Work
pages. Tickets #466 and #467 and a new ticket for How It Nudges build to it. The 1.5.0 version
mockup takes it in and replaces it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**Tutorials (#465)** group opens each sheet; everything also works by tapping.

## What changed since the Tutorials mockup

- **Settings › Tutorials:** every row presents a sheet, so none has a chevron. The rows keep the
  tint color and their feature's symbols (`bell`, `person.2`, `speaker.wave.2`).
- **Every tutorial is a paged sheet**, as How Sharing Works is: art, a heading, then rows or numbered
  steps; swipe or Back and Next top right; page dots under the pages; Close top left; the standard
  confirm checkmark (Done) on the last page. Only How Sharing Works opens by itself (the first time
  Sharing is turned on); How It Nudges and How Alarm Sounds Work never do.
- **How It Nudges, four pages** (the pushed page is gone):
  1. **What to Expect:** the welcome's four points as rows, with #459's line under the alarms
     point.
  2. to 4. **Gentle, Firm, Relentless:** the strength's line ("Never rings as an alarm."), then
     "At your Default Pace, <pace>, with Break Through Focus on." and its schedule and summary, as
     the page drew them. A long schedule scrolls within its page.
  The How It Nudges section on a reminder's details and form is unchanged.
- **How Alarm Sounds Work, three pages** (the one-page version is gone):
  1. **Pick Your Default Sound:** Settings › Default Alarm Sound; tapping a tone plays it; Default
     Alarm is iOS's own sound, which apps can't play; new and received reminders start with it,
     and existing ones keep theirs.
  2. **Change Your Reminders:** the art is one reminder and the sound it rings with ("Wake Up
     → Chime"; each pill keeps to one line, and its text stops growing at xxxLarge, since the art is
     decoration VoiceOver skips), then rows: Use for All Reminders,
     Sound on the form (even while nudging), and Named on its details. Footer: a received reminder
     rings with the sound chosen on this iPhone.
  3. **When It Plays:** only nudges that ring as alarms play it (a Firm reminder's Urgent nudges
     with Break Through Focus on, and every Relentless nudge); a Gentle reminder, or a Firm one with
     the switch off, never rings and has no Sound row; other nudges, and every nudge while Alarms
     are off, use the standard sound.
- `scripts/mockup-shots.py` has the screens this adds: `tutorial-how-it-nudges-p1` to `-p4` and
  `tutorial-how-alarm-sounds-work-p1` to `-p3`. `settings-how-it-nudges` and
  `settings-how-alarm-sounds-work` don't apply to this mockup, which has no such pages.

Nothing else changed.
