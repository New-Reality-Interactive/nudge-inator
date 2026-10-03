---
title: "Product Brief: Nudge-inator"
status: draft
created: 2026-09-29
updated: 2026-10-03
source: docs/mockups/2026-10-02-ux-review-changes (index.html and README.md); docs/design (DESIGN.md and EXPERIENCE.md)
---

# Product Brief: Nudge-inator

Nudge-inator is a reminders app for **iPhone**, built for iOS only, that keeps nudging until you tap
**Done**. iPad runs the iPhone app in v1 and gets its own layout in v2 (see
[§5](#5-devices-orientations-and-ios-versions)).

The [tags mockup](../mockups/2026-10-02-ux-review-changes/index.html) is the visual reference for the app.
Its [README](../mockups/2026-10-02-ux-review-changes/README.md) explains the reasons behind it and how it
was checked against Apple's Human Interface Guidelines. It shows an iPhone in portrait and
landscape, on iOS 18, 26 and 27, and draws only what the app can build with the system's components
on each. The UX spines, [DESIGN.md](../design/DESIGN.md) (how it looks) and
[EXPERIENCE.md](../design/EXPERIENCE.md) (how it works), build on the mockup and add what it doesn't
show.

Where documents differ, precedence runs:

1. The nudging rules in [§3](#3-product-concepts), [§4](#4-how-nudges-reach-you) and
   [§10](#10-risks-and-decisions).
2. The [architecture spine](../architecture/ARCHITECTURE-SPINE.md), for how those rules are built.
3. The UX spines, for how the app looks and behaves around those rules.
4. The mockup, which illustrates the spines. The app looks like the mockup, but where the mockup and
   a spine differ, the spine wins.

The decision logs (`.memlog.md` in each folder) record the reasons behind decisions and don't
override any of these.

This brief replaces the earlier website-and-API brief. Detail that doesn't belong in the brief, such
as what was removed and why, layout notes, a localization checklist and the TestFlight setup, is in the
[addendum](addendum.md).

## 1. Executive summary

Ordinary reminders fire once and go quiet. If you're busy, asleep, driving or distracted when they
fire, the moment passes and nothing follows up. Nudge-inator keeps nudging until you tap **Done**:
- Each reminder has a **strength** that sets how often it nudges and how insistent it gets.
- A **give-up limit** keeps it from nudging forever.
- **Quiet hours** hold nudges overnight.
- A missed occurrence makes the next one start more insistently.
- Done can be taken back. Stopping an alarm counts as Done, so the app asks at once whether it
  really is done.

Early nudges are notifications: ordinary ones at Normal urgency, and Time Sensitive ones, which get
through Focus, at High. On iOS 26 and later, the final, Urgent nudges ring as
**AlarmKit alarms**: prominent system alerts that sound through silent mode and Focus. On iOS 18,
and whenever alarms aren't allowed, a minute-by-minute chain of notifications stands in. You organize reminders with **tags**, as many as each reminder needs,
and filter by one or more tags on the Tags tab and on My Day.

The app runs entirely on the device: no sign-up, no server, and nothing sent anywhere except the
person's own iCloud or computer backup (or an export they choose to share), and no running costs
beyond the Apple Developer Program.

## 2. Problem and audience

**The problem.** A reminder that fires once can be missed completely: swiped away without reading,
buried under other notifications, or silenced by Focus. Snoozing is too easy, and nothing checks
whether the task got done. The person finds out when the bins weren't taken out, the rent is late
or the medication was skipped.

**Who it's for.** People whose reminders have to be acted on, not just seen:
- people who take medication on a schedule, or look after someone who does
- people with ADHD, or anyone for whom a single alert is easy to dismiss and forget
- anyone with a few non-negotiable deadlines (rent, a reply before a cutoff, a stand-up, an
  appointment) mixed in with low-stakes routines

They need nudging they can tune per reminder: gentle for watering the plants, relentless for paying
rent. It must stop the moment they act.

**Audience plan.** The first release goes to the owner and invited testers through
TestFlight. It's released on the App Store once the success measures are met (see [§10](#10-risks-and-decisions)).

## 3. Product concepts

| Concept | Meaning |
|---|---|
| **Reminder** | Something to be nudged about: a title (required), optional notes (shown only in the app), any number of tags, a start time, a time zone (it follows the iPhone's time zone, the default, or stays in one chosen zone), a repeat rule (one of the form's presets, or Custom, which can repeat several times a day; a monthly or yearly repeat on a day a month doesn't have falls on its last day), a strength, a snooze length, a give-up limit and whether it ignores quiet hours. |
| **Occurrence** | One time a reminder falls due. It's **coming up**, then **nudging**, then closes as **done**, **missed** or **skipped**. Each has an event history. A reminder has at most 1 open occurrence. When the next one falls due while the last is still open, the last closes as missed ("Missed: the next one took over") and the new one starts at nudge 1. |
| **Nudge** | One alert sent while an occurrence is open: a notification or an alarm. |
| **Strength** | Gentle, Firm or Relentless. It sets the intervals and how urgency rises (table below). |
| **Urgency** | Normal, High or Urgent. It rises as nudges go unanswered and decides how a nudge arrives ([§4](#4-how-nudges-reach-you)). |
| **Give-up limit** | After a number of nudges or a time, whichever comes first, the occurrence stops and counts as **missed**. Quiet hours and snoozed time don't count toward the time. The limit can't end an occurrence before its first High nudge, so each strength has a smallest limit. Choosing a gentler strength raises a lower limit to its minimum. Ranges, defaults and minimums are in the tables below. |
| **Quiet hours** | A daily window, such as 10 PM to 7 AM, in the iPhone's current time zone, that stops every open occurrence's clock, as Snooze does. No nudges are sent, nothing escalates, no alarms ring and the time doesn't count toward the give-up limit. When it ends, the next nudge is sent at once (1 nudge, not a backlog), and the intervals carry on from it. An occurrence due during quiet hours sends nudge 1 then. Start and end can't be the same time. A reminder with **Ignore Quiet Hours** on nudges through them. |
| **Carry-over** | After a missed occurrence, the next one that nudges sends its Normal nudges at High ("↑ Starts higher"). Its intervals, and when it reaches Urgent, don't change, so Relentless, which starts at High, isn't affected. Carry-over doesn't stack. Skipped occurrences neither use it nor clear it, and pausing the reminder clears it. |
| **Tag** | A one-word label shown as `#home`, with no color. A reminder can have any number of tags or none. Names are unique, ignoring case. Deleting a tag removes it from its reminders (which aren't deleted) and from any tag filter. |
| **My Day** | Everything due today in time order, with Done, Nudging, Missed and Left counts. Filter by one or more tags (All or Any, or No Tags), and tap a count to show only that status. |
| **Snooze** | A break of a set length, a limited number of times per occurrence. Each reminder has its own snooze length: its strength's default, or longer (tables below). Choosing a gentler strength raises a shorter snooze length to the new strength's default. It doesn't raise the level, and snoozed time doesn't count toward the limit. |
| **Clear** | The system's own Clear on a notification. Nudging continues. The app has no Dismiss action of its own. |
| **Done** | The only way to close an occurrence as done. On an alarm, it's the system's **Stop** control, and a **Done follow-up** notification asks at once whether it's really done ([§4](#4-how-nudges-reach-you)). The give-up limit, the next occurrence, Pause, Delete and some edits also stop nudging. Quiet hours hold it. |
| **Not Done** | Reopens the reminder's latest done occurrence until its next occurrence falls due. A one-off has no next occurrence, so for it Not Done lasts 24 hours after Done. Pausing the reminder ends the window, and resuming doesn't bring it back. For any done occurrence, it's offered in Reminder details, in Assistive Access, and as **Undo** right after Done. Rows in Now (Last 24 Hours) and My Day offer it only when the occurrence was closed by an alarm's Stop, which also gets the Done follow-up notification with **Not Done** ([EXPERIENCE.md › Reminder row](../design/EXPERIENCE.md#reminder-row) owns this). The next nudge comes one interval after reopening, at the next step, and the time it was closed doesn't count toward the limit. If the occurrence had already used its give-up limit (nudges or time), reopening allows one more nudge (an Urgent one without alarms is one notification, not a chain); if that one goes unanswered for an interval, it closes as missed ("Missed: gave up after the limit"). |
| **Pause** | Stops a reminder. An occurrence that's nudging closes as **skipped**, and anything due while it's paused is skipped too. Skipped isn't missed, so there's no carry-over, and pausing clears any carry-over. Resume picks up at the next time. |
| **Edit** | A new schedule applies from the next time it's due. A new strength, give-up limit or Ignore Quiet Hours applies from the next nudge, and the nudge count carries on. A new snooze length applies from the next snooze. If a lowered limit has already been reached, the open occurrence closes as skipped; other edits never close it. So does a one-off reminder whose time changes while it's nudging. A one-off can't be saved with a start time that has already passed; the form asks for a later time. The one exception is editing a reminder that was already a one-off without changing its time (for example, renaming it). Resuming one, or changing a repeat to Never, needs a later time. |
| **Completed** | A one-off reminder whose occurrence has closed. It has nothing left to nudge, so Tags and Search list it under Completed. Not Done, or giving it a new time, makes it active again. Repeating reminders are never completed. A paused reminder is Paused, not Completed, even if its occurrence closed when it was paused; Resume then asks for a new time. A Completed one-off can't be paused. |
| **Delete** | Deletes a reminder and its history, after a confirmation. **Delete All Data** does this for every reminder and tag, and also clears Recent Searches and the tag filters. It keeps settings (quiet hours, time zone for new reminders). |

**How each strength nudges:**

| Strength | Intervals between nudges | Urgency | With the default limit |
|---|---|---|---|
| **Gentle** | 60, 45, 34, 25 min, then every 20 | Normal, then High from nudge 5 (about 2 h 45 min after it's due). Never Urgent. | 20 nudges over about 8 hours |
| **Firm** | 30, 15, 7.5 min, then every 5 | Normal, then High at nudge 3 (45 min after it's due) and Urgent from nudge 4 | 20 nudges over about 2 h 12 min |
| **Relentless** | 10, 5, 2.5 min, then every 2 | High from nudge 1, Urgent from nudge 4 | 20 nudges over about 50 min |

**Set by the strength:**

| Strength | Default snooze length | Smallest give-up limit |
|---|---|---|
| **Gentle** | 30 min | 5 nudges or 3 hours |
| **Firm** | 15 min | 3 nudges or 1 hour |
| **Relentless** | 5 min | 1 nudge or 15 min |

**Limits and defaults:**

| Item | Limit | Default |
|---|---|---|
| Title | Up to 200 characters. Required. | None |
| Notes | Up to 2,000 characters | None |
| Tag name | 1–30 characters, one word. Spaces become hyphens, one leading `#` is dropped, and hyphens at either end are removed. | None |
| Give-up limit, nudges | 1–100, and at least the strength's smallest | 20 |
| Give-up limit, time | 15 minutes to 7 days, and at least the strength's smallest | 24 hours |
| Snooze length | The strength's default, or 5, 10, 15 or 30 min where that's longer | The strength's default |
| Snoozes per occurrence | 3 | Not applicable |
| Event history | Kept for 90 days | Not applicable |

## 4. How nudges reach you

| Nudge | iOS 26 and later | iOS 18 |
|---|---|---|
| Normal | **Notification** (`.active`) with **Done** and **Snooze**. A Focus holds it. | Same |
| High | **Time Sensitive notification**, with the same actions. It gets through Focus. | Same |
| Urgent (Firm and Relentless, from nudge 4) | **AlarmKit alarm**: a prominent system alert that rings and vibrates through silent mode and Focus, with **Snooze** and the system's **Stop**, which counts as Done | **Notification chain**: each time the occurrence enters Urgent, a Time Sensitive notification at once and then every minute, 10 in all. Then Urgent nudges follow the strength's interval. Silent mode can mute them. |
| Urgent, with alarms not allowed | **Notification chain**, as on iOS 18 | n/a |
| Urgent, once the system's alarm limit is reached | A Time Sensitive notification for each nudge that couldn't get an alarm | n/a |

- Gentle reminders never reach Urgent, so they never ring an alarm.
- **During a Focus, Normal nudges wait.** A Gentle or Firm reminder's first nudges are held until it
  reaches High (see the strength table in [§3](#3-product-concepts)). Relentless starts at High. After a miss, carry-over sends Normal nudges at High, so they get
  through. The give-up limit can't end an occurrence before its first High nudge (see
  [§3](#3-product-concepts)). People who want every nudge can allow Nudge-inator in that Focus. How
  It Nudges and Settings say so.
- **The alarm screen is the system's own.** AlarmKit draws it from a title, an optional secondary
  button and a tint color. It shows the app's name, the reminder's title, **Snooze** (with its
  length, such as "Snooze 15 min", filled with the tint color) and the system's stop control. From
  iOS 26.1 the app can't label that control, so it can't say **Done**. Stopping the alarm runs the
  app's code, which marks the occurrence done, and onboarding says so. The nudge count and snoozes
  left can't appear on the alarm, so the app shows them on the nudging card. After a snooze, the
  countdown shows on the Lock Screen as the app's Live Activity, with **Done**.
- **Where nudges appear depends on whether the iPhone is in use.** On a locked iPhone, the alarm
  and notifications appear on the Lock Screen, which is always portrait. On an iPhone that's in use,
  they appear over the app: the alarm in the Dynamic Island, and notifications as banners at the
  top. In landscape the Dynamic Island is at the side, so the mockup shows the alarm as a banner at
  the top center. That's an approximation, to confirm on a device (see [§10](#10-risks-and-decisions)).
  The alarm also shows in StandBy.
- A paired **Apple Watch** shows the alarm too. The system does this, so it needs no Watch app.
- **Stopping an alarm is confirmed.** People stop alarms by reflex, and Stop counts as Done. So
  stopping the alarm marks it done, and the app sends an ordinary notification at once: "Marked
  done: Blood-pressure pill. Not done yet?", with **Not Done**. (The stop intent only records Done;
  the app's reconciler sends the notification. See the architecture spine, AD-12.) Not Done stops
  working on it once Not Done no longer applies ([§3](#3-product-concepts)), and the app removes it the next time it runs
  after that, or at once when Not Done is used. Stopping the alarm on a paired Watch does the same.
- **The notification chain** (iOS 18, and whenever alarms aren't allowed) starts each time an
  occurrence enters Urgent: its first Urgent nudge, the end of quiet hours, the end of a snooze, and
  Not Done, except Not Done after the give-up limit, whose one extra nudge is a single notification
  ([§3](#3-product-concepts)). This is the one list of when a chain starts. It sends a Time Sensitive notification at once and then every minute, 10 in all.
  - The strength's Urgent nudges that fall inside a chain still count on schedule, so the nudge
    count and the give-up time are the same as with alarms. They aren't sent as extra
    notifications: the chain's notification for that minute shows the current nudge number.
  - The repeats don't count toward the nudge limit, but their time counts toward the time limit.
  - Snooze, Done or the start of quiet hours ends the chain.
- **Quiet hours apply at once.** Changing them reschedules the nudges and alarms of every open and
  coming-up occurrence, and so does turning a reminder's **Ignore Quiet Hours** on or off. A
  reminder that ignores quiet hours can ring alarms at night.
- **Closing an occurrence clears its nudges.** However it closes, nothing more is sent for it: the
  app plans every nudge ahead, so the last one is the last one scheduled. Its pending notifications,
  alarms and Live Activity are cancelled, and its delivered notifications are removed, as soon as
  the app runs. When an occurrence closes on its own (at the give-up limit, or when the next one
  takes over), the app isn't running, because no app code runs when a nudge arrives, so its
  delivered notifications stay until the app next runs. The Done follow-up is the only exception.
  An action from a notification, alarm or Live Activity whose occurrence has already closed does
  nothing.
- **A snooze never outlasts its occurrence.** If a snooze on an alarm would end after the next
  occurrence takes over, or inside quiet hours for a reminder that doesn't ignore them, the app
  replaces the system's countdown with an alarm at the right time, or none.
- **When the system's limits are reached.** The app schedules within the limits in the table
  below, and tops up whenever it runs (see [§10](#10-risks-and-decisions) for what's still to
  confirm).
- **Weaker fallbacks show.** With alarms not allowed, Urgent nudges come as a notification chain;
  an Urgent nudge that can't get an alarm because of the system's limit comes as a Time Sensitive
  notification. The nudging card and How It Nudges mark any nudge that arrives a weaker way than
  its urgency, and say why.
- Snooze disappears from the card, the notification and the alarm once the occurrence has no
  snoozes left.
- If notifications or alarms are turned off in iOS Settings, Now and Settings show a banner that
  says what that means. The two permissions are separate: with notifications off and alarms
  allowed, only Urgent nudges reach the person. A nudge that can't be delivered still counts: the
  occurrence's nudges and give-up limit run on schedule, so it closes as missed at its limit
  rather than nudging forever, and its history shows each nudge that couldn't be sent.
- **Time Sensitive can be turned off on its own.** The person can turn it off for the app, and iOS
  asks from time to time whether the app's Time Sensitive notifications are worth it. Then every
  nudge that would be Time Sensitive (High nudges, the notification chain, and Urgent nudges past the
  alarm limit) arrives as an ordinary notification, which a Focus holds. This is the one statement of
  that rule: wherever the brief, the spines or the mockup README say a nudge is Time Sensitive, they
  mean when Time Sensitive is on. The app reads `timeSensitiveSetting` and shows a banner on Now
  and Settings, like the other permissions.
- **Privacy:** notifications show the title and a second line with the nudge count and urgency
  ("Nudge 3 of 20 · High"), under the app's icon. Alarms show only the title, since
  AlarmKit has no room for more. Notes and tags stay in the app. If the person hides notification
  previews in iOS Settings, the Lock Screen shows only the app's name.

**System limits:**

| Limit | Value | How the app works within it |
|---|---|---|
| Pending notifications | 64 per app. iOS keeps the soonest 64 and drops the rest without an error. | Keeps its own count. Slots go first to nudge 1 of each coming-up occurrence, soonest first, then to the remaining nudges, soonest first. 1 slot is kept for an "Open Nudge-inator to keep nudging" notification, at the time its scheduled nudges run out. |
| Notification chain (iOS 18, or alarms not allowed) | Up to 10 pending at once | Counts toward the 64 |
| Alarms | Not published. Scheduling fails with `maximumLimitReached`. | Slots go soonest first. The app remembers how many it could schedule and plans within that. An Urgent nudge that can't get an alarm comes as a Time Sensitive notification. |
| Alarms per occurrence | Firm and Relentless: 17 at the default limit (nudges 4–20), up to 97 at the 100-nudge maximum | Counts toward the alarm limit |

## 5. Devices, orientations and iOS versions

**Devices.** iPhone, in portrait and landscape. In v1, iPad runs the iPhone app, and v2 gives it its
own layout (decided in the UX work, 2026-10-02). Each device keeps its own reminders: nothing syncs,
so someone using an iPhone and an iPad has two separate lists, each nudging for its own reminders.

**iOS versions.** The app supports **iOS 18 and later** and is tested on **iOS 18, iOS 26 and
iOS 27**, on iPhone, and on iPad running the iPhone app.

| | iOS 18 | iOS 26 and 27 |
|---|---|---|
| Appearance | iOS 18's standard bars and tab bar, without Liquid Glass, as in the mockup's iOS 18 view: Search is a fifth tab, sheet buttons are words, section headers are in capitals, and confirmations are action sheets at the bottom | Liquid Glass, as in the mockup: a Search circle, symbols for sheet buttons, title-case headers, and confirmation dialogs that grow out of their button |
| Resizable window | Not available | iOS 27 only: an iPhone app can be resized (iPhone Mirroring, an iPhone app on iPad). The layout follows the width. |
| Urgent nudges | See [§4](#4-how-nudges-reach-you) | See §4 |
| iPhone in landscape | My Day's date stays in the content, as in portrait, and the tab bar doesn't shrink. The APIs for both (`navigationSubtitle`, `tabBarMinimizeBehavior`) are iOS 26 and later. | As in the mockup |
| Assistive Access | The app's own one-screen view, shown full screen (see [§6](#6-features)) | The system's Assistive Access scene |
| Everything else | Same screens, layouts and behavior | Same |

**Visual reference and where it changes.** The mockup shows an iPhone in portrait and landscape.
The app keeps its screens, text styles, colors, symbols and behavior everywhere, and changes only
the layout:
- **System components draw the chrome.** The tab bar, navigation bars, sheets, alerts and Search
  are the system's own, so they get Liquid Glass on iOS 26 and later and the classic look on
  iOS 18 without separate designs.
- **iPhone in landscape (in the mockup).** In landscape the screen is short, so the layout saves
  height:
  - inline titles instead of large ones, and content at a readable width
  - the tab bar shrinks to the current tab while you scroll down
  - My Day's date moves under the title and Filter into the navigation bar, and its counts become
    one row
  - nudge cards that are wide enough put Done and Snooze beside the text
  - sheets fill the screen
  - nudges arrive over the app, because the iPhone is in use (see [§4](#4-how-nudges-reach-you))
- **One column on every iPhone.** The iPhone app has no split view, even where the larger iPhones
  are regular width in landscape. Layouts depend on the available width, never on the iPhone model,
  so iOS 27's resizable windows need nothing extra.
- **iPhone Duo.** Treated like any iPhone: one column, folded and unfolded, with the layout
  following the width. What's on screen survives folding and unfolding. Check it on a device at
  both sizes.
- **iPad (v2).** In v1, iPad runs the iPhone app in a window whose layout follows its width, as
  iOS 27's resizable windows do. Keyboard shortcuts (⌘N, ⌘F, ⌘1 to ⌘4) work with a hardware
  keyboard. v2 adds an iPad layout:
  - a two-column layout (`NavigationSplitView`) for Tags, Search and Settings
  - the tab bar floating at the top, as iPadOS 18 and later draw it, or as a sidebar
  - centered form sheets, and every window size

  The addendum has the layout notes.
- **Accessibility text sizes** keep the mockup's stacked layouts in every orientation.
- **The alarm** is drawn by the system (see [§4](#4-how-nudges-reach-you)). The mockup shows it
  that way, but its layout is an approximation of iOS's.

## 6. Features

| Screen | Features |
|---|---|
| **Now** | Nudging cards with the urgency word (High or Urgent), **Done**, **Snooze** (snoozes left), the next nudge and how it arrives, and **Undo** right after Done. Coming Up (7 days) with quiet-hours and "starts higher" notes. Last 24 Hours, where a reminder done by stopping its alarm offers **Not Done**. Quiet-hours chip, permission banners (each with **Open Settings** and **Got It**, and a link to How Nudges Work), and a badge on the tab. |
| **My Day** | Today in time order, with Now and quiet-hours markers. Done, Nudging, Missed and Left counts that filter the list. **Filter by Tags**: one or more tags, Match All or Any, or No Tags. |
| **Tags** | Your tags with counts. Find tags and choose one or more as tokens, then Match All or Any. Results in Today, Later, Paused and Completed. **Edit** renames or deletes tags (deleting keeps the reminders). |
| **Search** | Every reminder by title, notes or tag, with recent searches. |
| **Reminder details** | Nudging card, tags (tap to filter), schedule, How It Nudges, history (90 days), **Not Done** (on the latest done occurrence, while it applies; see [§3](#3-product-concepts)), **Pause/Resume**, **Delete** (confirmed), **Edit**. |
| **New / Edit** | Title (wraps), notes, tags (choose or add), start, Repeat (presets and Custom, which can repeat several times a day), time zone (Follow iPhone or a chosen zone), strength, snooze length, give-up limits (with a minimum per strength), **Ignore Quiet Hours**, and a live How It Nudges preview, which shows where a repeat's next occurrence takes over. While a reminder is nudging, Edit says when each change applies. Every repeat rule can be shown and edited in the form. |
| **Settings** | Notification and alarm status, Open iOS Settings, Send a Test Nudge. Quiet hours (in the iPhone's time zone). Time zone for new reminders (Follow iPhone or a chosen zone). Siri & Shortcuts. Export Data (a readable record, not a backup) and Delete All Data. **How Nudges Work** (strengths, urgency, Focus, quiet hours, alarms), the one help page every permission banner links to. About and Accessibility. |
| **First launch** | Welcome, then the notification permission, then (on iOS 26 and later) the alarm permission. After an update from iOS 18, the alarm permission is asked once on the next launch. |
| **Siri and Shortcuts** | "Mark my Nudge-inator nudge done", "Snooze Nudge-inator" and "What's nudging me in Nudge-inator?" (Apple requires the app's name in every App Shortcut phrase), from Siri, the Action button or a Home Screen shortcut. |
| **Assistive Access** | One screen: what needs you now, with large Done and Snooze buttons; what's done today, with **Not done yet**; and what's later today. No editing, tags or settings. On iOS 26 and later it's an Assistive Access scene, drawn in the system's Assistive Access style. On iOS 18, where that scene doesn't exist, the app shows the same view full screen (`UISupportsFullScreenInAssistiveAccess`) when `isAssistiveAccessEnabled` is on. |

**Not in this release:** an iPad layout (iPad runs the iPhone app), Android, Mac, an Apple Watch app (alarms still show on a paired Watch), Home Screen widgets (the Live Activity that
AlarmKit uses for a snoozed alarm is included), sync between devices, accounts,
sharing reminders with other people, in-app purchases, and languages other than English. Nor is
importing exported data: iCloud and computer backups already restore everything, and an import
format would have to stay compatible from version to version.

## 7. Principles

- **Follows Apple's Human Interface Guidelines.** The mockup was reviewed against the Icons,
  Typography, Color, Dark Mode, Accessibility and Materials pages (local copies in
  `docs/apple/design/`, which isn't in the repo), and the app
  keeps those decisions: SF Symbols, the built-in text styles, semantic and accent colors with
  light, dark and Increase Contrast variants, and system materials.
- **Accessible.**
  - Dynamic Type from xSmall to AX5, Bold Text, Increase Contrast, Reduce Transparency, Reduce
    Motion and Dark Mode.
  - VoiceOver, with filter and search results announced. Voice Control, Full Keyboard Access and
    Switch Control.
  - 44 pt targets, and no gestures required.
  - Nothing on a timer, and nothing shown by color alone.
  - Assistive Access.
  - The App Store Accessibility Nutrition Labels declare VoiceOver, Voice Control, Larger Text,
    Dark Interface, Differentiate Without Color Alone, Sufficient Contrast and Reduced Motion.
    Captions and Audio Descriptions don't apply, since the app has no video or audio content.
- **Ready for other languages.** English is the only language at launch, but the app is built so
  that adding one is translation work, not code changes. All text is in string catalogs with
  plural rules, dates and numbers use the system's formatters, and layouts mirror for
  right-to-left languages. The person's own text (titles, notes, tag names) is never translated.
  The addendum has the full checklist.
- **Private.** Reminders stay on the device. They're included in the person's iCloud or computer
  backup, which is how they're restored. After a restore, nudging resumes once the app is opened. They can be exported as a readable record, or deleted.
  There are no analytics or trackers.
- **Predictable and testable.** Given the reminders, their history and a clock, the nudges are
  fully determined, including quiet hours, daylight saving changes, Snooze, carry-over, overlapping
  occurrences, edits while nudging, the give-up limit and which nudges get the system's slots. The "How It Nudges" preview and what's actually scheduled come from the same rules, which
  can be tested with a fixed clock.

## 8. Success measures

| Measure | Target |
|---|---|
| **People rely on it** | The owner and at least 3 testers use it daily for 4 weeks. |
| **Nudging works** | Nudges arrive within 1 minute of their scheduled time. In testing, no notification or alarm arrives after Done for the same occurrence. Snooze and Clear behave as specified on iOS 18, 26 and 27. |
| **Every device and orientation** | Every screen works in portrait and landscape on iPhone, and on iPad running the iPhone app, on all 3 iOS versions, with no clipped or cut-off text at any Dynamic Type size. |
| **Accessible** | VoiceOver, Voice Control and Dynamic Type pass on every screen, tested with Accessibility Inspector and on real devices. |
| **Ready to translate** | A pseudo-localized build shows no hard-coded strings and no clipped layouts. |

## 9. Costs and constraints

- **Cost:** the Apple Developer Program, $99 a year. There's nothing else to pay for.
- **Constraints:** iPhone only in v1 (iPad runs the iPhone app), iOS 18 and later. English only at launch. No server, so
  every nudge has to come from the device itself.

## 10. Risks and decisions

**Risks to confirm on real devices:**
- **How many alarms an app can schedule.** A Firm or Relentless occurrence uses many alarms (see
  the system limits in [§4](#4-how-nudges-reach-you)). AlarmKit has a limit, but Apple doesn't
  publish it. When it's reached, the app falls back to Time Sensitive notifications for the alarms it couldn't schedule, and says so (see [§4](#4-how-nudges-reach-you)).
- **How many notifications an app can schedule.** The limit of 64 pending local notifications per
  app is documented only on the deprecated `UILocalNotification` page: "the system keeps the
  soonest-firing 64 notifications … and discards the rest". The current UserNotifications docs
  don't state it. Extra requests are dropped silently, with no error, so the app keeps its own
  count. §4 says which nudges get the slots. Confirm the limit on iOS 18, 26 and 27.
- **People turning off Time Sensitive.** iOS explains Time Sensitive notifications the first time
  one arrives, offers to turn them off, and asks again from time to time. Apple's guidance is to use
  them for events "happening now or will happen within an hour". If people turn them off, Focus
  holds every early nudge. Sending only High nudges as Time Sensitive keeps their number down (see
  the decision below). Watch for it during TestFlight.
- **Normal nudges held by a Focus.** Watch in TestFlight whether testers on Gentle or Firm miss
  first nudges during a Focus.
- **Stop and Snooze on an alarm when the app isn't running.** AlarmKit runs the app's own App
  Intents for an alarm's buttons without opening the app. The intents only record Done or Snooze;
  the app's reconciler then cancels the remaining alarms, moves them after a snooze and enforces
  the 3-snooze limit (architecture spine, AD-12). Confirm this still works after the app has been
  force-quit.
- **Snooze before the first unlock.** After a restart, the alarm can ring before the device has
  been unlocked. Snooze still counts down, but Apple says the app's snooze intent only runs after
  the first unlock, so the snooze isn't counted and the later alarms aren't moved until the app next
  runs. Then it counts the snooze and moves the later alarms (architecture spine, AD-6).
- **The alarm can't say Done.** From iOS 26.1 the stop control is the system's own. Confirm in
  testing that people understand that stopping the alarm marks the reminder done.
- **Alarms with notifications off.** Apple documents the alarm permission as separate from
  notifications. Confirm that alarms still ring when notifications are turned off.
- **Keeping future nudges scheduled if the app isn't opened for days.** Background refresh isn't
  guaranteed, so the app schedules a rolling window ahead.
- **App Review and alarms.** Apple says alarms are "not a replacement for … time-sensitive
  notifications". Using them only for Urgent nudges follows that.
- **The iOS 18 chain is weaker.** Silent mode can mute it, so Urgent nudges are less forceful on
  iOS 18.
- **How the alarm looks.** Apple describes it only as a prominent alert, on the Lock Screen, in the
  Dynamic Island and in StandBy. Confirm how it presents on an unlocked iPhone, including in
  landscape, where the mockup's banner at the top is a guess, and on iPhones without a Dynamic
  Island. Confirm it on iPad too (AlarmKit supports iPadOS 26), and that it sounds there as it does
  on iPhone.
- **Losing the device loses the reminders,** unless it's restored from an iCloud or computer backup.
  Export Data is a readable record, not a backup: it can't be imported.
- **Restoring a backup probably doesn't restore what's scheduled.** Pending notifications and
  alarms seem to belong to the device, so a restored or new iPhone may not nudge until the app is
  opened once; then it reschedules everything. Apple doesn't document this. Confirm on a device.
- **Nothing runs when a nudge arrives.** The app plans every nudge ahead, so what it shows is
  always right, but a closed occurrence's delivered notifications stay until the app next runs.
  Background refresh helps, but isn't guaranteed.

**Device checks that replace earlier questions:**
- **Navigation bars at large text sizes.** The app uses the system's navigation bar as it is: large
  titles grow with Dynamic Type, and inline titles and bar buttons keep their size and use the Large
  Content Viewer, as in the mockup. Confirm this on a device at the accessibility sizes.
- **The selected tab's color.** The system draws the tab bar's selected state from the TabView's
  tint, the accent, so the app can't color it on its own. The accent is now Lagoon teal (decided in
  the UX work, 2026-10-03), which passes on the mockup's pill in every appearance: 5.4:1 light,
  6.5:1 dark, and 7.4:1 and 7.2:1 with Increase Contrast. Measure it on the system's pill on a
  device before the App Store listing declares Sufficient Contrast.
- **What the mockup can't know about the system's drawing.** Whether the search field's clear
  button removes tokens and Cancel keeps them, what iOS 26's Search tab shows to end a search, the
  notification's layout, and iOS 26's alerts (the mockup's README lists them under "iOS versions").
  Apple's documentation confirms the rest: iOS 26's confirmation dialog has no Cancel when it's
  attached to its button, and a search scoped to one tab goes under the title.
- **Many tags on one reminder.** There's no limit on tags per reminder. Test rows, nudge cards and
  the details with 10 or more tags.

**Device checklist.** This is the one list of checks to run on real devices before TestFlight and
the App Store. The architecture spine and EXPERIENCE.md point here, and each item names the
decision or section it affects.

- *Alarms and notifications*
  - The AlarmKit alarm limit (risk above; AD-11's `alarmCapacity`).
  - The 64-notification limit on iOS 18, 26 and 27 (risk above; AD-14).
  - Cancelling an alarm during its snooze countdown, and reusing alarm IDs (AD-12, and its `.custom`
    fallback).
  - Stop and Snooze after the app has been force-quit, including Stop on a paired Watch (risk
    above; AD-12).
  - Stop, Snooze and Done before the first unlock: the journal and the follow-up (risk above;
    AD-16).
  - Alarms with notifications off (risk above).
  - An alarm that rings out: AlarmKit doesn't report it as a stop
    ([EXPERIENCE › Nudge Surfaces](../design/EXPERIENCE.md#nudge-surfaces)).
  - How the alarm presents: on an unlocked iPhone, as a banner over the app in landscape, in the
    Dynamic Island over another app, and in StandBy (risk above; EXPERIENCE Flow 3).
  - Alarms, Time Sensitive notifications and the Live Activity under Assistive Access
    ([EXPERIENCE › Assistive Access](../design/EXPERIENCE.md#assistive-access)).
  - Restoring from a backup: whether nudging resumes before the app is opened (risk above; AD-15).
- *Screens*
  - Navigation bars at the accessibility sizes (above).
  - The selected tab's contrast on the system's glass pill (above; the accessibility release gate).
  - What the mockup can't know about the system's drawing (above).
  - Rows, nudge cards and details with 10 or more tags (above).
  - Token selection and deletion in the Tags tab's field
    ([EXPERIENCE › Tag token field](../design/EXPERIENCE.md#tag-token-field)).
  - Folding and unfolding the iPhone Duo, at both sizes
    ([EXPERIENCE › Responsive & Platform](../design/EXPERIENCE.md#responsive--platform)).
- *Accessibility release gate* (before the App Store listing declares its Accessibility Nutrition
  Labels; [EXPERIENCE › Accessibility Floor](../design/EXPERIENCE.md#accessibility-floor)): an
  Accessibility Inspector audit, then VoiceOver, Voice Control and Switch Control on the common
  tasks, at Large and AX5, in light, dark and Increase Contrast.

**Decided (2026-10-01):**
- **My Day and the Tags tab keep separate filters.** My Day shows what's due today among the chosen
  tags; the Tags tab browses every reminder.
- **My Day's counts filter one at a time.**
- **Match All Tags is the default.** Adding a tag narrows the list, as in Mail and Reminders. Watch
  for confusion during TestFlight.
- **Tags have no colors in v1.** Revisit if testers ask for them.
- **The tab bar shrinks while scrolling only in landscape.** Portrait has room for it, and people
  switch tabs often.

- **Release on the App Store once the success measures are met** (see
  [§8](#8-success-measures)) over a four-week TestFlight beta with external testers. The first beta
  build goes through Beta App Review, an early test of using alarms for reminders.
- **Normal nudges are ordinary notifications; only High nudges are Time Sensitive.** This matches
  Apple's interruption levels to the app's urgency, makes the app less likely to have Time Sensitive
  turned off, and fits the strengths. The cost is that a Focus holds Normal nudges (see
  [§4](#4-how-nudges-reach-you)).

**Decided (2026-10-02):**
- **Carry-over sends Normal nudges at High, once.** It gets the next occurrence through a Focus
  without changing its intervals, so it never rings an alarm on nudge 1. Relentless has no Normal
  nudges, so it has no carry-over. Pausing clears it.
- **The next occurrence takes over.** A reminder has at most 1 open occurrence, so nudges are always
  about the current time and fewer are scheduled. A frequent repeat restarts at nudge 1 each time,
  and every handover counts as missed.
- **Quiet hours stop the clock, and a reminder can ignore them.** Nothing gives up overnight, and
  1 nudge is sent when they end. **Ignore Quiet Hours** is for medication and caregiving reminders
  that must nudge at night.
- **Give-up limits have a minimum per strength,** so the limit can't end an occurrence before its
  first High nudge, which gets through a Focus. A short window means Firm or Relentless, not Gentle.
- **Changes while nudging apply now, and Done can be undone.** A new strength or limit applies from
  the next nudge, and a new schedule from the next time it's due. **Not Done** reopens the latest
  done occurrence while it applies ([§3](#3-product-concepts)), because the alarm's Stop counts as Done and can't
  be labelled.
- **Export Data is a record, not a backup.** There's no Import in this release (see
  [§6](#6-features)). Device backups restore everything.
- **First nudges get the notification slots first.** A reminder that never nudges is the worst
  failure, so every coming-up occurrence's nudge 1 is scheduled before anyone's later nudges.

**Decided in the UX review (2026-10-02),** so that the mockup shows only what the app can build on
iOS 18, 26 and 27:
- **The mockup shows iOS 18, 26 and 27,** each with its own system appearance, and iOS 18's
  notification chain instead of alarms.
- **No Dismiss action on notifications.** The system's Clear does the same. The app records an
  explicit Clear through its notification category's `customDismissAction` option; a banner flicked
  away isn't reported to the app, so it isn't recorded.
- **The Tags tab's chosen tags are tokens in its search field** (`searchable` with tokens). The
  tags not chosen yet stay listed under the results, because Apple warns that tokens are easy to
  miss and shouldn't replace visible filter controls.
- **Menus replace segmented controls at the accessibility sizes,** because a segmented control
  can't stack its options.
- **One column on every iPhone.** The larger iPhones' split view waits for the iPad layout in v2.
- **Swipe actions for Done and Snooze** on nudging rows and cards, as shortcuts for their buttons.
- **The selected tab uses the accent,** as the system draws it (see the device check above).

**Decided in the UX work (2026-10-02 and 2026-10-03),** recorded in the
[design decision log](../design/.memlog.md) and specified in the [UX spines](../design/):
- **iPhone only in v1.** iPad runs the iPhone app; its own layout (split view, sidebar, form sheets)
  waits for v2.
- **The iPhone Duo is treated like any iPhone:** one column, folded and unfolded, laid out by width.
  This settles the earlier open question.
- **The accent is Lagoon teal** (#04666B light, #07DDE6 dark), replacing the system-like blue, which
  fell short on the selected tab's pill.
- **Snooze length is set per reminder:** the strength's default or longer (5, 10, 15 or 30 min). The
  3-snooze cap stays. This gives people who need more time a way to get it.
- **Stopping an alarm is confirmed.** A Done follow-up notification offers **Not Done** at once, and
  the done row on Now and My Day and Assistive Access offer it too.
- **Done has an Undo,** and swipe actions need a tap after the swipe, so a stray swipe can't mark a
  reminder done.
- **Urgency shows as a word and a glyph** on nudge cards, not just their color, because High's orange
  and Urgent's red are hard to tell apart.

**Decided in the architecture (2026-10-03),** recorded in the
[architecture decision log](../architecture/.memlog.md):
- **The nudging rules live in one engine.** The preview, the scheduler, history and Siri all get
  their answers from it, and it's tested with a fixed clock.
- **A reminder follows the iPhone's time zone,** unless it's set to stay in a chosen zone. Quiet
  hours always follow the iPhone.
- **Repeat rules are only what the form can show.** "Keep: …" for rules the form can't express is
  gone, since nothing on the device can create one. Custom can repeat several times a day.
- **With alarms not allowed, Urgent nudges come as the notification chain,** as on iOS 18. Only a
  nudge past the system's alarm limit comes as a single Time Sensitive notification.
- **The chain starts each time an occurrence enters Urgent** ([§4](#4-how-nudges-reach-you) lists when), and covers the Urgent nudges inside
  it (see [§4](#4-how-nudges-reach-you)).
- **Done and Snooze work from the Lock Screen without Face ID,** as Stop does on an alarm.
- **Filters on My Day and the Tags tab survive iOS closing the app in the background,** and reset
  when the person closes the app.

There are no open questions left in this brief.

## 11. Questions for the architecture

All of these are answered in the [architecture spine](../architecture/ARCHITECTURE-SPINE.md), which
maps each one to its decisions under "Capability → Architecture Map".

1. SwiftUI, UIKit or both, and how the app adapts to landscape and to iOS 27's resizable windows
   (iPad's own layout is v2).
2. How reminders, occurrences and history are stored on the device, and how the data model migrates
   between app versions.
3. How the nudging rules are shared between the preview, the scheduler and tests, so they can't
   drift apart.
4. How notifications and alarms are scheduled within the system limits in §4, and how far ahead. How the slot order in §4 is kept as nudges fire, and
   how quiet hours, Ignore Quiet Hours and edits reschedule what's pending at once.
5. How Done and Snooze run from notifications, alarms, Siri and Shortcuts (App Intents), with or
   without the app open, and how an explicit Clear (`customDismissAction`) is recorded. For alarms: Snooze uses AlarmKit's own countdown, but an alarm
   that rings again keeps its buttons, so the third snooze has to replace that alarm with one
   without Snooze, and every snooze has to move the occurrence's later alarms. iOS 27's `.clock`
   App Intents domain has a `snoozeAlarm` schema for Siri, but an app that adopts one schema in the
   domain has to support them all, including creating alarms, so it probably doesn't fit.
6. How the alarm's Live Activity extension is set up, with the system countdown presentation as
   its fallback before the first unlock, and how the app reconciles its scheduled alarms with
   AlarmKit's list (`alarms` and `alarmUpdates`) and its permission (`authorizationUpdates`) on
   every launch.
7. How alarms follow time zones. A fixed alarm doesn't move when the device's time zone changes, so
   reminders that follow the device's time zone need their alarms rescheduled when it changes.
8. How the iOS 18 and iOS 26+ paths are separated and tested: Urgent nudges, Assistive Access, and
   the iOS 26-only layout APIs (`navigationSubtitle`, `tabBarMinimizeBehavior`).
9. How strings, plurals and formats are set up so that adding a language needs no code changes.
10. How the app is tested on iOS 18, 26 and 27, on iPhone and on iPad running the iPhone app, in
    both orientations.
11. How an occurrence that closes while the app isn't running (at the give-up limit, or when the
    next one takes over) has its delivered notifications and Live Activity removed, and how the app
    knows an action came from an occurrence that has already closed.
12. What format Export Data uses (the mockup shows a JSON file), so the record can be read without
    the app.
13. How the Done follow-up notification is sent without opening the app, and how it's removed when
    the next occurrence falls due. (Sending is answered in the architecture spine: the stop intent
    only records Done and the reconciler sends the follow-up, AD-12; before the first unlock the
    intent posts it itself, AD-16.)
14. Whether My Day's and the Tags tab's filters survive a relaunch. (Answered: they're restored
    after iOS ends the app in the background, and reset when the person closes it.)
