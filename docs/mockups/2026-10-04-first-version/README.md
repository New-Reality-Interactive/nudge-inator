# Nudge-inator iOS mockup: first version

Nudge-inator as an **iPhone app for iOS 26 and later**. Reminders and nudging live on the device:
there's no account, no server and no website. A reminder can have any number of tags, and you find
reminders by filtering on one or more of them.

Open [`index.html`](index.html) in a browser. It's a single file with no dependencies. On a desktop
it shows a phone with **Mockup controls** beside it, in portrait or landscape. On a phone the app
fills the screen and the controls are below it.

This mockup matches the decisions in [GLOSSARY.md](../../../GLOSSARY.md),
[ADR 0001](../../adr/0001-stop-silences-done-is-deliberate.md),
[ADR 0002](../../adr/0002-lock-due-time-repeat-strength-while-nudging.md),
[ADR 0003](../../adr/0003-custom-repeat-is-an-rrule-subset.md) and the
[first-version spec](../../../.scratch/first-version/spec.md). It was made from the
[2026-10-02 mockup](../archive/2026-10-02-ux-review-changes/README.md), which is archived and
describes the fuller product. Where the two differ, this one is the first version.

## What it shows

| Tab | What it shows |
|---|---|
| **Now** | Nudging cards with **Done**, Coming Up (7 days), Last 24 Hours |
| **My Day** | Today in time order, with Done, Nudging, Missed and Left counts that filter the list, and a tag filter |
| **Tags** | Your tags with counts. **+** adds a tag, Edit renames or deletes them, and choosing a tag opens its reminders (whose **+** makes a reminder with that tag) |
| **Settings** | Notification and alarm status, **Send a Test Nudge**, **Delete All Data** |

The **+** button opens the New Reminder form: title, notes, tags, start time, repeat, strength, and
the **Break Through Focus** switch. **How It Nudges** previews every nudge. Reminder details have
Edit, Pause or Resume, and Delete.

**Repeat** offers Never, Every Day, Every Weekday, Every Week, Every 2 Weeks, Every Month and Every
Year, and then **Custom**, which opens its own page. Custom starts from the preset you had chosen
and has plain choices only:

- **Frequency** (Daily, Weekly, Monthly, Yearly) and a stepper: "Every 2 weeks".
- **On:** weekdays for a weekly repeat. A monthly repeat offers choices taken from the start date,
  such as "On the 28th", "On the fourth Monday", "On the last Monday" or "On the last day".
- **Ends:** Never, after a number of times, or on a date.
- A summary sentence at the top ("Every 2 weeks on Monday and Wednesday at 9:00 AM, 5 times.") and
  the **Next Times** it falls due.

The app stores the result as an RRULE (ADR 0003), but nothing on screen shows one. "Water the plants"
repeats every 3 days, as an example of a custom repeat.

**Editing while nudging** works normally unless **Lock nudging reminders** is on in the mockup
controls. With it on, a nudging reminder's start, repeat, strength and Break Through Focus are locked
(ADR 0002). The Edit form shows them dimmed with a lock and says why: mark it Done or pause it to
change them. Title, notes and tags stay editable, and its details say the same under Schedule.
Reminders that aren't nudging always edit normally.

## How nudging works here

- **Strengths:** Gentle (every 60 min, easing to 20), Firm (30, easing to 5) and Relentless (10,
  easing to 2). Each has an urgency ladder: Normal, High, Urgent. Firm and Relentless reach Urgent at
  nudge 4. Gentle never does.
- **Give-up limit:** 20 nudges or 24 hours, whichever comes first, for every strength. When it's
  reached, the occurrence closes as **Missed**.
- **Break Through Focus**, per reminder:
  - **On:** Normal nudges are ordinary notifications (a Focus holds them), High nudges are Time
    Sensitive, and Urgent nudges ring as AlarmKit alarms.
  - **Off:** every nudge is an ordinary notification. Nothing breaks through a Focus and nothing
    rings. "Walk the dog" and "Water the plants" are set this way.
- **The alarm** shows the reminder's title, the system's **Stop** and an **Open** button.
  - **Stop** quiets that ring and moves the ladder along. The next nudge still comes on schedule.
  - **Open** opens the app on the reminder, where **Done** is.
  - **Done** is the only way to end the nudging. It's on the nudge card, in a notification, in the
    swipe action on Now and My Day, and on My Day's rows.
