# Nudge-inator iOS mockup: alarm sound

A change mockup for `enhancement-alarm-sound` (spec #129), ticket #223: the reminder form's Sound
row, the alarm sound picker, and Settings' Default Alarm Sound. Copied from the
[1.4.0 mockup](../1.4.0/README.md), with only what this change needs added, so the two can be
compared screen by screen. Tickets #228 and #230 build to it. The 1.5.0 version mockup takes it in
and replaces it.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**Alarm sound (#223)** group jumps to each state; everything also works by tapping.

## What changed since 1.4.0

- **Reminder form, Sound row:** in the Break Through Focus section, under the switch. It shows the
  current tone's name and opens the Sound page. It's there only while the reminder sends alarms
  (Relentless, or Firm with Break Through Focus on), and appears and goes as the switch or the
  strength changes. Gentle never rings, so it has none. The section's footer gains a second line:
  "Plays when a nudge arrives as an alarm. Other nudges use the standard notification sound."
- **The picker:** Default Alarm (iOS's own alarm sound) first, then Chime, Bell, Pulse, Beacon, Rise
  and Siren, with a checkmark on the current choice and the same footer. Default Alarm is a sound
  like the others; the person's default is whichever sound they picked in Settings. A choice is
  saved at once and the page stays open. The app plays a short preview of a tone (none for Default
  Alarm); the mockup says so in the panel instead. At the accessibility sizes the checkmark stays on
  its sound's line.
- **Settings › Default Alarm Sound:** a gray tile with `speaker.wave.2`, in Nudges right after Default
  Pace, showing the current sound's name: Default Alarm, the first in the list, until the person
  picks another. It opens the same list, whose footer adds "New reminders, and reminders someone
  sends you, start with this sound. Reminders you already have keep theirs." A new reminder's form
  starts from it. Delete All Data sets it back to Default Alarm. Reminders made before this update
  have Default Alarm.
- **Nudging:** the Edit form of a Nudging reminder keeps its Sound row editable, while start, repeat,
  strength, pace and Break Through Focus stay locked.
- **Received reminders:** the copy's form keeps its title, notes and schedule locked, and shows the
  Sound row, editable, when the copy sends alarms. The owner note says "You can add or remove your
  own tags and choose its alarm sound." A copy arrives with the recipient's Default Alarm Sound.
- **Sent reminders:** the sender's form for a reminder they're sending, or sent, has no Sound row; it
  never rings on their iPhone.
- `scripts/mockup-shots.py` has the screens this adds: `form-sound-off`, `form-sound-gentle`,
  `form-sound-picker`, `form-sent-edit`, `form-received-arrive` and `settings-default-sound`.

Nothing else changed.
