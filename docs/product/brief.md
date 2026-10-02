---
title: "Product Brief: Nudge-inator"
status: draft
created: 2026-09-29
updated: 2026-10-01
source: docs/mockups/2026-09-30-mockup-tags (index.html and README.md)
---

# Product Brief: Nudge-inator

Nudge-inator is a reminders app for **iPhone and iPad**, built for iOS and iPadOS only, that keeps
nudging until you tap **Done**.

The [tags mockup](../mockups/2026-09-30-mockup-tags/index.html) is the visual reference for the app.
Its [README](../mockups/2026-09-30-mockup-tags/README.md) explains the reasons behind it and how it
was checked against Apple's Human Interface Guidelines. The app looks and behaves like the mockup.
It shows an iPhone in portrait and landscape. The app differs only where something the mockup
doesn't show needs a different choice: iPad, and iOS 18's system appearance (see
[§5](#5-devices-orientations-and-ios-versions)).

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

Early nudges are Time Sensitive notifications. On iOS 26 and later, the final, Urgent nudges ring as
**AlarmKit alarms**: prominent system alerts that sound through silent mode and Focus. On iOS 18, a minute-by-minute chain
of notifications stands in. You organize reminders with **tags**, as many as each reminder needs,
and filter by one or more tags on the Tags tab and on My Day.

The app runs entirely on the device: no sign-up, no data leaving the phone, and no running costs
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
| **Reminder** | Something to be nudged about: a title (required, up to 200 characters), optional notes (up to 2,000, shown only in the app), any number of tags, a start time, a time zone, a repeat rule, a strength and a give-up limit. |
| **Occurrence** | One time a reminder falls due. It's **coming up**, then **nudging**, then closes as **done**, **missed** or **skipped**. Each has an event history, kept for 90 days. |
| **Nudge** | One alert sent while an occurrence is open: a notification or an alarm. |
| **Strength** | Gentle, Firm or Relentless. It sets the intervals and how urgency rises (table below). |
| **Urgency** | Normal, High or Urgent. It rises as nudges go unanswered and decides how a nudge arrives ([§4](#4-how-nudges-reach-you)). |
| **Give-up limit** | After a number of nudges (1–100, default 20) or a time (15 minutes to 7 days, default 24 hours), whichever comes first, the occurrence stops and counts as **missed**. |
| **Quiet hours** | A daily window, such as 10 PM to 7 AM. Nudges wait until it ends, nothing escalates and no alarms ring. |
| **Carry-over** | After a missed occurrence, the next one starts a level higher ("↑ Starts higher"). |
| **Tag** | A one-word label shown as `#home`, with no color. A reminder can have any number of tags or none. Names are unique, ignoring case. |
| **My Day** | Everything due today in time order, with Done, Nudging, Missed and Left counts. Filter by one or more tags (All or Any, or No Tags), and tap a count to show only that status. |
| **Snooze** | A fixed break by strength (Gentle 30 minutes, Firm 15, Relentless 5), up to 3 times per occurrence. It doesn't raise the level, and snoozed time doesn't count toward the limit. |
| **Dismiss** | Clears one notification. Nudging continues. |
| **Done** | The only thing that stops nudging. It cancels the occurrence's remaining notifications and alarms. On an alarm, it's the system's **Stop** control. |
| **Pause** | Stops a reminder. Anything due while it's paused is **skipped**, not missed, so there's no carry-over. Resume picks up at the next time. |

| Strength | Intervals between nudges | Urgency | With the default limit |
|---|---|---|---|
| **Gentle** | 60, 45, 34, 25 min, then every 20 | Normal, High from nudge 5. Never Urgent. | 20 nudges over about 8 hours |
| **Firm** | 30, 15, 7.5 min, then every 5 | Normal, High at nudge 3, Urgent from nudge 4 | 20 nudges over about 2 h 20 min |
| **Relentless** | 10, 5, 2.5 min, then every 2 | High, Urgent from nudge 4 | 20 nudges over about 50 min |

## 4. How nudges reach you

| Nudge | iOS 26 and later | iOS 18 |
|---|---|---|
| Normal and High | **Time Sensitive notification** with **Done**, **Snooze** and **Dismiss** | Same |
| Urgent (Firm and Relentless, from nudge 4) | **AlarmKit alarm**: a prominent system alert that rings and vibrates through silent mode and Focus, with **Snooze** and the system's **Stop**, which counts as Done | **Notification chain**: when the occurrence first reaches Urgent, a Time Sensitive notification every minute, up to 10. Then Urgent nudges follow the strength's interval. Silent mode can mute them. |
| Urgent, with alarms not allowed | Time Sensitive notifications | n/a |

- Gentle reminders never reach Urgent, so they never ring an alarm.
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
- The iOS 18 chain repeats the current nudge. The repeats don't count toward the nudge
  limit, but their time counts toward the time limit. Snooze or Done ends the chain.
- Snooze disappears from the card, the notification and the alarm after 3 snoozes.
- If notifications or alarms are turned off in iOS Settings, Now and Settings show a banner that
  says what that means. The two permissions are separate: with notifications off and alarms
  allowed, only Urgent nudges reach the person.
- **Privacy:** notifications and alarms show only the title (and the app's name). Notes and tags
  stay in the app.

## 5. Devices, orientations and iOS versions

**Devices.** iPhone and iPad, both in portrait and landscape. Each device keeps its own reminders:
nothing syncs, so someone using both has two separate lists, each nudging for its own reminders.

**iOS versions.** The app supports **iOS 18 and later** and is tested on **iOS 18, iOS 26 and
iOS 27**, on iPhone and iPad.

| | iOS 18 | iOS 26 and 27 |
|---|---|---|
| Appearance | iOS 18's standard bars and tab bar, without Liquid Glass | Liquid Glass, as in the mockup |
| Urgent nudges | See [§4](#4-how-nudges-reach-you) | See §4 |
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
- **Larger iPhones in landscape (in the mockup).** The iPhones 414 pt wide or more, such as the Plus
  and Max models, are regular width in landscape. There, Tags, Search and Settings show their list
  and the chosen item side by side, and fold back to one column in portrait.
- **iPad.** It starts from the larger iPhones' two-column layout. The tabs can become a sidebar,
  sheets are centered form sheets, and every window size and keyboard shortcuts (⌘N, ⌘F) are
  supported.

  The addendum has the full layout notes.
- **Accessibility text sizes** keep the mockup's stacked layouts in every orientation.
- **The alarm** is drawn by the system (see [§4](#4-how-nudges-reach-you)). The mockup shows it
  that way, but its layout is an approximation of iOS's.

## 6. Features

| Screen | Features |
|---|---|
| **Now** | Nudging cards with **Done**, **Snooze** (snoozes left), the next nudge and how it arrives. Coming Up (7 days) with quiet-hours and "starts higher" notes. Last 24 Hours. Quiet-hours chip, permission banners, and a badge on the tab. |
| **My Day** | Today in time order, with Now and quiet-hours markers. Done, Nudging, Missed and Left counts that filter the list. **Filter by Tags**: one or more tags, Match All or Any, or No Tags. |
| **Tags** | Your tags with counts. Find tags and choose one or more as tokens, then Match All or Any. Results in Today, Later, Paused and Completed. **Edit** renames or deletes tags (deleting keeps the reminders). |
| **Search** | Every reminder by title, notes or tag, with recent searches. |
| **Reminder details** | Nudging card, tags (tap to filter), schedule, How It Nudges, history (90 days), **Pause/Resume**, **Delete** (confirmed), **Edit**. |
| **New / Edit** | Title (wraps), notes, tags (choose or add), start, Repeat (presets and Custom), time zone, strength, give-up limits, and a live How It Nudges preview. Rules the form can't express are kept as they are. |
| **Settings** | Notification and alarm status, Open iOS Settings, Send a Test Nudge. Quiet hours. Time zone (automatic or chosen). Siri & Shortcuts. Export Data and Delete All Data. About and Accessibility. |
| **First launch** | Welcome, then the notification permission, then (on iOS 26 and later) the alarm permission. |
| **Siri and Shortcuts** | "Mark my nudge done", "Snooze my nudge" and "What's nudging me?", from Siri, the Action button or a Home Screen shortcut. |
| **Assistive Access** | One screen: what needs you now, with large Done and Snooze buttons, and what's later today. No editing, tags or settings. |

**Not in this release:** Android, Mac, an Apple Watch app (alarms still show on a paired Watch), Home Screen widgets (the Live Activity that
AlarmKit uses for a snoozed alarm is included), sync between devices, accounts,
sharing reminders with other people, in-app purchases, and languages other than English.

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
  backup, and they can be exported or deleted. There are no analytics or trackers.
- **Predictable and testable.** Given a reminder, its history and a clock, the nudges are fully
  determined, including quiet hours, daylight saving changes, Snooze, carry-over and the give-up
  limit. The "How It Nudges" preview and what's actually scheduled come from the same rules, which
  can be tested with a fixed clock.

## 8. Success measures

- **People rely on it.** The owner and at least 3 testers use it daily for 4 weeks.
- **Nudging works.** Nudges arrive within a minute of their scheduled time. In testing, no
  notification or alarm arrives after Done for the same occurrence. Snooze and Dismiss behave as
  specified on iOS 18, 26 and 27.
- **Every device and orientation.** Every screen works in portrait and landscape on iPhone and iPad,
  on all three iOS versions, with no clipped or cut-off text at any Dynamic Type size.
- **Accessible.** VoiceOver, Voice Control and Dynamic Type pass on every screen, tested with
  Accessibility Inspector and on real devices.
- **Ready to translate.** A pseudo-localized build shows no hard-coded strings and no clipped
  layouts.

## 9. Costs and constraints

- **Cost:** the Apple Developer Program, $99 a year. There's nothing else to pay for.
- **Constraints:** iOS and iPadOS only, iOS 18 and later. English only at launch. No server, so
  every nudge has to come from the device itself.

## 10. Risks and decisions

**Risks to confirm on real devices:**
- **How many alarms an app can schedule.** A Firm or Relentless occurrence uses up to 17 alarms.
  AlarmKit has a limit (scheduling can fail with `maximumLimitReached`), but Apple doesn't publish
  it. When it's reached, the app falls back to Time Sensitive notifications for the alarms it
  couldn't schedule. Local notifications are limited to 64 pending per app, and the iOS 18 chain
  uses up to 10 of them at once.
- **Stop and Snooze on an alarm when the app isn't running.** AlarmKit runs the app's own App
  Intents for an alarm's buttons without opening the app, which is how it cancels the remaining
  alarms, moves them after a snooze and enforces the 3-snooze limit. Confirm this still works after
  the app has been force-quit.
- **Snooze before the first unlock.** After a restart, the alarm can ring before the device has
  been unlocked. Snooze still counts down, but Apple says the app's snooze intent only runs after
  the first unlock, so the snooze isn't counted and the later alarms aren't moved. The app
  reconciles on its next launch.
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
- **Which iPhones get two columns.** The mockup assumes the iPhone Air is regular width in
  landscape, like the other iPhones 414 pt wide or more. Apple doesn't list it, so confirm it on a
  device or in Simulator.
- **Losing the device loses the reminders,** unless it's restored from a backup. Export is the only
  other copy.

**Device checks that replace earlier questions:**
- **Navigation bars at large text sizes.** The app uses the system's navigation bar as it is: large
  titles grow with Dynamic Type, and inline titles and bar buttons keep their size and use the Large
  Content Viewer, as in the mockup. Confirm this on a device at the accessibility sizes.
- **The selected tab's color.** The system draws the tab bar's selected state from the accent
  color. Confirm it's legible in dark mode with Increase Contrast. The mockup's `#D8ECFF` reaches
  7.1:1 but looks pale.
- **Many tags on one reminder.** There's no limit on tags per reminder. Test rows, nudge cards and
  the details with 10 or more tags.

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

There are no open questions.

## 11. Questions for the architecture

1. SwiftUI, UIKit or both, and how the app adapts to size classes for landscape and iPad.
2. How reminders, occurrences and history are stored on the device, and how the data model migrates
   between app versions.
3. How the nudging rules are shared between the preview, the scheduler and tests, so they can't
   drift apart.
4. How notifications and alarms are scheduled within system limits (64 pending notifications, and
   AlarmKit's unpublished limit, reported as `maximumLimitReached`), and how far ahead.
5. How Done, Snooze and Dismiss run from notifications, alarms, Siri and Shortcuts (App Intents),
   with or without the app open. For alarms: Snooze uses AlarmKit's own countdown, but an alarm
   that rings again keeps its buttons, so the third snooze has to replace that alarm with one
   without Snooze, and every snooze has to move the occurrence's later alarms.
6. How the alarm's Live Activity extension is set up, with the system countdown presentation as
   its fallback before the first unlock, and how the app reconciles its scheduled alarms with
   AlarmKit's list (`alarms` and `alarmUpdates`) and its permission (`authorizationUpdates`) on
   every launch.
7. How alarms follow time zones. A fixed alarm doesn't move when the device's time zone changes, so
   reminders that follow the device's time zone need their alarms rescheduled when it changes.
8. How the iOS 18 and iOS 26+ paths for Urgent nudges are separated and tested.
9. How strings, plurals and formats are set up so that adding a language needs no code changes.
10. How the app is tested on iOS 18, 26 and 27, on iPhone and iPad, in both orientations.
