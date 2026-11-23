# Nudge-inator iOS mockup: Quiet hours banner (#499)

A change mockup for quiet-hours-and-shortcuts (spec #338): a copy of the
[How Quiet Hours Work tutorial mockup](../2026-11-22-quiet-hours-tutorial/README.md) with the
holding banner added to Now, My Day and Reminders, and nothing else changed. It is deleted when the
1.6.0 version mockup takes the change in.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**Quiet Hours page (#370, #371)** group has the banner's states at the top.

## What changed since the tutorial mockup

- **A banner under the date (Now, My Day) and under the Mine | Sent picker (Reminders)** while
  Quiet Now is on or a schedule that's on covers the time, the same test as Settings' On and Until.
  It sits after any permission banners, above the lists, counts and filters.
- **Words:** "Quiet hours are holding nudges" in bold, then "Until 9:00 AM." (the latest end when
  several schedules overlap, as Settings' Until reads) or "Until you turn it off." for Quiet Now,
  then "Change this in Settings, under Quiet Hours." (words only: a › would read as a tap target).
- **Look:** the permission banner's card, with a gray border and a `bell.slash` icon, since being held
  is the person's own choice, not a problem to fix (red and orange stay for what needs attention).
- **Not tappable** (the developer's call, 2026-11-22): it informs and names where to change it, so a
  tap never leaves the tab. VoiceOver reads it as one element, a note: "Quiet hours are holding
  nudges, until 9:00 AM. Change this in Settings, under Quiet Hours."
- **It goes** when quiet hours end; nothing shows otherwise.
