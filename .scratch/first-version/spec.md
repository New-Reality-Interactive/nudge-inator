Status: ready-for-agent

# Nudge-inator, first version

## Problem Statement

I have reminders that matter, and an ordinary iOS reminder gets one notification that I swipe away and forget. I want a reminder that keeps nudging me, the way an iOS Alarm keeps ringing, until I finally mark it done. For the ones that really matter it has to get through a Focus. I don't want to depend on willpower or on remembering to re-set it.

## Solution

An iPhone app (iOS 26 and later) where each reminder has a strength (Gentle, Firm or Relentless). Once a reminder comes due it nudges on that strength's escalating schedule: ordinary notifications first, then Time Sensitive notifications, then AlarmKit alarms for Firm and Relentless. A per-reminder **Break through Focus** switch controls whether the nudges may get through a Focus. The alarm offers the system **Stop** (silence, and the ladder moves along) and an **Open** button that opens the reminder, where **Done** is the only way to end the nudging. The screens are as drawn in the mockup: Now, My Day, Tags and a minimal Settings.

Vocabulary is in `CONTEXT.md`. The Stop and Open decision is in ADR 0001. The visual design is `docs/mockups/2026-10-02-ux-review-changes/` where this spec doesn't differ from it.

## User Stories

1. As someone with an important reminder, I want it to keep nudging until I mark it done, so that I can't forget it by swiping a notification away.
2. As a user, I want to create a reminder with a title, notes, a due date and time, so that it comes due when I need it.
3. As a user, I want to choose a strength for each reminder, so that a trivial reminder nudges gently and an important one nudges relentlessly.
4. As a user, I want Gentle to nudge hourly at first, easing to every 20 minutes, so that low-stakes reminders don't become a nuisance.
5. As a user, I want Firm to nudge every 30 minutes, tightening to every 5, so that a reminder that matters gets harder to ignore.
6. As a user, I want Relentless to nudge every 10 minutes, tightening to every 2, so that a reminder I truly can't miss escalates fast.
7. As a user, I want each nudge to carry a urgency (Normal, High or Urgent) that rises along the ladder, so that the nudges get harder to ignore over time.
8. As a user, I want Firm and Relentless reminders to ring as alarms from the fourth nudge, so that they reach me even on silent.
9. As a user, I want Gentle reminders never to ring as alarms, so that low-stakes reminders can't wake me.
10. As a user, I want a Break through Focus switch on each reminder, so that I choose which reminders may get through a Focus.
11. As a user, I want the switch on to give me the full ladder (ordinary, then Time Sensitive, then alarm), so that important reminders reach me during a Focus.
12. As a user, I want the switch off to send only ordinary notifications, so that a Focus can hold them and a low-stakes reminder never interrupts me.
13. As a user, I want to tap **Stop** on an alarm to silence it, so that I can quiet it right now.
14. As a user, I want Stop not to end the reminder, so that an accidental or half-asleep Stop can't make me forget.
15. As a user, I want the next nudge to come on schedule after a Stop, so that the reminder keeps working.
16. As a user, I want an **Open** button on the alarm, so that I can jump straight to the reminder.
17. As a user, I want to mark the reminder **Done** where Open lands me, so that finishing the task is one tap from the alert.
18. As a user, I want **Done** on the nudge card and on every notification, so that I can finish a reminder without hunting for it.
19. As a user, I want Done to end the occurrence for good and cancel its pending notifications and alarms, so that nothing more is sent.
20. As a user, I want a reminder to give up after 20 nudges or 24 hours, whichever comes first, so that a forgotten reminder doesn't nudge forever.
21. As a user, I want a reminder that gave up to show as **Missed**, so that I can see what I let slide.
22. As a user, I want the notification to show the title and the nudge count and urgency ("Nudge 3 of 20 · High"), so that I know how serious it has become without opening the app.
23. As a user, I want the alarm to show only the title, so that private details don't appear on my Lock Screen.
24. As a user, I want notes and tags never to appear in a notification or alarm, so that my private details stay in the app.
25. As a user, I want a repeating reminder to come due again on its schedule, so that I don't recreate it.
26. As a user, I want the repeat presets Never, Every Day, Every Weekday, Every Week, Every 2 Weeks, Every Month and Every Year, so that the common cases are quick.
27. As a user, I want the next occurrence to take over when the last one is still nudging, so that I'm never nudged about two copies of the same reminder.
28. As a user, I want the occurrence that was taken over to show as Missed ("the next one took over"), so that I can see what happened.
29. As a user, I want the new occurrence to start at nudge 1, so that a missed one doesn't make the next one start angrier than I chose.
30. As a user, I want to attach any number of tags to a reminder, or none, so that I can group them my own way.
31. As a user, I want a tag to be one word shown as `#home`, so that tags stay short and consistent.
32. As a user, I want tag names to be unique ignoring case, so that `Home` and `#home` are the same tag.
33. As a user, I want to create a tag while editing a reminder, so that I don't need a separate step.
34. As a user, I want to rename and delete tags from the Tags tab, so that I can tidy them up.
35. As a user, I want deleting a tag to warn me how many reminders use it and not delete those reminders, so that I don't lose reminders by mistake.
36. As a user, I want the Tags tab to list my tags with counts of reminders, due today and nudging, so that I can see where my attention is needed.
37. As a user, I want to choose a tag on the Tags tab and see that tag's reminders, so that I can find a group quickly.
38. As a user, I want a + button on the Tags tab that adds a new tag, so that I can make a tag before I need it.
39. As a user, I want a + button on a tag's screen that makes a new reminder with that tag already chosen, so that I can add to a group in one step.
40. As a user, I want a **Now** tab with my nudging cards (Done on each), Coming Up for 7 days and the Last 24 Hours, so that I see what needs me first.
41. As a user, I want a **My Day** tab with today's occurrences in time order and Done, Nudging, Missed and Left counts, so that I can see how my day is going.
42. As a user, I want to tap a count on My Day to filter the list to it, so that I can focus on the Missed or still-nudging ones.
43. As a user, I want to filter My Day by tags, or by No Tags, so that I can see one area of my life at a time.
44. As a user, I want to swipe a nudging row for Done, so that finishing is quick.
45. As a user, I want to pause a reminder, so that it stops nudging without losing it.
46. As a user, I want a nudging occurrence that I pause to close as Skipped, not Missed, so that pausing isn't counted against me.
47. As a user, I want to resume a paused reminder at its next future time, so that I don't have to recreate it.
48. As a user, I want to delete a reminder after a confirmation, so that I don't delete one by accident.
49. As a user, I want edits to a nudging reminder to apply from the next nudge or next occurrence, with a warning where the occurrence is skipped, so that I know what my change will do.
50. As a user, I want the app to ask for notification permission and then alarm permission on first launch, so that I understand what each is for.
51. As a user, I want a banner if alarms are denied, saying that Urgent nudges now come as Time Sensitive notifications, so that I know the weaker behavior.
52. As a user, I want Urgent nudges to fall back to a Time Sensitive notification when the system's alarm limit is reached, marked "Notification: too many alarms scheduled", so that a nudge still reaches me.
53. As a user, I want a banner if notifications are denied, so that I know why nothing is reaching me.
54. As a user, I want a minimal Settings tab showing permission status, with **Send a Test Nudge** and **Delete All Data**, so that I can check it works and clear everything.
55. As a user, I want everything stored on my device with no account or server, so that my reminders stay private.
56. As a user, I want the app to follow the system's Light, Dark and text size settings, so that it behaves like any iOS app.
57. As a user, I want to know how nudges reach me before I rely on them (onboarding and How It Nudges), so that I trust it for the reminders that matter.

