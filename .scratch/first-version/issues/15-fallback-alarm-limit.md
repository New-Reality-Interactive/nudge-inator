Status: resolved

# Fallback for the alarm limit, and the chain length the spike chose

## What to build

When the scheduler reports `maximumLimitReached` for an Urgent nudge, the engine re-plans that nudge as a **Time Sensitive notification** marked "Notification: too many alarms scheduled" and keeps the rest of the ladder. Use the spike's measured limit (ticket 02) to set how many alarms are kept pending at once (the chain length), and which later nudges are scheduled lazily when the app opens, if the limit is below what a full ladder needs.

The notification side has its own cap: the system keeps only the soonest 64 pending local notifications (ticket 18 caps the adapter at 64 and the app tops up on foreground), so the chain length must account for both the alarm limit and that cap.

Events in: "scheduling failed with alarm limit for item X" from the adapter. The fake scheduler can be told to fail after N alarms.

## Acceptance criteria

- [x] With a fake scheduler whose limit is N, a plan that needs more than N alarms is delivered with the overflow nudges as Time Sensitive notifications carrying the "too many alarms scheduled" marker.
- [x] The marker text appears only on the overflow nudges.
- [x] Chain length constant equals the value recorded in ticket 02's answer; the test names the number and cites the ticket.
- [x] When a slot frees (an alarm fired or was stopped) a later reconcile promotes a notification back to an alarm only if the spike showed slots are reusable; otherwise the behaviour is documented.
- [x] Alarms-denied fallback (ticket 14) and limit fallback combine without duplicating items.

Blocked by: 14, 02

## Comments

**Decisions settled with the user before coding (2026-10-16).**
- **The event is `Engine.markAlarmLimitReached(_ reminderID:, firingAt fireTime:)`.** It names the nudge by reminder ID and fire time, not nudge number. The plan can hold two ladders for one reminder (the open occurrence and the next), so a nudge number is ambiguous; a fire time isn't. One report re-plans only that nudge. The adapter reports each alarm that fails, and a global limit could free up if another app's alarms go. A report the plan has no alarm for is ignored and applies no plan, like the other events with nothing to act on: a reminder not held, a fire time not in the plan, a nudge that isn't an alarm (already fallen back, alarms denied, switch off), or one that has fired.
- **The marker is `SchedulePlan.Item.isPastAlarmLimit: Bool`, not a delivery kind.** The adapter still sees `.timeSensitiveNotification` and needs no new case. The words "Notification: too many alarms scheduled" are UI (tickets 26 and 27), like the mockup's other `viaLabel` wordings. The mockup has no such string yet. They are not in the notification, whose body Privacy fixes as the title plus "Nudge N of 20 · Urgency". The fallback goes through `Engine.delivery` (ticket 14's `deliveryKind`, which now also returns the marker):
  - The marker is set only when the nudge would otherwise ring.
  - Alarms denied, or the switch off: Time Sensitive, with no marker, because the reason is "alarms are off" (or the switch).
  - Time Sensitive off: an ordinary notification, still marked.
  - Notifications denied: the nudge drops out.
- **The chain length is 4,000 pending alarms, the engine's cap (`AlarmLimit.shipped`).** That's what ticket 02 A scheduled on an iPhone 15 (iOS 27.0.1) without `maximumLimitReached`. It is a floor, not the system's limit, so the report stays as the safety net. The cap counts only alarms yet to ring, soonest first, with ties broken by reminder ID. Alarms past it are planned as marked notifications without waiting for a report. So the engine never asks AlarmKit for more than 02 tested. A ladder rings at most 17 times, so no lazy alarm scheduling is needed: it takes some 118 repeating Relentless reminders nudging at once (two ladders each) to reach the cap. `shippedEnginePlansAtMostTheFourThousandAlarmsTicket02Measured` names the number, cites 02's point A, and checks it through the public init: 235 one-off Relentless reminders plan 3,995 alarms, and 236 plan 4,000 with 12 marked.
- **The 64-pending-notification cap belongs to the adapter (ticket 18).** The adapter keeps the soonest 64, and ticket 21 refills on foreground. The engine's plan stays complete. Overflow nudges are notifications, so they compete for those 64 like any other.
- **Slot reuse.** Ticket 02 hit no limit, so it couldn't show whether an alarm that fired or was stopped frees a slot. A nudge the system turned down stays a notification until it fires: a later reconcile doesn't try it as an alarm again. The engine's own cap is different, because the engine knows its own count. Its overflow is worked out again on every plan, so a slot it frees goes back to an alarm (`engineCapGivesAlarmsBackWhenAnotherReminderGoes`). This changed in review; see below.
- **Interaction with the other events.**
  - Records are kept per fire time in the reminder's `History`.
  - Done, Pause and take-over drop the occurrence's items from the plan.
  - Delete clears the record.
  - A new occurrence's ladder starts with alarms.
  - Already-delivered overflow nudges keep their delivery and marker, like titles (13) and deliveries (14).
  - Records are pruned past the give-up span, as in 14.
  - Alarms denied after an overflow: Time Sensitive, no marker. Allowed again: the record still applies, so the nudge is marked again.
