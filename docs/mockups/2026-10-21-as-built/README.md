# Nudge-inator iOS mockup: as built

The app as it was built for the first version, drawn as a mockup, so there's a true record of the
shipped design to propose changes against. It's a copy of the
[first-version mockup](../archive/2026-10-04-first-version/README.md), corrected wherever the app
turned out differently, and checked screen by screen against simulator screenshots.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. On a desktop
it shows a phone with **Mockup controls** beside it, in portrait or landscape. On a phone the app
fills the screen and the controls are below it.

The words are in [GLOSSARY.md](../../../GLOSSARY.md), the decisions in
[ADR 0001](../../adr/0001-stop-silences-done-is-deliberate.md),
[ADR 0002](../../adr/0002-lock-due-time-repeat-strength-while-nudging.md) and
[ADR 0003](../../adr/0003-custom-repeat-is-an-rrule-subset.md), and the tokens in
[DESIGN.md](../../design/DESIGN.md). Where this mockup and the first-version one differ, this one is
the app.

## What it shows

| Tab | What it shows |
|---|---|
| **Now** | The permission banners, Nudging cards with **Done**, Coming Up (7 days), Last 24 Hours |
| **My Day** | Today in time order, with Done, Nudging, Missed and Left counts that filter the list, a tag filter, and the banners |
| **Tags** | Your tags with counts. **Edit** renames or deletes them, **+** adds one, and choosing a tag opens its reminders (whose **+** makes a reminder with that tag) |
| **Settings** | Notification and alarm status, **Send a Test Nudge**, **How It Nudges** (onboarding's points and each strength's nudges), **Delete All Data** |

The **+** button opens the New Reminder form: title, notes, tags, start date and time, repeat (with
its Repeat and Custom pages), strength, the **Break Through Focus** switch and **How It Nudges**.
Reminder details have the reminder's card while it's nudging, its schedule, How It Nudges, Edit,
Pause or Resume, and Delete. First launch shows onboarding.

A nudging reminder's start, repeat, strength and Break Through Focus are locked (ADR 0002): the Edit
form shows them dimmed with a lock and says why, and its details say the same under Schedule.

## How nudging works here

- **Strengths:** Gentle (every 1 hr, easing to 20 min), Firm (30 min, easing to 5) and Relentless
  (10 min, easing to 2). Firm and Relentless reach Urgent at nudge 4; Gentle never does.
- **Give-up limit:** 20 nudges or 24 hours, whichever comes first, for every strength.
- **Break Through Focus**, per reminder. On: Normal nudges are ordinary notifications, High nudges
  are Time Sensitive, and Urgent nudges ring as AlarmKit alarms. Off: every nudge is an ordinary
  notification.
- **With alarms off**, an Urgent nudge is one Time Sensitive notification (an ordinary one with Time
  Sensitive off). There's no chain of repeats.
- **Stop** on an alarm quiets that ring, and the next nudge still comes. **Open** opens the reminder,
  where **Done** is. Only Done ends the nudging.

## What changed from the first-version mockup

Each of these was found by comparing the first-version mockup with the app's screenshots, and the
mockup was changed to match the app.

**Words and formats**

1. Dates and times are the app's US English formats: "Wed, Oct 21", "Wednesday, October 21" (My
   Day and the Lock Screen), "Sun, Oct 25 at 6:25 PM", "Today at 6:00 PM", not "Mon 28 Sep" or
   "Today, 6:00 PM".
2. How soon is the system's short relative time: "in 5 min.", "in 1 hr.", not "in 5 min", "in 1 h".
3. Durations are the system's abbreviated units, at most two: "2 hr, 18 min", "7 min, 30 sec"
   (waits keep their seconds), "+2 hr, 19 min" (seconds round into the minutes once hours show).
4. A reminder's tags show in the order they were added to it, not sorted ("#money #home").

**Now and its cards**

5. A card's urgency is a word on its top row, beside the strength badge: "↑ High" in orange or the
   alarm glyph and "Urgent" in red, nothing for Normal. The line under the title is "#home · due
   7:30 AM" ("Due 7:30 AM" with no tags), without "· Urgency High". At accessibility sizes the
   badge, the word and the count stack.
6. Done, wherever a status label shows it, has a green `checkmark.circle.fill` before the word.
7. Section headers (Coming Up, Last 24 Hours, Schedule, Your Tags and the rest) are the system's
   iOS 26 headers: 17 pt semibold in the secondary label color, not 13 pt footnote. DESIGN.md
   now says so too.

**Reminder details**

8. There is no History section. The Schedule section ends with a **Last occurrence** row (its
   status label, and when it closed) when the latest occurrence has closed. A reminder deleted
   while its details are open shows "Reminder Not Found" and "It may have been deleted."
9. The status under the title is "Nudging", "Coming up" or "Paused", or how a finished one's last
   occurrence closed, not "Nudging now" or "Active".
10. The tags are plain text under the status, not buttons that open the Tags tab.
11. The lock note under Schedule shows whenever the reminder is nudging: the lock is how the app
    works, so the mockup's **Lock nudging reminders** control is gone, and the Edit form of a
    reminder that isn't nudging only says when changes apply: nothing about the nudge count
    carrying on, or a new time closing the occurrence as skipped, since neither can happen.