## Implementation Decisions

- **Platform.** iOS 26 and later only. No iOS 18 variants and no notification-chain fallback for missing AlarmKit.
- **Nudge engine (the main module).** A pure module with no framework dependencies. It turns reminders, the current time, permission states and events (Stop, Done, Edit, Pause, Resume, Delete, app opened) into occurrence state and a *schedule plan*: the list of alarms and notifications to have pending, each with its fire time, urgency and delivery kind. It owns all the rules below.
- **Scheduler adapter.** A thin module that applies a schedule plan through AlarmKit and the user notification center, and reports permission states and scheduling errors back to the engine. The engine never calls Apple frameworks directly.
- **Store.** Local persistence of reminders, tags and the state of each occurrence. No account, no server.
- **Occurrence lifecycle.** An occurrence is nudging until it is Done, Missed (give-up limit reached, or taken over by the next occurrence) or Skipped (paused, or an edit that skips it). A reminder has at most one open occurrence.
- **Strengths and ladders.** Gentle starts at 60 minutes (factor 0.75, floor 20 minutes). Firm starts at 30 (factor 0.5, floor 5). Relentless starts at 10 (factor 0.5, floor 2). Urgency rises from Normal to High to Urgent along the ladder. Firm and Relentless reach Urgent from nudge 4, and Gentle never does. The numbers come from the mockup and can be tuned.
- **Give-up limit.** Fixed at 20 nudges or 24 hours, whichever comes first. There is no editor and no per-strength minimum.
- **Delivery by urgency.** With Break through Focus on: Normal is an ordinary notification, High is a Time Sensitive notification, and Urgent is an AlarmKit alarm. With it off: every nudge is an ordinary notification. With alarms denied, or past the system's alarm limit (the scheduling error), Urgent nudges are Time Sensitive notifications instead.
- **Alarm presentation.** Title only, the app's tint, the system's Stop button, and a custom secondary button, **Open**, that runs an app intent that opens the app on the reminder. Stop moves the ladder along. The chain of later nudges is pre-scheduled, so Stop needs no app code. See ADR 0001.
- **Done.** The only way to end nudging, from the nudge card, the Open destination, notification actions, swipe actions and My Day. Done cancels every pending alarm and notification for the occurrence. Notification actions are Done only.
- **Take-over.** If the next occurrence falls due while the last is open, the last closes as Missed and the new one starts at nudge 1. There is no carry-over.
- **Repeats.** The presets Never, Every Day, Every Weekday, Every Week, Every 2 Weeks, Every Month and Every Year. No Custom.
- **Quiet hours.** None in the app. A Focus holds ordinary notifications, and alarms ring through every Focus, Sleep Focus included. The Break through Focus switch is the only control.
- **Privacy.** Notifications carry the title and "Nudge N of 20 · Urgency". Alarms carry only the title. Notes and tags stay in the app.
- **Screens.** Now, My Day, Tags and a minimal Settings (permission status, Send a Test Nudge, Delete All Data), as drawn in the mockup. Reminder details with Edit, Pause, Resume and Delete, and the New Reminder form with Title, Notes, Tags, Repeat, Strength and the Break through Focus switch. The Tags tab is only about tags: its list, + to add a tag, Edit to rename or delete, and a pushed screen of one tag's reminders, whose + makes a reminder with that tag. My Day's filters (tags with Match All or Any, No Tags, and the status counts), swipe actions and permission banners follow the mockup.
- **Deliberate differences from the mockup.** No Snooze, no Not Done, no Undo, no Clear log, no Done follow-up notification, no quiet hours and no carry-over. Stop does not count as Done.

