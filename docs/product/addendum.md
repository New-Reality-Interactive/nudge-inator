---
title: "Product Brief Addendum: Nudge-inator"
updated: 2026-10-01
---

# Product Brief Addendum: Nudge-inator

Detail behind the [brief](brief.md) that later documents (PRD, UX, architecture) will need, but that
doesn't belong in the brief itself. The rules in the brief come from the tags mockup: where they
disagree, its `index.html` is the reference for behavior, and its README for reasons.

## A. What the earlier brief had that this one drops

The 2026-09-29 brief described a website (v0), then an iOS app (v1), both built on a server API. On
2026-10-01 the owner chose **on-device only**, matching the tags mockup. These were
dropped entirely, not parked:

- the website, and the website-first release plan
- the API, the OpenAPI contract and contract-first delivery
- accounts, invitations, passkeys and recovery links
- email and SMS nudges, "Which nudges" routing, verification codes, SMS caps and Done links
- Cloudflare hosting and the monthly cost estimate (now just $99 a year)
- the criteria for going public that depended on a server (abuse, deliverability and SMS controls)

**Why:** with no server there's nothing to run, pay for or secure. The cost is that nudges can only
come from the device itself, so nothing can reach the person if the device is off or lost.

The earlier brief was never committed, so this list is the only record of it.

## B. iOS version matrix

| | iOS 18 | iOS 26 | iOS 27 |
|---|---|---|---|
| Normal and High nudges | Time Sensitive notification | Same | Same |
| Urgent nudges | Notification chain (every minute, up to 10, then the strength's interval) | AlarmKit alarm | AlarmKit alarm |
| Alarm permission prompt | None | On first launch, after notifications | Same |
| AlarmKit | Not available | Available (iOS and iPadOS 26.0+) | Available |
| Bars, tab bar and sheets | iOS 18 system look | Liquid Glass | Liquid Glass |
| Scroll edge effects | System default for iOS 18 | As in the mockup | As in the mockup |

The mockup's iOS 26 behavior is the target. On iOS 18, the app uses the same system components, so
it gets iOS 18's look without a separate design.

## C. Layout notes for landscape and iPad

These are starting points for the UX work. The mockup only shows an iPhone in portrait.

- **iPhone, landscape:** compact height.
  - Large titles collapse to inline titles.
  - The tab bar stays at the bottom.
  - Content keeps a readable width.
  - Sheets fill the screen.
  - The full-screen alarm is the system's own and handles orientation itself.
- **iPad, portrait and landscape:** regular width.
  - The tabs can become a sidebar (iPadOS 18 and later).
  - Tags and Search show the list and the selected reminder side by side.
  - Now and My Day keep a readable column, and could add a details column in landscape.
  - Sheets are centered form sheets.
  - Every window size is supported, from Slide Over to full screen, with Stage Manager.
- **Keyboard (iPad and Full Keyboard Access):**
  - ⌘N new reminder, ⌘F Search
  - ⌘1 to ⌘4 for the tabs
  - Return to save a sheet, Escape to cancel
- **Pointer:** hover effects on the system controls.
- **Accessibility sizes:** the mockup's stacked layouts apply in every size class.

## D. Localization checklist

English only at launch. Adding a language should need only translations.

- Every user-facing string is in a string catalog, including accessibility labels, VoiceOver
  announcements, alert text, notification and alarm text, the Live Activity's text, Siri phrases and
  App Shortcuts.
- Plurals use the catalog's plural variants, never "\(n) reminder(s)".
- No sentences are assembled from fragments. Phrases such as "with #home and #morning" or "Due today
  with #work or #morning" use a format string per form, and lists use the system list formatter.
- The permission prompts' text (`NSAlarmKitUsageDescription` and the other usage strings in
  `Info.plist`) and the alarm's button labels ("Done", "Snooze 15 min") are localized too.
- Dates, times, durations ("2 h 18 min") and relative times ("in 3 min") use the system formatters,
  following the region and the 12- or 24-hour setting.
- Layout uses leading and trailing, never left and right. Directional symbols, such as the Back
  chevron, mirror. Test with a right-to-left pseudo-language.
- Layouts allow for text 30 to 40% longer than English. The Dynamic Type stacked layouts cover most
  of this.
- Tag names, reminder titles and notes are the person's own text and are never translated. The
  `#` prefix stays as it is.
- Test with a pseudo-localized build: longer strings, accented characters and right to left.

## E. AlarmKit notes

From Apple's AlarmKit overview and the "Scheduling an alarm with AlarmKit" sample (WWDC25 session
230). Local copies are in `docs/apple/swift/`, which isn't in the repo.

- **Platforms:** iOS 26.0+, iPadOS 26.0+ and Mac Catalyst 26.0+. The sample targets iPhone and iPad,
  with a deployment target of 26.0.
- **The alarm UI is a system template.** `AlarmPresentation.Alert` holds a title, a stop button and
  an optional secondary button. Each `AlarmButton` has text, a text color and an SF Symbol. Alarms
  also take a tint color. There's no room for other text, so the alarm shows only the title, **Done** and
  **Snooze**, and the nudge count and snoozes left appear in the app instead.
- **Buttons run the app's code.** An alarm is configured with a `stopIntent` and a `secondaryIntent`,
  both `LiveActivityIntent`s. Their `perform()` runs without opening the app unless
  `openAppWhenRun` is set. Done would stop the alarm, close the occurrence and cancel the rest of
  its alarms there.
- **Snooze can be the system's countdown.** A secondary button with the `.countdown` behavior and a
  post-alert duration makes the system alert again after that time. That matches the fixed snooze
  per strength. After the third snooze, the app has to reschedule the remaining alarms without the
  Snooze button.
- **Countdowns are Live Activities.** The countdown and paused states appear as a Live Activity, set
  up in a widget extension, as in the sample. Nudge-inator needs that extension even without Home
  Screen widgets.
- **Schedules:** `Alarm.Schedule.fixed(date)` for a one-off time, or `.relative` for a time of day
  with weekly repeats. Each Urgent nudge is a one-off, so it's `.fixed`.
- **Reconciling:** `AlarmManager.alarms` lists what's scheduled, and `alarmUpdates` reports changes.
  The app can compare these with what it expects on every launch.
- **Permission:** `AlarmManager.requestAuthorization()`, with the reason in
  `NSAlarmKitUsageDescription`. The states are not determined, denied and authorized.
- **Not covered by the docs or the sample:** how many alarms an app can schedule, App Review's view
  of alarms for reminders, and behavior after the app has been force-quit.
