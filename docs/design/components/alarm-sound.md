# Alarm sound

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

What the alarm sound mockup (`docs/mockups/2026-11-18-alarm-sound/`, #223) adds. It rewrites
nothing above.

- **Sound row:** on the reminder form, in the Break Through Focus section under the switch, a row
  in `{typography.body}` with the current tone's name trailing in `{colors.secondary-label}` and a
  chevron, as the Tags row. It opens the Sound page. It shows only while the reminder sends alarms
  (Relentless, or Firm with Break Through Focus on), and appears and goes at once as the switch or
  the strength changes. It's never locked: not while Nudging, and not on a received copy, whose other
  fields the sender owns. Neither a reminder being sent nor the sender's form for one they sent has
  one. The section's footer adds, under the switch's line: "Plays when a nudge arrives as an alarm.
  Other nudges use the standard notification sound."
- **The picker:** one inset grouped list for Settings and the form: Default Alarm (iOS's own alarm
  sound) first, then Chime, Bell, Pulse, Beacon, Rise and Siren. `checkmark` in the accent marks the
  current choice and stays on its sound's line at the accessibility sizes. A choice is saved at once
  and plays the whole tone, as the Clock app does (on silent too), until it ends, another sound is
  chosen or the page closes (none for Default Alarm); the page stays open. VoiceOver reads the list
  by its page's title, and each sound as a selectable row with its selected state. The footer is the
  Sound row's, in the same footer style on both pages; on Settings' page a second line says new and
  received reminders start with this sound and existing reminders keep theirs.
- **Settings' Default Alarm Sound:** a Settings row with a `{colors.tile-gray}` tile and
  `speaker.wave.2`, in Nudges right after Default Pace, showing the current tone's name as Default
  Pace shows its pace. It starts as Default Alarm, the list's first sound.
- **Symbols added:** `speaker.wave.2`.