## Testing Decisions

- **What a good test is.** It exercises external behavior through the engine's interface with a fake clock and a fake scheduler adapter, and asserts on occurrence state and on the schedule plan. It does not assert on internal data structures or on how the plan is built.
- **One seam.** The nudge engine's interface, as agreed. The scheduler adapter is replaced by a fake that records the plan.
- **What the tests cover.** The ladder for each strength (intervals, urgency, when alarms begin, Gentle never ringing). The give-up limit. Break through Focus on and off. The fallbacks for denied alarms and for the alarm limit. Stop moving the ladder along without ending the occurrence. Done cancelling everything pending. Take-over of a repeat. Pause, Resume, Delete and Edit while nudging. The repeat presets, including month ends. Tag rules (names unique ignoring case, deleting a tag keeps its reminders) and My Day's counts and tag filters (Match All, Match Any).
- **Not covered automatically.** The SwiftUI screens, and the AlarmKit and notification adapter. Three behaviors need a device: the real system alarm limit, whether tapping Open silences the ring, and how Open behaves on a locked phone.
- **Prior art.** None. The repository has no code yet.

## Out of Scope

- iOS 18 and iPad.
- Snooze, Not Done, Undo, the Clear log and the Done follow-up notification.
- Quiet hours and Ignore Quiet Hours.
- Carry-over ("Starts higher").
- Custom repeats.
- Filtering all reminders by several tags at once. My Day's tag filter covers today only.
- Editing the give-up limit, the snooze length, or the intervals.
- Search, history, Export Data, Siri and Shortcuts, Assistive Access, the Live Activity countdown.
- Updating the mockup or its README to match these decisions.

## Further Notes

- The alarm limit is undocumented. Apple gives only the `maximumLimitReached` error, so the limit has to be measured on a device before the chain length is settled. The Time Sensitive fallback covers hitting it.
- Apple's docs say a custom secondary button runs its intent "without mutating the alarm state," which suggests the ring may continue after Open. Because of that, the Open intent should stop the alarm itself, and a device test must confirm the behavior. This is still open.
- The secondary intent is "only available after first unlock" since a restart. What happens on a locked phone is unconfirmed.
- Alarms ring through every Focus, so a Firm or Relentless reminder with the switch on can ring after midnight. The 20-nudge limit bounds this to roughly 1 hour for Relentless, 1.5 hours for Firm and 6 hours for Gentle, which never rings.
- The mockup README's "Stop counts as Done" rule is superseded by ADR 0001.
