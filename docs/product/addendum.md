---
title: "Product Brief Addendum: Nudge-inator"
updated: 2026-10-03
---

# Product Brief Addendum: Nudge-inator

Detail behind the [brief](brief.md) that later documents (PRD, UX, architecture) will need, but that
doesn't belong in the brief itself. The rules in the brief started from the tags mockup. Which
document wins where they differ is set once, in the [brief's introduction](brief.md). Technical
decisions are in the [architecture spine](../architecture/ARCHITECTURE-SPINE.md).

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
| Normal nudges | Notification (`.active`), held by a Focus | Same | Same |
| High nudges | Time Sensitive notification | Same | Same |
| Urgent nudges | Notification chain (each time an occurrence enters Urgent: at once and then every minute, 10 in all; then the strength's interval) | AlarmKit alarm; the notification chain if alarms aren't allowed | Same as iOS 26 |
| Alarm permission prompt | None | On first launch, after notifications; or, after updating from iOS 18, on the first launch on iOS 26 | Same |
| AlarmKit | Not available | Available (iOS and iPadOS 26.0+) | Available |
| Bars, tab bar and sheets | iOS 18 system look | Liquid Glass | Liquid Glass |
| Scroll edge effects | System default for iOS 18 | As in the mockup | As in the mockup |
| Tab bar shrinking in landscape (`tabBarMinimizeBehavior`, iPhone only) | Not available: the full tab bar stays | As in the mockup | Same |
| My Day's date as a subtitle (`navigationSubtitle`) | Not available: the date stays in the content, as in portrait | As in the mockup | Same |
| Assistive Access | `UISupportsFullScreenInAssistiveAccess`, with the app's own one-screen view when `isAssistiveAccessEnabled` | `AssistiveAccess` scene and `UISupportsAssistiveAccess`, in the system's Assistive Access style | Same |
| Search | A fifth tab, with its field under the title | A separate circle in the tab bar (`Tab(role: .search)`) | Same |
| Sheet buttons | **Cancel**, **Add**, **Save**, **Done** as words | Symbols for the `.cancel` and `.confirm` button roles | Same |
| Section headers | Capitals | Title case | Same |
| Confirming a delete | Action sheet at the bottom, with Cancel | `confirmationDialog` attached to its button, growing out of it, with no Cancel (WWDC25, "Build a UIKit app with the new design") | Same |
| Unselected tabs | Secondary label color, set with `UITabBarAppearance` (iOS 18's default gray is about 3:1) | The system's own | Same |
| Resizable iPhone app (iPhone Mirroring, an iPhone app on iPad) | Not available | Not available | Available: the layout follows the width |
| Swipe actions on `List` rows | Available (iOS 15 and later) | Same | Same |

The mockup's iOS 26 behavior is the target. On iOS 18, the app uses the same system components, so
it gets iOS 18's look without a separate design. The rows above that say "Not available" are the
exceptions: those APIs are iOS 26.0 and later, so iOS 18 keeps the portrait behavior.

## C. Layout notes for landscape and iPad

The iPhone notes describe what the tags mockup shows; its README has the reasons and how it was
checked. The iPad notes are for v2: in v1, iPad runs the iPhone app (decided in the UX work on 2026-10-02).

| Threshold | Value | What changes |
|---|---|---|
| Wide nudge cards | A card 540 pt wide or more, in any orientation and on iPad | Done and Snooze sit beside the text, except at accessibility sizes |

- **iPhone, landscape:** compact height. Every model:
  - Large titles collapse to inline titles. The status bar is hidden.
  - Content stays inside the safe areas, at a readable width; backgrounds run to the edges.
  - The tab bar stays at the bottom, with each symbol beside its title. It shrinks to the current
    tab while scrolling down (`tabBarMinimizeBehavior(.onScrollDown)`), except on Search. Portrait
    keeps the full tab bar (decided 2026-10-01). iOS 26 and later only; on iOS 18 it doesn't shrink.
  - My Day's header is shorter: the date is the title's subtitle (`navigationSubtitle`, iOS 26 and
    later; on iOS 18 it stays in the content), Filter is a bar button showing how many tags are
    chosen, and the counts are a row of capsules.
  - Wide nudge cards put Done and Snooze beside the text (see the table). It depends on the card's
    width, not the orientation.
  - Sheets fill the screen. Alerts stay centered. On iOS 18, action sheets keep their portrait
    width; on iOS 26, confirmation dialogs grow out of their button.
  - Nudges arrive over the app, because the iPhone is in use: the alarm as AlarmKit's alert (a
    banner at the top in the mockup, to confirm on a device) and notifications as banners. The Lock
    Screen doesn't rotate, so it's only ever portrait.
- **iPhone, every model and orientation:** one column. The larger iPhones are regular width in
  landscape, but the iPhone app has no split view (decided 2026-10-02): it waits for iPad. The
  previous mockup's split view is archived in
  `docs/mockups/archive/2026-09-30-mockup-tags-v1/`.
- **iPhone app in a resizable window (iOS 27):** the layout follows the window's width, as above.
- **iPad (v2), portrait and landscape:** regular width. In v1, iPad runs the iPhone app.
  - The tab bar floats at the top of the screen (iPadOS 18 and later), not at the bottom as on
    iPhone, and the tabs can become a sidebar (`sidebarAdaptable`). Search stays pinned at the
    trailing end.
  - The tab bar never shrinks: Apple supports minimizing it "on only iPhone".
  - Tags, Search and Settings use a split view (`NavigationSplitView`): the list and the chosen
    item side by side. The archived mockup's iPhone split view is a starting point.
  - Now and My Day keep a readable column, and could add a details column in landscape.
  - Sheets are centered form sheets.
  - Every window size is supported, from Slide Over to full screen, with Stage Manager.
- **Keyboard (iPad and Full Keyboard Access):**

  | Key | Action |
  |---|---|
  | ⌘N | New reminder |
  | ⌘F | Search |
  | ⌘1 to ⌘4 | Now, My Day, Tags, Settings |
  | Return | Save a sheet |
  | Escape | Cancel a sheet |

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
  `Info.plist`) and the alarm's Snooze label ("Snooze 15 min") are localized too. The alarm's stop
  control is the system's, so iOS localizes it.
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

From Apple's AlarmKit overview and API reference, the "Scheduling an alarm with AlarmKit" sample
and WWDC25 session 230, "Wake up to the AlarmKit API". Local copies are in `docs/apple/swift/`,
which isn't in the repo. Checked against Apple's documentation on 2026-10-01.

- **Platforms:** iOS 26.0+, iPadOS 26.0+ and Mac Catalyst 26.0+. The sample targets iPhone and iPad,
  with a deployment target of 26.0.
- **The alarm UI is a system template.** `AlarmPresentation.Alert` holds a title and an optional
  secondary button. Each `AlarmButton` has text, a text color and an SF Symbol (shown in the
  Dynamic Island). Alarms also take a tint color, which fills the secondary button and tints the
  title and countdown on the Lock Screen. The system adds the app's name. There's no room for other
  text, so the nudge count and snoozes left appear in the app instead.
- **The stop control is the system's.** The initializer with a `stopButton` is deprecated from
  iOS 26.1 ("stopButton is deprecated and will no longer be used"). The current one,
  `init(title:secondaryButton:secondaryButtonBehavior:)`, uses a system-provided stop control, so
  the alarm can't say **Done**. Stopping still runs the app's `stopIntent`.
- **Buttons run the app's code.** An alarm is configured with a `stopIntent` and a `secondaryIntent`,
  both `LiveActivityIntent`s. Their `perform()` runs without opening the app unless
  `openAppWhenRun` is set. The intents only record a command (Done or Snooze); the app's reconciler
  does the rest, such as cancelling the occurrence's other alarms after Stop (architecture spine,
  AD-12). The one exception is before the first unlock (AD-16). The secondary intent "is only available after first unlock", so a Snooze before the first
  unlock after a restart isn't seen by the app until it next runs.
