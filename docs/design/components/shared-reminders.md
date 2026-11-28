# Shared reminders

A component of the design system ([DESIGN.md](../DESIGN.md), Components): read the
intro there for the item format and the rules every component follows.

What the shared reminders mockup (`docs/mockups/1.4.0/`, #183) adds. It rewrites
nothing above. Two items are exceptions to rules above, and name them: Disconnect's choice, and the
sharing paused and offline banner.

- **"From <name>" label:** on a received reminder, `person` then "From Maya" in `{typography.subhead}`
  `{colors.secondary-label}`, under the title on Now's cards and every list row. It has no color of its
  own: who sent a reminder isn't a status. Where the row has no strength badge (My Day, Reminders,
  Last 24 Hours) the strength badge follows the label. Details add the strength in words, as How It
  Nudges says it ("Relentless: rings an alarm until you mark it done").
- **Mine | Sent:** the system's segmented `Picker` under the search field (iOS keeps the search field
  in the navigation bar; #201), or under the title where there's no search field, filling the content
  width. Two short words, so it stays segmented at the accessibility sizes.
- **Segmented choices' capitalization:** the spec's words as written ("Start right away", "Ask me
  first"), which are glossary terms. `All Tags | Any Tag` keeps its title style.
- **Connection rows:** a round `{colors.tile-gray}` tile with `person`, the name in `{typography.body}`,
  a detail line in `{typography.subhead}` `{colors.secondary-label}` ("Connected", "Invited · Waiting
  for them to accept") and a chevron, under Connected and Invited headers. Settings' Connections row
  is a `{colors.tile-gray}` tile with `person.2`, in a section headed Sharing, under the Sharing
  switch: a `{colors.tile-blue}` tile with `square.and.arrow.up` and a switch, with the footer
  "Connect with people through iCloud to send each other reminders." The Connections row shows only
  while the switch is on (#387). Below it, also only while the switch is on, the Share Activity row
  is a `{colors.tile-gray}` tile with `list.bullet.rectangle` and a chevron, with no status (#397).
  How Sharing Works is no longer in this section: it's under Tutorials (#466).
- **Tutorials section** (mockups `2026-11-20-tutorials` and `2026-11-20-tutorial-sheets`, #466):
  Settings' last section above Your Data, headed Tutorials, with no footer. One row per feature's
  tutorial, in the order the features shipped: How It Nudges, How Sharing Works, How Alarm Sounds
  Work (#467), then How Quiet Hours Work (#468). Each row is a `{colors.tile-gray}` tile with its
  feature's symbol (`bell`, `person.2`, `speaker.wave.2`, `bell.slash`) and its title in the accent, which says it can be tapped, as Send a Test Nudge's
  does. Every row opens a sheet, so none has a chevron, since the HIG keeps the disclosure indicator
  for drilling in (#423, #470). Every tutorial sheet is the one How Sharing Works uses (below), with
  its own pages. Only How Sharing Works and How Quiet Hours Work open by themselves.
- **How Sharing Works sheet** (mockup `2026-11-15-sharing-tutorial`, #423): four pages in an inset
  grouped list, inline title How Sharing Works. Each page has decorative pills (an SF Symbol and a
  word in `{colors.label}`, 8 pt apart, on `tertiary-system-fill`, `arrow.forward` between them in
  `{colors.secondary-label}`; stacked with `arrow.down` where they don't fit on one line; each pill
  keeps its words on one line, as wide as they need, and its text stops growing at xxxLarge, in every
  tutorial (#470, mockup `2026-11-20-tutorial-pills-one-line`)), hidden from VoiceOver; a centered heading in `{typography.title2}` bold; then a lead in
  `{typography.body}` and rows with a `{colors.tile-blue}` tile, a title in `{typography.body}` and a
  line under it in `{typography.subhead}` `{colors.secondary-label}`, or, on Connect, three numbered
  steps in accent circles (Accent's one exception; capped at 44 pt, dividers from the circle's
  edge) and a footer, with an optional lead under the heading, as How Quiet Hours Work's Your
  Schedules has (#468). Rows stack at the accessibility
  sizes, as Settings rows do. The pages swipe, a paged `TabView` that settles one page at a time
  (#430, mockup `2026-11-16-tutorial-swipe-top-bar`); each page scrolls on its own. Under them,
  pinned and centred, page dots (accent for this page, separator for the others; VoiceOver reads
  "Page 2 of 4"), with no button under the pages. Close (the system's close role, drawn `xmark`) is
  top left on every page. Back (`chevron.backward`) and Next (`chevron.forward`) share one capsule
  top right, Back dimmed on page 1; on the last page Next becomes the system's confirm checkmark,
  named Done, which closes the sheet. A page change speaks the new page's heading.
- **How It Nudges sheet** (mockups `2026-11-20-tutorial-sheets` and
  `2026-11-20-how-it-nudges-strength-pills`, #470): How Sharing Works' sheet with
  four pages, inline title How It Nudges, opened only from its row. What to Expect (`bell` Nudge, an
  arrow, `checkmark.circle.fill` Done) lists the welcome's four points as rows with their symbols,
  and #459's line about the alarm sound as a second line under the alarms point; onboarding shows
  the points without it. Gentle, Firm and Relentless each show a pill of the strength's bars alone,
  as tall as the other pills' icons, as the picture (the heading names the strength); the strength's line the form shows under Strength in `{typography.body}`;
  "At your Default Pace, <pace>, with Break Through Focus on." in `{typography.subhead}`
  `{colors.secondary-label}`; then the How It Nudges section (How It Nudges, above) with no header. The pages are
  built at the Default Pace as the sheet opens, so a changed pace shows the next time.
- **How Alarm Sounds Work sheet** (mockups `2026-11-20-tutorial-sheets` and
  `2026-11-20-alarm-sounds-tutorial-leads`, #467): How Sharing Works' sheet with three pages, each a
  lead and rows, inline title How Alarm Sounds Work, opened only from its row: Pick Your Default
  Sound (a `speaker.wave.2` Default Alarm Sound pill, two rows), Change Your Reminders (`bell` Wake
  Up, an arrow, `speaker.wave.2` Chime; three rows and a footer) and When It Plays (an `alarm` Alarm pill alone, since a notification
  never plays the sound; three rows). Its pills and the Use for All Reminders row reuse the screens'
  own strings, and its tests check that the sentences name Default Alarm Sound, Sound and the tones
  as the screens do.
- **How Quiet Hours Work sheet** (mockup `2026-11-22-quiet-hours-tutorial`, #468): How Sharing Works'
  sheet with four pages, inline title How Quiet Hours Work. It opens by itself over the Quiet Hours
  page the first time that page opens (Close, Done or a swipe ends that for good; an update keeps
  it; opening it from Settings' row doesn't count), and any time from its row. Rest Without Nudges
  (`moon.fill` 10:00 PM, an arrow, `bell` 7:00 AM; two rows), Quiet Now (a `bell.slash` Quiet Now
  pill; two rows), Your Schedules (a `plus` Add Schedule pill; a lead under the heading, then three
  numbered steps and a footer) and Held Nudges (`bell.slash` Held, an arrow, `xmark.circle.fill`
  Missed; three rows, the last quoting the Missed note). Its pills reuse the screens' own strings,
  and the Missed note is the note's own text.
- **Share Activity entries:** plain rows with nothing to tap, newest first, in one inset list: who
  it concerns in `{typography.body}` (several names joined as a list), then what happened and when
  ("Today at 7:58 AM"), each in `{typography.subhead}` `{colors.secondary-label}`. VoiceOver reads
  an entry as one element. The list's footer is "Kept on this iPhone only. Turning off Sharing
  clears it." With nothing recorded, the empty state is `checkmark.circle.fill`, "No Share
  Activity" and "Nothing has gone wrong with sharing. If iCloud refuses a change or a connection
  ends, it shows here." An entry with no name to show (a store from before names were kept) shows its
  sentence and time alone.
- **Sync states:** "Waiting to sync" with `clock`, in `{colors.secondary-label}`, on a Sent row's
  trailing label and on a received reminder's "From" line. It's a state, so it's never accent, warning
  or negative.
- **Status labels Sent and received rows add:** Waiting, Canceled, Removed and Delivered, all in
  `{colors.secondary-label}`, as Skipped and Paused are.
- **Sent rows:** as Reminders tab rows, due time then title, with a detail line ("Delivered", "Not
  sharing status", "Not sharing this one", "Waiting for them to accept", "Not delivered yet") and the
  status label trailing. A row swipes to Edit at the edge and Delete beside it, as a tag does
  (Swipe actions, #429): Edit opens the sent reminder's Edit Reminder form, and Delete asks the
  details' question first. There's no Done: a sent reminder doesn't nudge the sender. Its content is
  at least 48 pt tall, as every row with a swipe. Group headers name the person and, trailing,
  whether they share status.
- **Sent's tools:** the Reminders tab's search field, count header, Filter and Sort in the same places.
  The filter sheet ("Filter Sent") has People, Status, Strength and Due Date, and Sort orders the
  reminders inside each person's group. Sent has no tags, and no tools in its empty states. The count
  is of reminders, so one sent to two people counts once.
- **7-day history:** on a repeating Sent row, under its text: today and the 7 days before, eight cells,
  oldest first, today on a `{colors.tertiary-fill}` cell, each with the day's initial and a glyph
  (#207's change mockup): `checkmark.circle.fill` Done (positive), `xmark.circle.fill` Missed
  (negative), `bell` Nudging (negative), `circle.dashed` Skipped (and Removed, which a day's report
  never holds), `pause` Paused, `clock` Coming up and `circle.slash` for a day with nothing due (a
  weekly repeat's off day), in the secondary label color, or `{colors.label}` on today's cell with its
  initial. The fill's rule is about text, and these are glyphs, so the status colors stay on it. Every
  glyph takes the box Done's does, so the initials line up. At the accessibility sizes the cells run
  four to a line. VoiceOver reads it as one element naming each day and status (the row's value,
  after its label: "Thursday: Done, …, Today: Coming up"). Details list the days newest first under
  "<first name>, Last 7 Days", each with its glyph beside its status word, as Done's status label has
  its check, or "Nothing due". It's hidden with status sharing off, "Not sharing this one", Waiting to
  sync and Waiting for them to accept. The status labels on the row and on Sent To keep their own look.
- **Waiting for You:** a section on Now between Nudging and Coming Up, each row with small filled
  Accept (`button-prominent`) and Remove (`button-destructive`) capsules, side by side as an even
  pair, full width when the row stacks (#402, `docs/mockups/1.4.0/`). It doesn't count toward the Now badge.
- **Notes on a received reminder:** a `{colors.cell}` card with `{rounded.control}` corners, `info.circle`
  or `clock` in `{colors.secondary-label}`, a semibold line and a detail line, which for a sender's change is one line per changed field ("Due
  time changed from 8:00 AM to 9:00 AM"; a notes change reads "Notes changed", with no text). No color:
  a change or a cancellation isn't "needs you now".
- **Disconnect's choice is a sheet, an exception to confirmation dialogs (Components):** a dialog can
  only list buttons, so it can't show Remove as the default. A checked list of the two options, then a
  `button-destructive` Disconnect (#402), with the form's Cancel. When the other person ended the
  connection the sheet has a prominent Continue and no Cancel, because the connection is already over
  and the choice has to be made: the one question without a way to close it that changes nothing.
- **Turn Off Sharing** (#388, the Turn Off Sharing mockup, `docs/mockups/1.4.0/`):
  Disconnect's sheet for everyone at once, under the same exception, asked whenever turning Sharing
  off would delete anything: a connection, an invite, a reminder sent or received. A first line
  saying what goes, the two options under "<n> Reminders You've Received" only when something was
  received, the note footer only while someone is connected (under the options, or under the first
  line when there are none), then a `button-destructive` Turn Off Sharing (#402), with the ✕ to
  cancel. The switch stays on until it's confirmed, and shows no message when it's off.
- **Apple Account Changed** (#212's change mockup, `docs/mockups/1.4.0/`): a
  sheet over whatever screen is up, once, when a different Apple Account signs in. Connection Ended's
  shape with no choice: a lead line, a list headed "Removed from This iPhone" (received reminders,
  connections, sent reminders, each a `{typography.body}` line over a `{typography.subhead}`
  `{colors.secondary-label}` detail, a row with nothing in it left out), a footer, and one prominent
  OK. A swipe down closes it too, since it only informs. When connections were removed, the footer
  also says the people in them weren't told (#433, `docs/mockups/1.4.0/`).
- **Sharing paused and offline, an exception to Warning's meaning (Colors):** the `permission-banner`
  with `{colors.warning}`, `icloud.slash` or `wifi.slash`, on Connections, Send To and Sent only. It
  extends Warning from the alarms-off and Time Sensitive-off banners to these two, as the same kind of
  "something can't reach you" message. Nothing else in the app changes.
- **Sender-owned fields:** a received reminder's form shows the `lock` beside its reason ("Maya owns this
  reminder"), as a locked row does, though these fields aren't Locked in the glossary's sense.
- **Symbols added:** `person`, `person.2`, `person.badge.plus` (invites), `person.slash` (Disconnect),
  `icloud.slash`, `wifi.slash`, `minus`. Also used here: `pause` and `info.circle`. How Sharing Works
  uses `iphone`, `arrow.forward` (it flips in right to left), `icloud`, `paperplane`, `eye`, `hand.raised`, `lock`, `clock`, `person.2`,
  `person.badge.plus`, `list.bullet.rectangle`, `checkmark.circle.fill`, `bell` and `info.circle`.
