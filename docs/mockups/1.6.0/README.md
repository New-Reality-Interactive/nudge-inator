# Nudge-inator iOS mockup: 1.6.0

The app as built at 1.6.0 (`v1.6.0`): the [1.5.0 mockup](../1.5.0/README.md), then
`quiet-hours-and-shortcuts` (spec #338). Made in the release PR from the feature's thirteen change
mockups. Eleven form one chain, Missed note (#369), Quiet Hours page (#370, #371), schedule switch
(#371), Add Schedule button (#498), How Quiet Hours Work (#468), quiet hours banner (#499),
Settings rows (#372), My Day on another day (#374, #375), My Day's day buttons (#375), Tag details
(#376, #377, #378) and the Tags swipe's List tile (#378), and this is a copy of its last. Two
branched off it and are folded in here: duplicate schedule (#371, from the schedule switch) and
How Quiet Hours Work's Your Schedules with icons (#379, from the tutorial). It takes in and
replaces all thirteen. Frozen.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. The panel's
**My Day on another day (#374, #375)**, **How Quiet Hours Work (#468)**, **Quiet Hours page (#370,
#371)**, **Missed note (#369)** and **Tag details** groups jump to each state; everything also
works by tapping.

## What changed since 1.5.0

- **Settings › Quiet Hours**, in Nudges after Default Pace, on a gray `bell.slash` tile. It says
  whether nudges are held now and until when: On (Quiet Now), Until 7:00 AM (a schedule that's on
  covers this moment, the latest end when several do), Starts 10:00 PM (the next start, with its
  weekday when it isn't today), or Off.
- **The Quiet Hours page:** Quiet Now, one switch that holds every nudge until it's turned off,
  then Schedules, each row the range, its days in secondary text and a switch (off keeps the row,
  dimmed). While Quiet Now is on, a line says the schedules apply again when it's off. The bar's
  + (Add Schedule) opens a new schedule at 10:00 PM to 7:00 AM, every day; with none, "No
  Schedules" points at the +.
- **Add Schedule and Edit Schedule:** a sheet with Cancel and Add or Save; Edit's first row is a
  Schedule switch. Starts and Ends are time pills with a line saying when it ends; Days are a
  checklist. Add or Save stays off, with a red line saying why, while the start equals the end, no
  day is chosen, or the times and days copy another schedule's. Edit has Delete Schedule, which
  asks first.
- **The holding banner** on Now, My Day and Reminders while Quiet Now is on or a schedule covers
  the time: "Quiet hours are holding nudges", then "Until 9:00 AM." or "Until you turn it off.",
  then where to change it. Gray border, `bell.slash`, not tappable.
- **Now's nudge card under Quiet Now:** in place of the next nudge, "Quiet Now is holding its
  nudges. It closes as Missed at 5:30 PM if it stays on." (#379's phone check; no change mockup
  drew it, so it's drawn here for the first time).
- **The Missed note:** an occurrence that closed as Missed while quiet hours held some of its nudges
  says "Quiet hours held 10 of its 20 nudges." under how it closed, wherever that Missed shows.
- **How Quiet Hours Work:** a four-page tutorial (Rest Without Nudges, Quiet Now, Your Schedules
  with icon rows, Held Nudges), the last row of Settings › Tutorials, opening by itself once the
  first time the Quiet Hours page opens.
- **Settings' Notifications, Alarms and Badges rows** end in a chevron and open the app's page in
  iOS Settings. The Open iOS Settings row is gone.
- **My Day on another day:** Previous Day and Next Day, 44 pt glass chevrons either side of the
  date (in the bar in landscape), move a day, back to the day the oldest reminder was created and
  forward 7 days, each dimmed at its end. Yesterday or Tomorrow names the day before its date.
  Today, top left, comes back. A past day lists its history; a future day what falls due, as Left
  or Paused. Counts, filters and their words follow the day. No sideways swipe.
- **Tag details:** a tag row opens its page, pushed, with its tile, name and counts, a Reminders row
  (teal `list.bullet.clipboard`) to the tag's reminders, Edit (the Rename Tag sheet) and Delete
  Tag, which asks first. The row's swipe offers Delete, Edit and List (teal), whose VoiceOver action
  is Reminders.
- `scripts/mockup-shots.py` has the screens these add.

The Tags tab and Sent's people now sort in the person's locale order (#335); the mockup's English
names sort the same either way, so nothing here shows it. Nothing else changed.

## Checked against the app

Before release, the screens this feature adds were compared with the app (`docs/agents/release.md`,
the drift check): the screenshots harness's `testQuietHours`, `testTags`, `testMyDay`, `testSettings`
and `testSiteShots` on the iPhone 15 simulator, iOS 27.2, portrait, beside this mockup's, screen by
screen. `as-built/` holds the app's, as small reference images.

- **Compared, and the same:** the holding banner on Now, My Day and Reminders with Quiet Now on;
  Now's nudge cards under Quiet Now; the Quiet Hours page with a schedule and Quiet Now on, and its
  empty state; Add Schedule; Settings' Nudges with the three rows' chevrons and the Quiet Hours
  row; the Tag details page and, from its Reminders row, the tag's reminders; My Day on tomorrow and
  yesterday, with Today, the day buttons and the counts; and all four pages of How Quiet Hours Work,
  Your Schedules with its icon rows.
- **Corrected here:** Now's nudge card under Quiet Now, which no change mockup drew (#379's phone
  check added it to the app). Nothing else.
- **Differences that are data or system look, not design:** the harness runs at the simulator's
  clock, not the mockup's 8:20 AM, so times, dates and which rows fall on a day differ; #home has 5
  reminders there and 7 here; Add Schedule here opens with the made-up schedule already saved, so
  its duplicate line shows, where the app's walk has none; Sharing is on here and off in the walk;
  after the walk scrolls, iOS minimizes the tab bar to the current tab's button, which the mockup
  doesn't draw.
- **Not compared:** landscape and the largest text size (the phone check's), the Missed note (the
  harness has no occurrence held by quiet hours), a schedule's Edit sheet and its refusals, Delete
  Tag and Tag Deleted, the Tags swipe's List tile, and the Settings rows' links into iOS Settings.
  Each was checked on the iPhone against its change mockup when its ticket was built.
