# Nudge-inator iOS mockup: Tutorials and How Alarm Sounds Work

A change mockup for `enhancement-alarm-sound` (spec #129), ticket #465: Settings gains a Tutorials
section, and its third row opens a new one-page tutorial, How Alarm Sounds Work. Copied from the
[details tone and Use for All mockup](../2026-11-19-details-tone-use-for-all/README.md), with only
this added, so the two can be compared screen by screen. Tickets #466 and #467 build to it. The
1.5.0 version mockup takes it in and replaces it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**Tutorials (#465)** group jumps to each state; everything also works by tapping.

## What changed since the details tone and Use for All mockup

- **Settings › Tutorials:** a new section, the last above Your Data: How It Nudges, How Sharing
  Works, How Alarm Sounds Work, in the order the features shipped. Every row is in the tint
  color, as How Sharing Works was in Sharing, with its feature's symbol on a gray tile: `bell`,
  `person.2` and `speaker.wave.2`. Each opens what it opened before: How It Nudges and How Alarm
  Sounds Work push a page (a chevron), How Sharing Works presents its sheet (no chevron). No
  footer.
- **Sharing and Nudges:** How Sharing Works has left Sharing, and How It Nudges has left Nudges.
  Their footers are unchanged. How Sharing Works still opens by itself the first time Sharing is
  turned on.
- **How Alarm Sounds Work:** one page, pushed from its row, that never opens by itself. Five points
  laid out as How It Nudges' are, each naming the rows as the screens do:
  - **Pick a default sound** (`speaker.wave.2`): Settings' Default Alarm Sound, Default Alarm and
    the six tones, that tapping a tone plays it, and that new and received reminders start with it.
  - **Give it to every reminder** (`square.stack`): a new default leaves existing reminders alone;
    Use for All Reminders gives it to all of them.
  - **Choose one for a reminder** (`pencil`): the form's Sound row, under Break Through Focus,
    editable while the reminder is nudging.
  - **See which sound it has** (`eye`): the details page names it, under Break Through Focus.
  - **Only alarms play it** (`alarm`): only a nudge that rings as an alarm plays the sound (a Firm
    reminder's Urgent nudges with Break Through Focus on, and every Relentless nudge); Gentle
    never rings, so it has no Sound row.

  Its footer: "Other nudges use the standard notification sound, and so does every nudge while
  Alarms are off in iOS Settings."
- **How It Nudges:** the alarms point gains #459's line, already in the app: "Choose the sound
  alarms ring with in Settings, under Default Alarm Sound, and for each reminder, under Sound on
  its form." Onboarding doesn't show it.
- **Points' icon column:** it no longer narrows when a point's text is long, so every point's text
  starts at the same edge, as the app's minimum width keeps it. This moves How It Nudges' and
  onboarding's text a few points right.
- `scripts/mockup-shots.py` has the screens this adds: `settings-tutorials` and
  `settings-how-alarm-sounds-work`.

Nothing else changed.
