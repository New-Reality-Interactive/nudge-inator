# Nudge-inator iOS mockup: 1.5.0

The app as built at 1.5.0 (`v1.5.0`): the [1.4.0 mockup](../1.4.0/README.md), then
`enhancement-alarm-sound` (spec #129). Made in the release PR from the feature's eight change
mockups, which form one chain: alarm sound (#223), tone preview footer (#229), details tone and Use
for All (#456), Tutorials (#465) and tutorial sheets, which then split into How Alarm Sounds Work
leads (#467) and How It Nudges strength pills (#470), and joined again in tutorial pills on one line
(#470). It is a copy of that last one, and it takes in and replaces all eight. Frozen.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**Alarm sound (#223)**, **Details tone and Use for All (#456)** and **Tutorials (#465)** groups jump
to each state; everything also works by tapping.

## What changed since 1.4.0

- **Alarm sounds:** Default Alarm (iOS's own alarm sound) and six tones, Chime, Bell, Pulse, Beacon,
  Rise and Siren. Choosing a tone plays it; Default Alarm plays nothing, which the picker's footer
  explains.
- **Settings › Default Alarm Sound:** a gray tile with `speaker.wave.2` in Nudges, after Default Pace,
  naming the current sound. Its page lists the sounds with a checkmark, then **Use for All
  Reminders**, which asks first ("Use <sound> for All Reminders?", counting the reminders that
  change) and is dimmed when every reminder already has the sound. New reminders, and reminders
  someone sends you, start with the default. Delete All Data sets it back to Default Alarm.
- **Reminder form, Sound row:** under Break Through Focus, only while the reminder rings as an alarm
  (Relentless, or Firm with the switch on), editable while the reminder is nudging. A received
  copy's form has it too; a reminder being sent has none.
- **Details, Sound row:** under Break Through Focus, naming the sound, while the reminder rings. A
  received copy's footer says the sound is chosen on this iPhone.
- **Settings › Tutorials:** a section above Your Data with How It Nudges, How Sharing Works and How
  Alarm Sounds Work, in the tint color with their features' symbols. How It Nudges has left Nudges
  and How Sharing Works has left Sharing.
- **Every tutorial is a paged sheet**, as How Sharing Works was: Close, Back and Next, page dots,
  and Done on the last page. How It Nudges has four pages (What to Expect, then Gentle, Firm and
  Relentless, each with a pill of its strength's bars), and How Alarm Sounds Work has three (Pick
  Your Default Sound, Change Your Reminders, When It Plays). Only How Sharing Works opens by itself.
- **Tutorial pills** keep their words on one line, stop growing at xxxLarge, and stack with a down
  arrow when they don't fit side by side.
- **How It Nudges** says where to choose the alarm sound, under its alarms point.
- `scripts/mockup-shots.py` has the screens these add.

Nothing else changed.

## Checked against the app

Before release, the screens this feature adds were compared with the app (`docs/agents/release.md`,
the drift check): the screenshots harness's `testAlarmSounds`, `testFormSound` and `testSettings` on
the iPhone 15 simulator, iOS 27.2, portrait, beside this mockup's, screen by screen. `as-built/`
holds the app's, as small reference images.

- **Compared, and the same:** Settings with Default Alarm Sound and Tutorials, the Default Alarm
  Sound page with Use for All Reminders, the form's Sound page, a reminder's details with its Sound
  row (and a reminder with none), all three pages of How Alarm Sounds Work, and all four of How It
  Nudges.
- **Corrected here:** nothing. #470's last phone-check fix (an urgency word and Via label stacked
  left-aligned at the accessibility sizes) was already drawn here.
- **Differences that are data or system look, not design:** Sharing is on here and off in the
  harness's walk; the confirmation counts differ (here Bell for 10 reminders, in the app Default
  Alarm for the one reminder on Chime); the reminder with no Sound row is a Firm one with Break
  Through Focus off here and Walk the dog (Gentle) in the app; the confirmation is iOS's own dialog,
  which the mockup draws as the template's system look.
- **Not compared:** landscape and the largest text size (the phone check's), received copies' Sound
  rows, the dimmed Use for All Reminders, and the tone previews' sound. Each was checked on the
  iPhone against its change mockup when its ticket was built.