- **No duplicate items with ticket 14.** Both fallbacks only change one item's kind and marker, so there is always one item per nudge (`bothFallbacksTogetherKeepOneItemPerNudge`). With alarms denied the plan has no alarm items, so no report can apply.

**Tests** are in `AlarmLimitFallbackTests.swift` (22 tests, 27 cases). `FakeScheduler(alarmLimit:)` fails alarms past N, soonest first, through `alarmsPastLimit(at:)`. The test sends each one to the engine, as the adapter will (the engine is a struct, so the fake can't call it back).
- **Red first:**
  - The overflow nudges as marked Time Sensitive notifications.
  - Alarms denied after an overflow dropping the marker.
  - The five ignored reports.
  - The engine's cap.
  - In review: the cap giving alarms back, cap overflow that fired keeping its marker, and an Edit that moves the ladder forgetting the reports.
- **Passed on their first run, kept as acceptance coverage:**
  - The marker only on overflow nudges.
  - Overflow following Time Sensitive off and notifications denied.
  - Reported nudges staying notifications after earlier alarms ring.
  - A fired overflow nudge keeping its marker.
  - Delete forgetting the limit.
  - A later occurrence ringing.
  - A title Edit keeping the reports.
  - One item per nudge with both fallbacks.
  - The shipped 4,000.
  - Cap ties independent of store order. This passed only because the sort happened to be stable; the explicit tie-breaker is there anyway.
- **Mutation-checked:**
  - A cap of 3,999 fails the shipped test.
  - Dropping the has-fired guard on reports fails `reportForANudgeThatHasFiredIsIgnored`.
  - Sorting the cap latest-first fails the cap test.
  - Counting alarms that have rung toward the cap survived at first. `engineCapCountsOnlyAlarmsYetToRing` was added and catches it.

**Code review (two axes, against main).**
- **Spec.**
  - Fixed: the cap's records were sticky like a report, so adding then deleting a reminder turned another's alarms into notifications for good. Decision 5's reason (02 couldn't show slot reuse) applies to the system's slots, not the engine's own exact count. So the cap's overflow yet to fire is now worked out again for each plan, and cap overflow that has fired keeps its marker. Reports stay sticky. This changes what was agreed for the cap: it no longer "falls back like a report".
  - Fixed: ties at the cap boundary depended on the store's order. Ties now go by reminder ID.
  - Fixed: an Edit that moves a ladder (due time, repeat, strength) kept the reports keyed by old fire times, so a new nudge landing on an old time came out marked with no report. Such an Edit now forgets the reports for nudges yet to fire. A title Edit keeps them.
  - Fixed: the no-duplicates criterion was only tested indirectly. It now has its own test.
  - Fixed: the doc comments said only "the system's alarm limit". They now cover the cap too. `AlarmLimit` records 02's bulk-scheduling caution for ticket 19 and says the 118 assumes repeats.
- **Standards: no hard violations.** Fixed:
  - The internal init's comment now covers `alarmLimit`.
  - The overflow choice was made in two places (`ringsAsAlarm` in the caller and in `deliveryKind`). It is now one `delivery(...)` that returns the kind and the marker, over a `notificationKind(...)` helper.
  - The test setup was repeated eight times. The suite now has `engine(alarmLimit:permissions:holding:)` and `engineWithBinsOverflowing(permissions:)` helpers, and the three-value tuple helper is gone.
  - Two overlapping tests now check different things (delivery kinds, and the marker).
  - `applyPlan` is split into `pruneAlarmLimitRecords` and `fallBackAlarmsPastTheCap`.
- **Kept, as judgement calls:**
  - The fake's `alarmsPastLimit` mirrors the engine's cap pipeline on purpose. It stands in for the system, so it must not share the engine's code (a comment says so).
  - `applyPlan` builds the plan twice, once to count alarms and once to apply. It's cheap, and keeps `plan()` free of side effects.

**For ticket 19:** call `markAlarmLimitReached` for each `maximumLimitReached`, with the item's reminder ID and fire time, then apply the plan the engine hands back. Schedule soonest first, so the latest nudges are the ones that overflow, and schedule only what changed (02's bulk-scheduling caution).

**Left alone:** tags and My Day (16), the store (17), the adapters and real scheduling (18–20), and every UI, including the "too many alarms scheduled" label on the Now card and details (26, 27), the banners (31) and Settings (30). The records are in memory only, like 14's. After a relaunch the adapter's next report rebuilds them.