- **Take-over:** when the next occurrence of a repeat falls due while the last is still nudging, the
  last closes as Missed ("the next one took over") and the new one starts at nudge 1.
- **No quiet hours.** A Focus holds ordinary notifications, and alarms ring through every Focus,
  Sleep included. The Break Through Focus switch is the only control.
- **Weaker fallbacks:** with alarms not allowed, Urgent nudges come as a chain of Time Sensitive
  notifications. With Time Sensitive off, High nudges are ordinary notifications. With notifications
  off, a red banner says what can still reach you.
- **Privacy:** notifications show the title and "Nudge 3 of 20 · High". Alarms show only the title.
  Notes and tags stay in the app.

## What's different from the archived mockup

Left out of the first version: Snooze, Not Done and Undo, the Clear log, the Done follow-up
notification, quiet hours and Ignore Quiet Hours, carry-over ("Starts higher"), the
give-up and snooze-length controls, the Search tab, filtering all reminders by several tags at once, history search, Export Data, Siri and Shortcuts,
Assistive Access, the Live Activity countdown, and the iOS 18 and iOS 27 variants.

Changed: the alarm's secondary button is **Open**, not Snooze, and Stop no longer counts as Done.
Custom repeats are back with a smaller set of choices (no "several times a day"). The proposed lock
on a nudging reminder's schedule can be turned on in the mockup controls.

## Mockup controls

These are not part of the app:

- **Next early nudge** shows a notification for the next nudging reminder whose next nudge isn't
  Urgent. Tap it to show **Done**. In landscape it's a banner over the app.
- **Next Urgent nudge** shows the alarm. **Stop** returns to the app, still nudging. **Open** goes to
  the reminder. With alarms not allowed it shows the first notification of the chain.
- **First launch** shows onboarding and the permission prompts.
- **Lock nudging reminders** turns on the proposed lock (ADR 0002). Then edit any nudging reminder,
  such as "Take the bins out" or "Reply to Alex about the lease" on Now, to see its locked fields.
  Off, every reminder edits as before: changes apply from the next nudge, and changing a one-off's
  time closes it as skipped. An Edit form that's open updates when you flip it. Reset turns it off.
- **Permissions** (notifications, alarms, Time Sensitive), **24-Hour Time**, **Appearance**, **Text
  Size** (all 12 Dynamic Type sizes), **Bold Text**, **Increase Contrast** and **Reduce
  Transparency** stand in for iOS Settings.
- **Screen size** and **Orientation** switch the phone between the iPhones that run iOS 26.
- **Reset the mockup** restores the data.

The clock is fixed at Monday 28 Sep 2026, 8:20 AM, and the data is made up.

## To check on a device

The mockup draws the system's alarm and notifications as an approximation. These are open:

- The alarm limit: Apple documents only the `maximumLimitReached` error, not a number.
- Whether tapping **Open** silences the ring. Apple's docs say a custom secondary button runs its
  intent "without mutating the alarm state", so the app's intent probably has to stop the alarm
  itself.
- How **Open** behaves on a locked phone. The secondary intent is documented as available only after
  the first unlock since a restart.

## How it was checked

On 2026-10-13, a headless Chrome script checked the Custom page and the lock: Custom from a preset,
weekdays, the interval, each monthly choice, yearly, both ways of ending, Next Times, saving and
reopening a custom repeat, the 31st skipping short months for Custom and moving to the last day for
the preset, **Lock nudging reminders** off (a nudging one-off edits freely and a new time skips it)
and on (any nudging reminder locks its fields, one that isn't nudging doesn't, and flipping it with
the form open updates the form), and Reset turning it off. The console had no errors, and
screenshots of the Repeat page, the Custom page (weekly and monthly), and the locked form (default
text size and AX3) were checked by eye.

Earlier, in headless Chrome, a script clicked through every tab, every reminder's details, the New and Edit
Reminder forms (including the Break Through Focus switch, the Repeat and Tags pages, and saving),
a notification and its Done action, the alarm's Stop and Open, the notification chain, the test
nudge, Pause, Resume, Delete, both My Day filters, adding, renaming and deleting a tag, a tag's reminders, a new reminder from a tag, landscape and reset, and the
console had no errors. Screenshots of Now, reminder details, the form, Settings, the alarm, Tags and a tag's
reminders were checked by eye. The contrast, Dynamic Type and landscape audits of the archived mockup were not
repeated. The screens and styles are the archived mockup's, so those results should still hold, but
that isn't re-measured.