- **Snooze can be the system's countdown.** A secondary button with the `.countdown` behavior and a
  post-alert duration (`Alarm.CountdownDuration`'s `postAlert`) makes the system alert again after
  that time. That matches the reminder's snooze length (the strength's default or longer).
  - The alarm that rings again uses the presentation it was scheduled with, so it still has Snooze.
    On the third snooze, once the snooze command is recorded, the reconciler cancels that alarm and
    schedules a new one for the end of the snooze, with no secondary button, and the remaining alarms are
    scheduled without it.
  - The occurrence's later alarms are separate alarms, so each snooze has to move them past the
    snooze. Otherwise, for example, a Relentless alarm 2 minutes later would ring during a 5-minute
    snooze.
  - The system's countdown rings again whatever has happened meanwhile, and no app code runs when
    it does. So if the snooze would end after the next occurrence takes over, or inside quiet hours
    for a reminder that doesn't ignore them, the reconciler cancels the countdown once the snooze
    command is recorded, and schedules a fixed alarm at the right time, or none.
  - If a device shows that cancelling an alarm during its countdown fails, the snooze button
    switches to the `.custom` behavior: the intent runs, and the app's own alarm replaces the
    countdown (AD-12's fallback).
- **Countdowns are Live Activities.** The countdown and paused states appear as a Live Activity, set
  up in a widget extension, as in the sample. Nudge-inator needs that extension even without Home
  Screen widgets. Apple warns that without it "the system may unexpectedly dismiss alarms and fail
  to alert". Before the first unlock the Live Activity can't show, so the alarm also needs an
  `AlarmPresentation.Countdown`, which the system draws instead.
- **Schedules:** `Alarm.Schedule.fixed(date)` for a one-off time, or `.relative` for a time of day
  with weekly repeats. Each Urgent nudge is a one-off, so it's `.fixed`. A fixed alarm "does not
  change when device timezone changes", so alarms are rescheduled when it changes (reminders follow
  the iPhone's time zone; brief §3).
- **Where it shows:** the Lock Screen, the Dynamic Island and StandBy, and a paired Apple Watch,
  which the system forwards the alert to. Apple calls it a prominent alert and doesn't describe it
  as full screen. WWDC25 session 230 says the buttons' SF Symbols are used "when the alert is shown
  in the Dynamic Island". That suggests the Dynamic Island is where it appears on an iPhone that's
  in use, and the Lock Screen only on a locked one. Apple doesn't say this directly.
- **Reconciling:** `AlarmManager.alarms` lists what's scheduled, and `alarmUpdates` reports changes.
  An alarm missing from `alarmUpdates` is no longer scheduled. The app can compare these with what
  it expects on every launch.
- **Permission:** `AlarmManager.requestAuthorization()`, with the reason in
  `NSAlarmKitUsageDescription`. Without that key, or with an empty value, the app can't schedule
  alarms. The states are not determined, denied and authorized, and `authorizationUpdates` reports
  changes. If the person denies it, every attempt to schedule an alarm fails, and Urgent nudges
  come as the notification chain, as on iOS 18. The permission is separate from notifications.
- **Limit:** scheduling can fail with `AlarmManager.AlarmError.maximumLimitReached`. Apple doesn't
  say what the limit is, so the app records how many alarms it could schedule, plans within that,
  and tries one more each time it reschedules.
- **App Review:** Apple says alarms suit countdowns and recurring scheduled alerts, and "are not a
  replacement for other prominent notifications, like critical alerts or time-sensitive
  notifications".
- **iOS 27:** new `AlarmConfiguration` initializers add an optional `appEntityIdentifier`,
  which could link an alarm to the reminder's App Entity for Siri. Apple's documentation still
  marked them beta on 2026-10-01, although iOS 27 is expected to be out by then; check that they're
  final before relying on them. iOS 27 also adds a `.clock` App Intents domain with a `snoozeAlarm`
  schema for Siri and Shortcuts. An app that adopts any schema in the domain must support them all,
  including creating alarms, so it probably doesn't fit Nudge-inator.
- **Not covered by the docs or the sample:** the alarm limit's value, App Review's view of alarms
  for reminders, behavior after the app has been force-quit, and whether alarms ring with
  notifications turned off. Nor how the alert looks on an unlocked iPhone: in landscape, where the
  Dynamic Island is at the side; on iPhones without a Dynamic Island; and on iPad.

## F. TestFlight beta

The brief's release decision (§10): release on the App Store once the success measures (§8) are met
over a four-week TestFlight beta. Apple's documentation confirms that external builds need Beta App
Review and that testers can join by public link. The limits and time periods below are as of
2026-10-01; check them in App Store Connect's help.

| Item | Value |
|---|---|
| Cost | The Apple Developer Program, $99 a year |
| External testers | Up to 10,000, by email or a public link |
| Internal testers | Up to 100, members of the App Store Connect team |
| Beta App Review | The first build of each version, usually within about a day |
| Build expiry | 90 days after upload |

- **Setup.** The Apple Developer Program, then an app record in App Store Connect with
  the bundle ID. TestFlight doesn't need an App Store listing. In Xcode, add the capabilities and
  `Info.plist` keys listed in the architecture spine's
  [Structural Seed › Environments](../architecture/ARCHITECTURE-SPINE.md#structural-seed), which is
  the one list. It includes the Time Sensitive Notifications entitlement (required to send Time
  Sensitive notifications), `NSAlarmKitUsageDescription`, `NSSupportsLiveActivities`,
  `UISupportsAssistiveAccess` and `UISupportsFullScreenInAssistiveAccess` (iOS 18's Assistive
  Access view), and `UIBackgroundModes` with `fetch` plus `BGTaskSchedulerPermittedIdentifiers`
  (the background top-up of scheduled nudges, AD-14).
- **Builds.** Archive in Xcode and upload from the Organizer (Distribute App > App Store Connect).
  Set `ITSAppUsesNonExemptEncryption` to `NO` in `Info.plist`, since the app uses no encryption of
  its own; otherwise App Store Connect asks about it for every build.
- **Testers are external,** invited by email or a public link. Internal testers would have to join
  the App Store Connect team, which gives them access to it, so they're only for the owner.
- **Beta App Review** checks the first build of each version before external testers get it; later
  builds of the same version usually skip it. It needs a
  description of what to test and a contact email. It's the first time Apple sees the app schedule
  AlarmKit alarms for reminders, so its outcome is an early signal for the App Review risk in the
  brief: a rejection means rethinking alarms before release.
- **Builds expire.** Upload a new one before the last one expires while the beta runs.
- **Devices.** Recruit testers on iOS 18 and on iOS 26 or later, so both Urgent paths, the
  notification chain and AlarmKit alarms, get real use. Include at least one iPad and one iPhone
  without a Dynamic Island, for the alarm checks the brief lists.
- **Feedback.** Testers send screenshots and comments from the TestFlight app, and crash reports
  arrive in App Store Connect. These are the evidence for the success measures.

