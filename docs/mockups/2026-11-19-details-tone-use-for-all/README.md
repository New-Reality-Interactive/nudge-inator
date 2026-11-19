# Nudge-inator iOS mockup: details tone and Use for All

A change mockup for `enhancement-alarm-sound` (spec #129), ticket #456: the reminder details page
names the reminder's alarm sound, and Settings' Default Alarm Sound page gains Use for All
Reminders. Copied from the [tone preview footer mockup](../2026-11-19-tone-preview-footer/README.md),
with only this added, so the two can be compared screen by screen. Tickets #457 and #458 build to
it. The 1.5.0 version mockup takes it in and replaces it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**Details tone and Use for All (#456)** group jumps to each state; everything also works by tapping.

## What changed since the tone preview footer mockup

- **Details, Sound row:** in Schedule, under Break Through Focus, a row naming the reminder's alarm
  sound (Default Alarm by name). It shows only while the reminder rings, as the form's Sound row
  does: Relentless, or Firm with Break Through Focus on. Gentle, or Firm with the switch off, has
  none, and so does a received copy its sender canceled, which never nudges. The row comes and goes
  as the switch is changed in Edit. It only names the sound, as Pace names the pace; Edit changes it.
- **Received details:** the same row, naming the sound chosen on this iPhone. While the copy rings,
  the schedule's footer adds "The sound is yours: it's chosen on this iPhone." and the footer under
  Remove Reminder reads "You can mark it Done, pause it, remove it, add your own tags and choose its
  alarm sound."
- **Settings › Default Alarm Sound, Use for All Reminders:** a section under the list with one tint
  row. Its footer: "Choosing a sound above leaves the reminders you already have as they are. This
  gives every one of them <sound>, including reminders someone sent you." The list's footer keeps
  "New reminders, and reminders someone sends you, start with this sound." and drops "Reminders you
  already have keep theirs.", which the new footer now says. When every reminder already has the
  default, the row is dimmed and its footer reads "Every reminder you have uses <sound>."
- **Its confirmation:** the system's confirmation dialog, from the row: "Use <sound> for All
  Reminders?", "<n> reminders, including ones people sent you, will use <sound>." (or "1 reminder
  will use <sound>."), and Use for All Reminders, not red, since nothing is deleted. It counts only
  the reminders whose sound changes. Reminders you sent have no sound on this iPhone and aren't
  counted. Focus is left where iOS puts it once the dialog closes.
- **Data:** Dentist appointment is on Chime and Take your allergy pill (from Maya Torres) on Rise,
  so the details and the action have something to show.
- `scripts/mockup-shots.py` has the screens this adds: `details-sound`, `details-sound-off`,
  `details-received-sound`, `settings-use-for-all`, `settings-use-for-all-confirm`,
  `settings-use-for-all-confirm-one` and `settings-use-for-all-done`.

Nothing else changed.
