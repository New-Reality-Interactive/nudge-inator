# Nudge-inator iOS mockup: tone preview footer

A change mockup for `enhancement-alarm-sound` (spec #129), ticket #229: the alarm sound picker's
footer gains a line saying a choice plays its sound and why Default Alarm plays nothing. Copied from
the [alarm sound mockup](../2026-11-18-alarm-sound/README.md), with only this added, so the two can
be compared screen by screen. The 1.5.0 version mockup takes it in and replaces it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**Alarm sound (#223)** group jumps to both picker pages: **The picker, from the form** and
**Settings › Default Alarm Sound**.

## What changed since the alarm sound mockup

- **The picker's footer, on both its pages:** a second line, under "Plays when a nudge arrives as an
  alarm. Other nudges use the standard notification sound.": "Choosing a sound plays it. Default
  Alarm is iOS's own sound, which apps can't play, so you'll hear it when an alarm rings." On
  Settings' Default Alarm Sound page it comes before that page's own line on new reminders. The
  reminder form's Sound row keeps its one-line footer.
- **The preview (panel note only):** choosing a tone plays the whole tone, as the Clock app does, on
  silent too, until it ends, another sound is chosen or the page closes. Default Alarm plays none.

Nothing else changed.