**How It Nudges** (details, the form, and Settings' page)

12. Each row leads with a small dot in its urgency's color, and the urgency word is semibold in that
    color (Normal in gray).
13. There's no "Next one due" take-over row: the app works the rows out from the strength and the
    switch alone.
14. The summary is one sentence a line, in the app's words: "20 nudges over 2 hr, 18 min, then it
    gives up." / "Nudges 1–3 are notifications. Nudges 4–20 ring as alarms." / "During a Focus,
    Normal nudges wait until High, unless you allow Nudge-inator in that Focus." With
    notifications off and alarms on it's "Notifications are off, so only nudges 4–20 can reach
    you, as alarms.", without a count of the alarms.
15. No nudge is a "Notification chain": with alarms off the Via label is "Notification: alarms are
    off", and the summary says "Alarms are off, so Urgent nudges come as Time Sensitive
    notifications." Via labels say "Break Through Focus is off", capitalized as the switch.

**Permission banners and Settings**

16. The alarms-off banner says "Urgent nudges now come as Time Sensitive notifications, which silent
    mode can mute" (or ordinary ones, which a Focus can hold too), not a chain. Each banner's icon
    takes its border's color.
17. My Day shows the banners too, under its date.
18. Settings has a **How It Nudges** row, which opens a page: onboarding's four points, "Below is how
    each strength nudges a reminder with Break Through Focus on.", then Gentle, Firm and Relentless.
19. The footer under Settings' Nudges rows is one sentence a line, and with alarms off says "Alarms
    are off, so Urgent nudges come as Time Sensitive notifications instead, which silent mode can
    mute." With notifications off only "Change these in iOS Settings." is left.

**Tags**

20. **Edit** (and **Done** in Edit mode) sits at the leading end of the bar, + at the trailing end.
21. A tag's screen has an inline title, never a large one.
22. On a tag's screen a nudging one-off shows its due time; a paused or finished reminder shows "—"
    with nothing under it; and every row shows its schedule, not "Paused" or "Completed".

**My Day**

23. A Done row says how many nudges it took even when that's one: "Done at 7:04 AM after 1 nudge".
24. The filter sheet's confirm button is the word **Done** in a filled capsule, not a checkmark.

**The reminder form**

25. Starts is the system's compact date and time pickers: two pills, "Oct 21, 2026" and "2:00 PM".
    While locked they are plain text without pills.
26. "Add a title to save." is red, on its own line above the note about notes and tags.
27. The line under Strength is worked out from the ladder, then the give-up limit on its own line:
    "Every 30 min at first, down to every 5 min. Rings as an alarm from nudge 4." / "Gives up after
    20 nudges or 24 hours, whichever comes first." Gentle, or any strength with the switch or
    alarms off, says "Never rings as an alarm."
28. The Custom page's summary is subheadline bold, and a yearly repeat's note reads "On September
    28, from the start date."

**Onboarding**

29. Onboarding is a full-screen cover on the system background, not a sheet. Its glyphs are in the
    secondary label color, not the accent, and each point's title is a headline.

**The largest text sizes**

30. A nudge card stacks its strength badge, urgency word and count, then the title, then **Done**,
    and only then the due time, the next nudge and the meter.
31. My Day's counts are a 2 × 2 grid, and **Filter by Tags** fills the row.

**Mockup controls**

32. **Next Urgent nudge** shows the one Time Sensitive (or ordinary) notification when alarms are
    off, not a chain.

## Where the app is wrong, not the mockup

At the accessibility text sizes a My Day row stacks its time and title, but keeps the status label
(✓ Done, Missed, Skipped, Paused) beside them, so the column is squeezed: "12:33 / PM", "Morn- /
ing meds" and "Do / ne" break mid-word (both simulators, AX5). The row's `opener` in
`App/MyDay/MyDayRows.swift` keeps the label in its `HStack` at every size. This mockup draws the
row as intended, with the label under the text. The fix is
[ticket 11](../../../.scratch/enhancement-pace/issues/11-my-day-row-status-at-accessibility-sizes.md).

## Not checked against the app

- The system's own screens: notifications on the Lock Screen and as banners, the alarm, the
  permission prompts and the Delete All Data question are drawn as before. The simulator doesn't
  show alarms, and the screenshots don't reach the system's UI.
- Dark mode, Bold Text, Increase Contrast and Reduce Transparency were not compared.
- Screen sizes other than the two simulators' (393 × 852 pt).

## How it was checked

On 2026-10-21, `scripts/screenshots.sh` took a screenshot of every screen on the `iPhone 15 Pro - iOS
26.5` and `iPhone 15 - iOS 27.0` simulators, in portrait, landscape and the largest text size
(AX5), light appearance: Now, a nudging reminder's and a coming-up reminder's details, the locked
Edit form, My Day and its filter, Tags, Edit mode, New Tag, a tag's screen, Settings and its How It
Nudges page, the New Reminder form and its Tags, Repeat and Custom pages, onboarding, and Now and
Settings with notifications, alarms and Time Sensitive off. Headless Chrome took the same screens of
this mockup, and each pair was compared by eye.

The screenshots aren't committed (`docs/screenshots` is git-ignored). To make them again, run
`scripts/screenshots.sh`; the recipe is in
[device-testing.md](../../agents/device-testing.md#simulator-screenshots). The app's times are now
plus or minus the mockup's gaps, so the times differ from the mockup's fixed 8:20 AM.

The clock is fixed at Monday 28 Sep 2026, 8:20 AM, and the data is made up.
